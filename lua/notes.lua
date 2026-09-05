---@class NoteInfo
---@field timestamp string
---@field title string
---@field tags string[]

---@class NotesPlugin
---@field dir string
local Notes = {
  dir = "",
}

---Cleans a title string by preserving its case, replacing spaces with
---hyphens and removing invalid characters.
---@param title string
---@return string
local function clean_title(title)
  title = title:gsub(" ", "-") -- Replace spaces with hyphens
  title = title:gsub("-+", "-") -- Replace multiple hyphens with a single hyphen
  title = title:gsub("[^-0-9A-Za-zÆØÅæøå]", "") -- Remove invalid characters
  return title
end

---Cleans a tag string by converting to lowercase, replacing spaces with
---hyphens and removing invalid characters.
---@param tag string
---@return string
local function clean_tag(tag)
  tag = tag:lower() -- Convert to lowercase
  tag = tag:gsub(" ", "-") -- Replace spaces with hyphens
  tag = tag:gsub("_+", "_") -- Replace multiple underscores with a single underscore
  tag = tag:gsub("[^0-9a-zæøå]", "") -- Remove invalid characters
  return tag
end

---Notify user that the current file is not in the notes directory.
local function print_not_in_notes_dir()
  vim.notify("Not in a note file: " .. vim.fn.expand("%"), vim.log.levels.WARN)
end

---Setup the Notes plugin.
---@param opts { dir: string }
function Notes.setup(opts)
  opts = opts or {}

  if opts.dir == nil then
    vim.notify("Please set the directory containing the notes", vim.log.levels.ERROR)
    return
  end

  Notes.dir = vim.fn.expand(opts.dir)

  local commands = { "create", "find", "link_to_note", "retitle", "search", "toggle_tag" }
  vim.api.nvim_create_user_command("Notes", function(command_opts)
    local args = command_opts.args
    if args == "create" then
      Notes:create()
    elseif args == "find" then
      Notes:find_note()
    elseif args == "link_to_note" then
      Notes:link_to_note()
    elseif args == "retitle" then
      Notes:retitle()
    elseif args == "search" then
      Notes:search_notes()
    elseif args == "toggle_tag" then
      Notes:toggle_tag()
    else
      vim.notify("Unknown command: " .. args, vim.log.levels.WARN)
    end
  end, {
    nargs = 1,
    complete = function(_, line)
      local l = vim.split(line, "%s+")
      return vim.tbl_filter(function(val)
        return vim.startswith(val, l[2])
      end, commands)
    end,
  })
end

-- Regular expression to parse filenames
local filename_regexp = [[(%d%d%d%d%d%d%d%dT%d%d%d%d%d%d)([-0-9A-Za-zÆØÅæøå]+)([_0-9a-zæøå]*).md$]]

---Parses a note filename into its components.
---@param filename string
---@return NoteInfo|nil
local function parse_filename(filename)
  local timestamp, title_string, tags_string = string.match(filename, filename_regexp)

  if not title_string then
    return nil
  end

  local title = vim.fn.join(vim.fn.split(title_string, "-"), " ") -- Convert hyphenated title back to space
  local tags = vim.fn.split(tags_string, "_") -- Split tags by underscore

  return {
    timestamp = timestamp,
    title = title,
    tags = tags,
  }
end

---Generates a valid filename for a note.
---@param opts { timestamp?: string, title: string, tags?: string[] }
---@return string
local function get_filename(opts)
  local timestamp = opts.timestamp or os.date("!%Y%m%dT%H%M%S", os.time()) -- Default to current timestamp if not provided

  local title = clean_title(opts.title) -- Clean the title

  -- Construct the initial filename
  local filename = timestamp .. "--" .. title

  local tags = {}

  -- Clean and sort tags
  for i, tag in ipairs(opts.tags or {}) do
    tags[i] = clean_tag(tag)
  end

  table.sort(tags)

  -- Append tags to filename if present
  if 0 < #tags then
    filename = filename .. "_"
    for _, tag in ipairs(tags) do
      filename = filename .. "_" .. clean_tag(tag)
    end
  end

  filename = filename .. ".md" -- Add file extension

  return filename
end

---Extracts tags from a filename.
---@param filename string
---@return string[]
local function tags_from_filename(filename)
  local parsed_filename = parse_filename(filename)
  if parsed_filename then
    return parsed_filename.tags
  else
    return {}
  end
end

---Renames the current file.
---@param new_filename string
local function rename_current_file(new_filename)
  local buf = vim.api.nvim_get_current_buf() -- Get the current buffer
  local modified = vim.api.nvim_get_option_value("modified", { buf = buf }) -- Check if the buffer is modified

  local lines = {}

  -- If modified, store the current lines
  if modified then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  local filename = vim.fn.expand("%") -- Get current filename
  local folder = vim.fn.expand("%:p:h") -- Get current folder
  local destination = folder .. "/" .. new_filename
  local current_filename = vim.fn.fnamemodify(filename, ":t")

  -- Case-insensitive filesystems cannot reliably rename a file when only its
  -- casing changes. Move it through the system temporary directory first.
  local case_only_rename = current_filename ~= new_filename
    and vim.fn.tolower(current_filename) == vim.fn.tolower(new_filename)
  if case_only_rename then
    local temporary_filename = vim.fn.tempname()
    os.rename(filename, temporary_filename)
    os.rename(temporary_filename, destination)
    vim.api.nvim_buf_set_name(buf, destination)
  else
    os.rename(filename, destination) -- Rename the file
  end

  vim.cmd("e! " .. destination) -- Open the new file
  local destination_buf = vim.api.nvim_get_current_buf()
  if modified then
    vim.api.nvim_buf_set_lines(destination_buf, 0, -1, false, lines) -- Restore lines if modified
  end

  if buf ~= destination_buf then
    vim.api.nvim_buf_delete(buf, { force = true }) -- Delete the old buffer
  end
