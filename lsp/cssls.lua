---@brief
---
--- https://github.com/hrsh7th/vscode-langservers-extracted
---
--- `css-languageserver` can be installed via `npm`:
---
--- ```sh
--- npm i -g vscode-langservers-extracted
--- ```
---
--- `vscode-css-language-server` only provides completions when the client advertises
--- snippet support, which nxvim's base capabilities do not — turn it on per server.
--- nxvim expands the snippets itself (`nx.snippet`); no snippet plugin is needed.
---
--- ```lua
--- -- Broadcast snippet support. A config's `capabilities` are deep-merged over
--- -- nxvim's base client capabilities, so this adds the one field rather than
--- -- rebuilding the whole table.
--- nx.lsp.config('cssls', {
---   capabilities = {
---     textDocument = { completion = { completionItem = { snippetSupport = true } } },
---   },
--- })
--- ```

local util = require("nxvim-lspconfig.util")

return {
  cmd = util.node_cmd("vscode-css-language-server"),
  filetypes = { "css", "scss", "less" },
  init_options = { provideFormatter = true }, -- needed to enable formatting capabilities
  root_markers = { "package.json", ".git" },
  settings = {
    css = { validate = true },
    scss = { validate = true },
    less = { validate = true },
  },
}
