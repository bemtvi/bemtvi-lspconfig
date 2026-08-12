---@brief
---
--- https://github.com/facebook/buck2
---
--- Build system, successor to Buck
---
--- To better detect Buck2 project files, the following can be added:
---
--- ```
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = { "*.bxl", "BUCK", "TARGETS" } }, function()
---   btv.bo.filetype = "bzl"
--- end)
--- ```

return {
  cmd = { "buck2", "lsp" },
  filetypes = { "bzl" },
  root_markers = { ".buckconfig" },
}
