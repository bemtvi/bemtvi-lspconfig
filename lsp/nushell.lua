---@brief
---
--- https://github.com/nushell/nushell
---
--- Nushell built-in language server.

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "nu", "--lsp" },
  filetypes = { "nu" },
  root_dir = function(bufnr, on_dir)
    util.root(bufnr, { ".git" }):next(function(root)
      on_dir(root or util.dirname(util.bufname(bufnr)))
    end)
  end,
}
