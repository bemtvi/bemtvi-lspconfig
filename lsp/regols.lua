---@brief
---
--- https://github.com/kitagry/regols
---
--- OPA Rego language server.
---
--- `regols` can be installed by running:
--- ```sh
--- go install github.com/kitagry/regols@latest
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "regols" },
  filetypes = { "rego" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    -- Pattern order is priority: a rego source tree wins over an enclosing repo.
    util.root_pattern("*.rego", ".git")(fname):next(on_dir)
  end,
}
