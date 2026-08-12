---@brief
---
--- https://github.com/AlloyTools/org.alloytools.alloy
---
--- Alloy is a formal specification language for describing structures and a tool for exploring them.
---
--- You may also need to configure the filetype for Alloy (*.als) files:
---
--- ```
--- autocmd BufNewFile,BufRead *.als set filetype=alloy
--- ```
---
--- or
---
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.als" }, function()
---   btv.bo.filetype = "alloy"
--- end)
--- ```
---
--- Alternatively, you may use a syntax plugin like https://github.com/runoshun/vim-alloy.

return {
  cmd = { "alloy", "lsp" },
  filetypes = { "alloy" },
  root_markers = { ".git" },
}
