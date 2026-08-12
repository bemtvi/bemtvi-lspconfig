---@brief
---
--- https://github.com/fallow-rs/fallow
---
--- Codebase intelligence for TypeScript and JavaScript.

local util = require("bemtvi-lspconfig.util")

return {
  cmd = util.node_cmd("fallow-lsp", {}),
  filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
  root_markers = { ".fallowrc.json", ".git" },
  init_options = {
    -- Every issue type is enabled by default. List only the ones you
    -- want to turn off; any key you omit stays enabled.
    -- issueTypes = {
    --   ['circular-dependencies'] = false,
    -- },
  },
}
