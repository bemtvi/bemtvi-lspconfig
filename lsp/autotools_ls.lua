---@brief
---
--- https://github.com/Freed-Wu/autotools-language-server
---
--- `autotools-language-server` can be installed via `pip`:
--- ```sh
--- pip install autotools-language-server
--- ```
---
--- Language server for autoconf, automake and make using tree sitter in python.

local util = require("bemtvi-lspconfig.util")

local root_files = { "configure.ac", "Makefile", "Makefile.am", "*.mk" }

return {
  cmd = { "autotools-language-server" },
  filetypes = { "config", "automake", "make" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    util.root_pattern(root_files)(fname):next(on_dir)
  end,
}
