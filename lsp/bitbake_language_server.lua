---@brief
---
--- https://github.com/Freed-Wu/bitbake-language-server
---
--- `bitbake-language-server` can be installed via `pip`:
--- ```sh
--- pip install bitbake-language-server
--- ```
---
--- Language server for bitbake.

return {
  cmd = { "bitbake-language-server" },
  filetypes = { "bitbake" },
  root_markers = { ".git" },
}
