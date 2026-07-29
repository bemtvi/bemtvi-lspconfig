---@brief
---
--- https://github.com/nim-lang/langserver
---
---
--- `nim-langserver` can be installed via the `nimble` package manager:
--- ```sh
--- nimble install nimlangserver
--- ```

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "nimlangserver" },
  filetypes = { "nim" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    on_dir(
      util.root_pattern("*.nimble")(fname)
        or util.dirname(vim.fs.find(".git", { path = fname, upward = true })[1])
    )
  end,
}
