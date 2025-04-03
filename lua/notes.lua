-- Define a module for managing notes
local Notes = {}

--- Global variable to store the directory for notes
--- @type string
vim.g.notes_dir = nil

--- @class FileInto options for get_filename
--- @field timestamp string The timestamp of the note
--- @field title string The title of the note
--- @field tags table<string> The tags of the note

--- @class SelectableTag
--- @field tag string The tag name
--- @field enabled boolean If the tag is enabled for the note

--- Cleans the title string for filenames
--- @param title string The title to clean
--- @return string The cleaned title
local function clean_title(title)
  title = title:lower() -- Convert to lowercase
  title = title:gsub(" ", "-") -- Replace spaces with hyphens
  title = title:gsub("-+", "-") -- Replace multiple hyphens with a single hyphen
  title = title:gsub("[^-0-9a-zæøå]", "") -- Remove invalid characters
  return title
end

--- Cleans the tag string for filenames
--- @param tag string The tag to clean
--- @return string cleaned_tag The cleaned tag
local function clean_tag(tag)
  tag = tag:lower() -- Convert to lowercase
  tag = tag:gsub(" ", "-") -- Replace spaces with hyphens
  tag = tag:gsub("_+", "_") -- Replace multiple underscores with a single underscore
  tag = tag:gsub("[^0-9a-zæøå]", "") -- Remove invalid characters
  return tag
end

--- Retrieves the notes directory from the global variable
--- Fails if vim.g.notes_dir isn't set.
--- @return string notes_dir The notes directory
local function get_notes_dir()
  if vim.g.notes_dir == nil then
    error({ message = "Please set vim.g.notes_dir to your notes directory" })
  end

  return vim.g.notes_dir
end

-- Regular expression to parse filenames
local filename_regexp = [[(%d%d%d%d%d%d%d%dT%d%d%d%d%d%d)([-0-9a-zæøå]+)([_0-9a-zæøå]*).md$]]

--- Parses a filename to extract timestamp, title, and tags
--- @param filename string The filename to parse
--- @return FileInto|nil file_info A table containing timestamp, title, and tags or nil if parsing fails
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

--- Generates a filename based on provided options
--- @param opts FileInto Options containing timestamp, title, and tags
--- @return string filename The generated filename
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

--- Extracts tags from a given filename
--- @param filename string - The filename to extract tags from
--- @return table<string> tags A list of tags or an empty table if none found
local function tags_from_filename(filename)
  local parsed_filename = parse_filename(filename)
  if parsed_filename then
    return parsed_filename.tags
  else
    return {}
  end
end

--- Renames the current file to a new filename
--- @param new_filename string The new filename to rename to
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

--- Wraps a callback function to handle errors gracefully
--- @param cb function - The callback function to wrap
--- @return function function_with_error_handling A new function that handles errors
local function with_errors_printed(cb)
  return function(...)
    local cb_arg = arg
    local result, err = pcall(function()
      cb(unpack(cb_arg))
    end)

    if err then
      if err.mesasge then
        print(err.message)
      else
        print(err)
      end
    end

    return result
  end
end

-- Toggles tags for the current note
Notes.toggle_tag = with_errors_printed(function()
  if not (get_notes_dir() == vim.fn.expand("%:p:h")) then
    error({ message = "Not in a note file: " .. vim.fn.expand("%") })
  end

  local tags_table = {}

  local note_filename = vim.fn.expand("%")
  for _, tag in pairs(tags_from_filename(note_filename)) do
    tags_table[tag] = true -- Mark current file's tags as enabled
  end

  -- Gather existing tags from all note files
  local files = vim.fn.split(vim.fn.globpath(get_notes_dir(), "*.md"), "\n")

  for _, filename in pairs(files) do
    for _, tag in pairs(tags_from_filename(filename)) do
      tags_table[tag] = false -- Initialize tags as not enabled
    end
  end

  --- @type SelectableTag[]
  local available_tags = {}
  for tag, enabled in pairs(tags_table) do
    -- Prepare tag list for selection
    table.insert(available_tags, { tag = tag, enabled = enabled })
  end

  table.sort(available_tags, function(a, b)
    return a.tag > b.tag
  end)

  -- Prompt user to select a tag to toggle
  vim.ui.select(available_tags, {
    prompt = "Select a tag to toggle",
    format_item = function(item)
      if item.enabled then
        return "☑ " .. item.tag
      else
        return "☐ " .. item.tag
      end
    end,
  }, function(selected)
    if not selected then
      return
    end

    tags_table[selected.tag] = not selected.enabled -- Toggle the selected tag

    local tags = {}
    for tag, enabled in pairs(tags_table) do
      if enabled then
        -- Collect enabled tags
        table.insert(tags, tag)
      end
    end

    local file_info = parse_filename(note_filename)
    if not file_info then
      error({ message = "Not in a note file: " .. note_filename })
    end

    local new_filename = get_filename({
      timestamp = file_info.timestamp,
      title = file_info.title,
      tags = tags,
    })

    -- Rename the current file with updated tags
    rename_current_file(new_filename)
  end)
end)

-- Finds and opens a note file
Notes.find_note = with_errors_printed(function()
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local notes_dir = get_notes_dir()

  -- Function to handle selection from the note search
  local function run_selection(prompt_bufnr)
    actions.select_default:replace(function()
      actions.close(prompt_bufnr)
      local selection = action_state.get_selected_entry()

      if selection then
        vim.cmd("e " .. notes_dir .. "/" .. selection[1]) -- Open the selected note
      else
        local line = action_state.get_current_line()
        local parts = vim.fn.split(line, "\\s*,\\s*") -- Split input line by commas
        local filename = get_filename({
          dir = notes_dir,
          title = parts[1],
          tags = { table.unpack(parts, 2) }, -- Remaining parts as tags
        })

        vim.cmd("e " .. notes_dir .. "/" .. filename) -- Open the new note
      end
    end)
    return true
  end

  require("telescope.builtin").find_files({
    cwd = notes_dir,
    attach_mappings = run_selection,
  })
end)

-- Searches notes using live grep
Notes.search_notes = with_errors_printed(function()
  require("telescope.builtin").live_grep({ cwd = get_notes_dir() })
end)

-- Links to another note
Notes.link_to_note = with_errors_printed(function()
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  -- Function to handle selection from the note link search
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
        print("No file selected")
      end
    end)
    return true
  end

  require("telescope.builtin").find_files({
    cwd = get_notes_dir(),
    attach_mappings = run_selection,
  })
end)

-- Retitles the current note
Notes.retitle = with_errors_printed(function()
  local filename = vim.fn.expand("%")

  if not (get_notes_dir() == vim.fn.expand("%:p:h")) then
    error({ message = "Not in a note file: " .. filename })
  end

  -- Prompt for new title
  local new_title = vim.fn.input("Enter a new title: ")

  if not new_title then
    return
  end

  local file_info = parse_filename(filename)

  if not file_info then
    error({ message = "Not in a note file: " .. filename })
  end

  file_info.title = new_title -- Update title
  local new_filename = get_filename(file_info) -- Generate new filename

  rename_current_file(new_filename) -- Rename the current file to the new filename
end)

return Notes
