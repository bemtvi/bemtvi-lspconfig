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

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "regal", "language-server" },
  filetypes = { "rego" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    on_dir(
      util.root_pattern("*.rego")(fname)
        or util.dirname(vim.fs.find(".git", { path = fname, upward = true })[1])
    )
  end,
}
