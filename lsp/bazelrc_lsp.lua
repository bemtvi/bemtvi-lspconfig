---@brief
---
--- https://github.com/salesforce-misc/bazelrc-lsp
---
--- `bazelrc-lsp` is a LSP for `.bazelrc` configuration files.
---
--- The `.bazelrc` file type is not detected automatically, you can register it manually (see below) or override the filetypes:
---
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.bazelrc" }, function()
---   btv.bo.filetype = "bazelrc"
--- end)
--- ```

return {
  cmd = { "bazelrc-lsp", "lsp" },
  filetypes = { "bazelrc" },
  root_markers = { "WORKSPACE", "WORKSPACE.bazel", "MODULE.bazel" },
}
