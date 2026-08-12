---@brief
---
--- https://github.com/slint-ui/slint
--- `Slint`'s language server
---
--- You can build and install `slint-lsp` binary with `cargo`:
--- ```sh
--- cargo install slint-lsp
--- ```
---
--- Vim does not have built-in syntax for the `slint` filetype at this time.
---
--- This can be added via an autocmd:
---
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.slint" }, function()
---   btv.bo.filetype = "slint"
--- end)
--- ```

return {
  cmd = { "slint-lsp" },
  filetypes = { "slint" },
  root_markers = { ".git" },
}
