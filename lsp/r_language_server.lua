---@brief
---
--- [languageserver](https://github.com/REditorSupport/languageserver) is an
--- implementation of the Microsoft's Language Server Protocol for the R
--- language.
---
--- It is released on CRAN and can be easily installed by
---
--- ```r
--- install.packages("languageserver")
--- ```

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "R", "--no-echo", "-e", "languageserver::run()" },
  filetypes = { "r", "rmd", "quarto" },
  root_dir = function(bufnr, on_dir)
    util.root(bufnr, { ".git" }):next(function(root)
      on_dir(root or util.home())
    end)
  end,
}
