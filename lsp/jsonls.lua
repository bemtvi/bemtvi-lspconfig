---@brief
---
--- https://github.com/hrsh7th/vscode-langservers-extracted
---
--- vscode-json-language-server, a language server for JSON and JSON schema
---
--- `vscode-json-language-server` can be installed via `npm`:
--- ```sh
--- npm i -g vscode-langservers-extracted
--- ```
---
--- `vscode-json-language-server` only provides completions when the client advertises
--- snippet support, which bemtvi's base capabilities do not — turn it on per server.
--- bemtvi expands the snippets itself (`btv.snippet`); no snippet plugin is needed.
---
--- ```lua
--- -- Broadcast snippet support. A config's `capabilities` are deep-merged over
--- -- bemtvi's base client capabilities, so this adds the one field rather than
--- -- rebuilding the whole table.
--- btv.lsp.config('jsonls', {
---   capabilities = {
---     textDocument = { completion = { completionItem = { snippetSupport = true } } },
---   },
--- })
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = util.node_cmd("vscode-json-language-server"),
  filetypes = { "json", "jsonc" },
  init_options = {
    provideFormatter = true,
  },
  root_markers = { ".git" },
}
