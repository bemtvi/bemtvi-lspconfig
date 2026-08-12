---@brief
---
--- https://codeberg.org/caradhras/uvls
--- Language server for UVL, written using tree sitter and rust.
--- You can install the server easily using cargo:
--- ```sh
--- git clone https://codeberg.org/caradhras/uvls
--- cd  uvls
--- cargo install --path .
--- ```
---
--- Note: To activate properly nvim needs to know the uvl filetype.
--- You can add it via:
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.uvl" }, function()
---   btv.bo.filetype = "uvl"
--- end)
--- ```

return {
  cmd = { "uvls" },
  filetypes = { "uvl" },
  root_markers = { ".git" },
}
