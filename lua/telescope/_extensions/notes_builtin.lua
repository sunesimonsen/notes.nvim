local M = {}

M.setup = function()
  local notes = require("notes")
  if not notes.dir then
    vim.notify("telescope._extensions.notes: `notes.nvim` is not loaded!", vim.log.levels.ERROR)
    return
  end
end

M.find_note = function(opts)
  local notes = require("notes")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local create_from_prompt = function()
    local line = require("telescope.actions.state").get_current_line()
    notes:create(line)
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
        vim.cmd("e " .. notes.dir .. "/" .. selection[1]) -- Open the selected note
      else
        vim.notify("No file selected", vim.log.levels.WARN)
      end
    end)
    return true
  end

  opts = opts or {}
  opts.cwd = notes.dir
  opts.attach_mappings = run_selection
  require("telescope.builtin").find_files(opts)
end

M.search_notes = function(opts)
  local notes = require("notes")
  opts = opts or {}
  opts.cwd = notes.dir
  require("telescope.builtin").live_grep(opts)
end

return M