end

---Creates a new note from the given text input.
---If no text is given the user is prompted for a title.
---
---Tags can be specified after the title by separating them with commas:
---This is the title, tag_one, tag_two
---@param text string|nil
function Notes:create(text)
  local title = text or vim.fn.input("Note: ")

  local parts = vim.fn.split(title, "\\s*,\\s*") -- Split input line by commas
  local filename = get_filename({
    title = parts[1],
    tags = { table.unpack(parts, 2) }, -- Remaining parts as tags
  })

  vim.cmd("e " .. self.dir .. "/" .. filename) -- Open the new note
end

---Find an existing note file or create a new one.
function Notes:find_note()
  local files = vim.fn.globpath(self.dir, "*.md", false, true)

  vim.ui.select(files, {
    prompt = "Find note",
    format_item = function(filename)
      return filename:match("([^/\\]+)$")
    end,
  }, function(filename)
    if filename then
      vim.cmd("e " .. filename)
    else
      vim.notify("No file selected", vim.log.levels.WARN)
    end
  end)
end

---Searches notes using live grep.
function Notes:search_notes()
  local query = vim.fn.input("Search for notes (regex): ")

  vim.cmd({ cmd = "vimgrep", args = { query, self.dir .. "/*.md" } })
end

---Insert a link to another note.
function Notes:link_to_note()
  local files = vim.fn.globpath(self.dir, "*.md", false, true)

  vim.ui.select(files, {
    prompt = "Link to note",
    format_item = function(filename)
      local file_info = parse_filename(filename)
      if not file_info then
        return ""
      end

      return file_info.title
    end,
  }, function(filename)
    if filename then
      local file_info = parse_filename(filename)

      if file_info then
        vim.api.nvim_put({ "[" .. file_info.title .. "](" .. file_info.timestamp .. ".id)" }, "c", true, true) -- Insert link
      else
        vim.notify("Could not parse filename", vim.log.levels.WARN)
      end
    else
      vim.notify("No file selected", vim.log.levels.WARN)
    end
  end)
end

---Retitles the current note.
function Notes:retitle()
  local filename = vim.fn.expand("%")

  if not (self.dir == vim.fn.expand("%:p:h")) then
    print_not_in_notes_dir()
    return
  end

  -- Prompt for new title
  local new_title = vim.fn.input("Enter a new title: ")

  if not new_title then
    return
  end

  local file_info = parse_filename(filename)

  if not file_info then
    return
  end

  file_info.title = new_title -- Update title
  local new_filename = get_filename(file_info) -- Generate new filename

  rename_current_file(new_filename) -- Rename the current file to the new filename
end

---Toggles a tag in the current note.
function Notes:toggle_tag()
  if not (self.dir == vim.fn.expand("%:p:h")) then
    print_not_in_notes_dir()
    return
  end

  local note_filename = vim.fn.expand("%")
  local file_info = parse_filename(note_filename)
  if not file_info then
    return
  end

  -- Gather existing tags from all note files
  local files = vim.fn.globpath(self.dir, "*.md", false, true)

  local tags_table = {}
  for _, filename in pairs(files) do
    for _, tag in pairs(tags_from_filename(filename)) do
      tags_table[tag] = true -- Initialize tags as not enabled
    end
  end

  local available_tags = {}
  for tag in pairs(tags_table) do
    -- Prepare tag list for selection
    table.insert(available_tags, tag)
  end

  table.sort(available_tags)

  ---Custom completion function for tag input.
  ---@param arg_lead string
  ---@param cmd_line string
  ---@param cursor_pos number
  ---@return string[]
  function NotesGetTags(arg_lead, cmd_line, cursor_pos)
    local result = {}

    for _, tag in ipairs(available_tags) do
      if arg_lead == string.sub(tag, 0, #arg_lead) then
        table.insert(result, tag)
      end
    end

    return result
  end

  local toggled_tag = vim.fn.input({
    prompt = "Toggle tag: ",
    default = "",
    completion = "customlist,v:lua.NotesGetTags",
  })

  local tags_state = {}
  for _, tag in ipairs(file_info.tags) do
    tags_state[tag] = true
  end

  tags_state[toggled_tag] = not tags_state[toggled_tag]

  local new_tags = {}
  for tag, enabled in pairs(tags_state) do
    if enabled then
      table.insert(new_tags, tag)
    end
  end

  -- Update note tags
  file_info.tags = new_tags
  local new_filename = get_filename(file_info) -- Generate new filename

  rename_current_file(new_filename) -- Rename the current file to the new filename
end

return Notes
