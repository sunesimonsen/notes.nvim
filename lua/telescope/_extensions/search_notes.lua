local notes_builtin = require("telescope._extensions.notes_builtin")

return require("telescope").register_extension({
  setup = notes_builtin.setup,
  exports = {
    search_notes = notes_builtin.search_notes,
  },
})
