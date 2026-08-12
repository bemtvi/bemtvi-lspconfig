---@brief
---
--- Language server for programs written in Hack
--- https://hhvm.com/
--- https://github.com/facebook/hhvm
--- See below for how to setup HHVM & typechecker:
--- https://docs.hhvm.com/hhvm/getting-started/getting-started

return {
  -- The working directory has to be the project root rather than the editor's; bemtvi
  -- spawns every server there already.
  cmd = { "hh_client", "lsp", "--from", "bemtvi" },

  filetypes = { "php", "hack" },
  root_markers = { ".hhconfig" },
}
