---@brief
---
--- https://github.com/hrsh7th/vscode-langservers-extracted
---
--- `vscode-html-language-server` can be installed via `npm`:
--- ```sh
--- npm i -g vscode-langservers-extracted
--- ```
---
--- `vscode-html-language-server` only provides completions when the client advertises
--- snippet support, which bemtvi's base capabilities do not — turn it on per server.
--- bemtvi expands the snippets itself (`btv.snippet`); no snippet plugin is needed.
---
--- The code-formatting feature of the lsp can be controlled with the `provideFormatter` option.
---
--- ```lua
--- -- Broadcast snippet support. A config's `capabilities` are deep-merged over
--- -- bemtvi's base client capabilities, so this adds the one field rather than
--- -- rebuilding the whole table.
--- btv.lsp.config('html', {
---   capabilities = {
---     textDocument = { completion = { completionItem = { snippetSupport = true } } },
---   },
--- })
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = util.node_cmd("vscode-html-language-server"),
  filetypes = { "html" },
  root_markers = { "package.json", ".git" },
  settings = {},
  init_options = {
    provideFormatter = true,
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { "html", "css", "javascript" },
  },
}
