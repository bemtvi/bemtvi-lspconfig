---@brief
---
--- https://github.com/StyraInc/regal
---
--- A linter for Rego, with support for running as an LSP server.
---
--- `regal` can be installed by running:
--- ```sh
--- go install github.com/StyraInc/regal@latest
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "regal", "language-server" },
  filetypes = { "rego" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    -- Pattern order is priority: a rego source tree wins over an enclosing repo.
    util.root_pattern("*.rego", ".git")(fname):next(on_dir)
  end,
}
