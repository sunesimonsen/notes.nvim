local Notes = {}

Notes.get_filename = function(opts)
  local timestamp = os.date("!%Y%m%dT%H%M%S", opts.timestamp or os.time())

  local title = opts.title

  title = title:lower()
  title = title:gsub(" ", "-")
  title = title:gsub("-+", "-")
  title = title:gsub("[^-0-9a-zæøå]", "")

  local filename = timestamp .. "--" .. title

  local tags = opts.tags or {}
  if 0 < #tags then
    filename = filename .. "_"
    for _, tag in ipairs(tags) do
      filename = filename .. "_" .. tag
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
        local filename = Notes.get_filename({
          dir = opts.dir,
          title = action_state.get_current_line(),
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
