---@brief
---
--- https://github.com/PMunch/nimlsp
---
--- `nimlsp` can be installed via the `nimble` package manager:
---
--- ```sh
--- nimble install nimlsp
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "nimlsp" },
  filetypes = { "nim" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    -- Pattern order is priority: the nimble project wins over an enclosing repo.
    util.root_pattern("*.nimble", ".git")(fname):next(on_dir)
  end,
}
