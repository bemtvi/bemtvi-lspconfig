---@brief
---
--- https://sr.ht/~whynothugo/hare-lsp/
---
--- Language server for hare.

return {
  cmd = { "hare-lsp", "-S" },
  filetypes = { "hare" },
  root_markers = { ".git" },
  workspace_required = false,
}
