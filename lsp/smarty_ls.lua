---@brief
---
--- https://github.com/landeaux/vscode-smarty-langserver-extracted
---
--- Language server for Smarty.
---
--- `smarty-language-server` can be installed via `npm`:
---
--- ```sh
--- npm i -g vscode-smarty-langserver-extracted
--- ```

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "smarty-language-server", "--stdio" },
  filetypes = { "smarty" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    local cwd = util.cwd()
    util.root_of_path(fname, { "composer.json", ".git" }):next(function(root)
      -- prefer cwd if root is a descendant
      on_dir(root and util.relpath(cwd, root) and cwd)
    end)
  end,
  settings = {
    smarty = {
      pluginDirs = {},
    },
    css = {
      validate = true,
    },
  },
  init_options = {
    storageDir = nx.json.null,
  },
}
