local notes_builtin = require("telescope._extensions.notes_builtin")

return require("telescope").register_extension({
  setup = notes_builtin.setup,
  exports = {
    find_note = notes_builtin.find_note,
  },
})
