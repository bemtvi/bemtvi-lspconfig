---@brief
---
--- https://github.com/ribru17/ts_query_ls
--- Can be configured by passing a "settings" object to `nx.lsp.config('ts_query_ls', {})`:
--- ```lua
--- nx.lsp.config('ts_query_ls', {
---   init_options = {
---     parser_install_directories = {
---       '/my/parser/install/dir',
---     },
---     -- This setting is provided by default
---     parser_aliases = {
---       ecma = 'javascript',
---       jsx = 'javascript',
---       php_only = 'php',
---     },
---   },
--- })
--- ```

-- Disable the (slow) built-in query linter, which will show duplicate diagnostics. This must be done before the query
-- ftplugin is sourced.
nx.g.query_lint_on = {}

return {
  cmd = { "ts_query_ls" },
  filetypes = { "query" },
  root_markers = { ".tsqueryrc.json", ".git" },
  init_options = {
    parser_aliases = {
      ecma = "javascript",
      jsx = "javascript",
      php_only = "php",
    },
    parser_install_directories = {
      nx.utils.joinpath(nx.stdpath("data"), "site/parser"),
    },
  },
  -- Upstream points `'omnifunc'` at neovim's `vim.lsp.omnifunc` so `<C-x><C-o>` asks
  -- the server. nxvim has no `'omnifunc'` hook into LSP — completion is `nx.complete`,
  -- whose `lsp` source serves this buffer already once the server is attached — so
  -- there is nothing to set here and setting a dead Vimscript expression would only
  -- make `<C-x><C-o>` fail obscurely.
}
