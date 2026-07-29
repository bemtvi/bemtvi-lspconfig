---@brief
---
--- https://github.com/hylo-lang/hylo-language-server
---
--- A language server for the Hylo programming language.

return {
  cmd = { "hylo-language-server", "--stdio" },
  filetypes = { "hylo" },
  root_markers = { ".git" },
  settings = {},
}
