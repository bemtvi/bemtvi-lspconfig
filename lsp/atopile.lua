---@brief
---
--- https://atopile.io/
---
--- A language server for atopile Programming Language.
---
--- It comes with the atopile compiler, for installation see: [Installing atopile](https://docs.atopile.io/atopile/guides/install)

return {
  cmd = { "ato", "lsp", "start" },
  filetypes = { "ato" },
  root_markers = { "ato.yaml", ".ato", ".git" },
}
