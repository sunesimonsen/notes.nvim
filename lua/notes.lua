---@class NoteInfo
---@field timestamp string
---@field title string
---@field tags string[]

---@class NotesPlugin
---@field dir string
local Notes = {
  dir = "",
}

---Cleans a title string by converting to lowercase, replacing spaces with
---hyphens and removing invalid characters.
---@param title string
---@return string
local function clean_title(title)
  title = title:lower() -- Convert to lowercase
  title = title:gsub(" ", "-") -- Replace spaces with hyphens
  title = title:gsub("-+", "-") -- Replace multiple hyphens with a single hyphen
  title = title:gsub("[^-0-9a-zæøå]", "") -- Remove invalid characters
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

  Notes.dir = opts.dir

  local commands = { "find", "link_to_note", "retitle", "search", "toggle_tag" }
  vim.api.nvim_create_user_command("Notes", function(command_opts)
    local args = command_opts.args
    if args == "find" then
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
local filename_regexp = [[(%d%d%d%d%d%d%d%dT%d%d%d%d%d%d)([-0-9a-zæøå]+)([_0-9a-zæøå]*).md$]]

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

  os.rename(filename, folder .. "/" .. new_filename) -- Rename the file

  vim.cmd("e! " .. folder .. "/" .. new_filename) -- Open the new file
  if modified then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines) -- Restore lines if modified
  end

  vim.api.nvim_buf_delete(buf, { force = true }) -- Delete the old buffer

  os.remove(filename) -- Remove the old file
end

---Find an existing note file or create a new one.
function Notes:find_note()
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local notes_dir = self.dir

  ---Creates a new note from the given text input.
  ---@param text string
  local function create_from_text(text)
    local parts = vim.fn.split(text, "\\s*,\\s*") -- Split input line by commas
    local filename = get_filename({
      title = parts[1],
      tags = { table.unpack(parts, 2) }, -- Remaining parts as tags
    })

    vim.cmd("e " .. notes_dir .. "/" .. filename) -- Open the new note
  end

  local create_from_prompt = function()
    local line = require("telescope.actions.state").get_current_line()
    create_from_text(line)
  end

  ---Handles selection from the note search.
  ---@param prompt_bufnr number
  ---@param map fun(mode: string, lhs: string, rhs: fun()): any
  local function run_selection(prompt_bufnr, map)
    map("i", "<S-CR>", function()
      actions.close(prompt_bufnr)
      create_from_prompt()
    end)

    actions.select_default:replace(function()
      actions.close(prompt_bufnr)
      local selection = action_state.get_selected_entry()

      if selection then
        vim.cmd("e " .. notes_dir .. "/" .. selection[1]) -- Open the selected note
      else
        local line = action_state.get_current_line()
        create_from_text(line)
      end
    end)
    return true
  end

  require("telescope.builtin").find_files({
    cwd = notes_dir,
    attach_mappings = run_selection,
  })
end

---Searches notes using live grep.
function Notes:search_notes()
  require("telescope.builtin").live_grep({ cwd = self.dir })
end

---Insert a link to another note.
function Notes:link_to_note()
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  ---Handles selection from the note link search.
  ---@param prompt_bufnr number
  local function run_selection(prompt_bufnr)
    actions.select_default:replace(function()
      local selection = action_state.get_selected_entry()

      if selection then
        actions.close(prompt_bufnr)

        local filename = selection[1]
        -- Extract ID from filename
        local id = filename:sub(1, 15)
        local title_end = filename:find("[_.]", 18)
        -- Convert hyphenated title back to spaces
        local title = filename:sub(18, title_end - 1):gsub("-", " ")

        vim.api.nvim_put({ "[" .. title .. "](" .. id .. ".id)" }, "c", true, true) -- Insert link
      else
        vim.notify("No file selected", vim.log.levels.WARN)
      end
    end)
    return true
  end

  require("telescope.builtin").find_files({
    cwd = self.dir,
    attach_mappings = run_selection,
  })
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
  local files = vim.fn.split(vim.fn.globpath(self.dir, "*.md"), "\n")

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
