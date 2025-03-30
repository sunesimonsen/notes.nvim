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
  tag = tag:gsub("[^_0-9a-zæøå]", "")
  return tag
end

local get_filename = function(opts)
  local timestamp = os.date("!%Y%m%dT%H%M%S", opts.timestamp or os.time())

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
