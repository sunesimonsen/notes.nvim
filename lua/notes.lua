local Notes = {}

local function clean_title(title)
  title = title:lower()
  title = title:gsub(" ", "-")
  title = title:gsub("-+", "-")
  title = title:gsub("[^-0-9a-zæøå]", "")
  return title
end

local function clean_tag(tag)
  tag = tag:lower()
  tag = tag:gsub(" ", "-")
  tag = tag:gsub("_+", "_")
  tag = tag:gsub("[^0-9a-zæøå]", "")
  return tag
end

local filename_regexp = [[(%d%d%d%d%d%d%d%dT%d%d%d%d%d%d)([-0-9a-zæøå]+)([_0-9a-zæøå]*).md$]]
local function parse_filename(filename)
  local timestamp, title_string, tags_string = string.match(filename, filename_regexp)

  if not title_string then
    return nil
  end

  local title = vim.fn.join(vim.fn.split(title_string, "-"), " ")
  local tags = vim.fn.split(tags_string, "_")

  return {
    timestamp = timestamp,
    title = title,
    tags = tags,
  }
end

local function get_filename(opts)
  local timestamp = opts.timestamp or os.date("!%Y%m%dT%H%M%S", os.time())

  local title = clean_title(opts.title)

  local filename = timestamp .. "--" .. title

  local tags = {}

  for i, tag in ipairs(opts.tags or {}) do
    tags[i] = clean_tag(tag)
  end

  table.sort(tags)

  if 0 < #tags then
    filename = filename .. "_"
    for _, tag in ipairs(tags) do
      filename = filename .. "_" .. clean_tag(tag)
    end
  end

  filename = filename .. ".md"

  return filename
end

local function tags_from_filename(filename)
  local parsed_filename = parse_filename(filename)
  if parsed_filename then
    return parsed_filename.tags
  else
    return {}
  end
end

local function file_exists(filename)
  local file = io.open(filename, "r")
  if file then
    io.close(file)
    return true
  else
    return false
  end
end

local function rename_current_file(new_filename)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local buf = vim.api.nvim_get_current_buf()

  local filename = vim.fn.expand("%")
  local folder = vim.fn.expand("%:p:h")
  local exists = file_exists(filename)
  if exists then
    -- Reload content from file
    vim.cmd("!cp % " .. folder .. "/" .. new_filename)
  end

  vim.cmd("e! " .. folder .. "/" .. new_filename)
  vim.api.nvim_buf_delete(buf, { force = true })

  if exists then
    -- Resmove old file
    vim.cmd("!rm " .. filename)
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

Notes.toggle_tag = function(opts)
  if not (opts.dir == vim.fn.expand("%:p:h")) then
    print("Not in a note file")
    return
  end

  local tags_table = {}

  local files = vim.fn.split(vim.fn.globpath(opts.dir, "*.md"), "\n")

  for _, filename in pairs(files) do
    for _, tag in pairs(tags_from_filename(filename)) do
      tags_table[tag] = false
    end
  end

  local filename = vim.fn.expand("%:p:t")
  for _, tag in pairs(tags_from_filename(filename)) do
    tags_table[tag] = true
  end

  local available_tags = {}
  for tag, enabled in pairs(tags_table) do
    table.insert(available_tags, { tag = tag, enabled = enabled })
  end

  table.sort(available_tags, function(a, b)
    return a.tag > b.tag
  end)

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
    local file_info = parse_filename(filename)
    tags_table[selected.tag] = not selected.enabled

    local tags = {}
    for tag, enabled in pairs(tags_table) do
      if enabled then
        table.insert(tags, tag)
      end
    end

    local new_filename = get_filename({
      timestamp = file_info.timestamp,
      title = file_info.title,
      tags = tags,
    })

    rename_current_file(new_filename)
  end)
end

Notes.find_note = function(opts)
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local function run_selection(prompt_bufnr)
    actions.select_default:replace(function()
      actions.close(prompt_bufnr)
      local selection = action_state.get_selected_entry()

      if selection then
        vim.cmd("e " .. opts.dir .. "/" .. selection[1])
      else
        local line = action_state.get_current_line()
        local parts = vim.fn.split(line, "\\s*,\\s*")
        local filename = get_filename({
          dir = opts.dir,
          title = parts[1],
          tags = { table.unpack(parts, 2) },
        })

        vim.cmd("e " .. opts.dir .. "/" .. filename)
      end
    end)
    return true
  end

  require("telescope.builtin").find_files({
    cwd = opts.dir,
    attach_mappings = run_selection,
  })
end

Notes.search_notes = function(opts)
  require("telescope.builtin").live_grep({ cwd = opts.dir })
end

Notes.link_to_note = function(opts)
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local function run_selection(prompt_bufnr)
    actions.select_default:replace(function()
      local selection = action_state.get_selected_entry()

      if selection then
        actions.close(prompt_bufnr)

        local filename = selection[1]
        local id = filename:sub(1, 15)
        local title_end = filename:find("[_.]", 18)
        local title = filename:sub(18, title_end - 1):gsub("-", " ")

        vim.api.nvim_put({ "[" .. title .. "](" .. id .. ".id)" }, "c", true, true)
      else
        print("No file selected")
      end
    end)
    return true
  end

  require("telescope.builtin").find_files({
    cwd = opts.dir,
    attach_mappings = run_selection,
  })
end

return Notes
