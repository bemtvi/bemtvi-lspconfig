---@brief
---
--- https://www.devsense.com/
---
--- `devsense-php-ls` can be installed via `npm`:
--- ```sh
--- npm install -g devsense-php-ls
--- ```
---
--- ```lua
--- -- See https://www.npmjs.com/package/devsense-php-ls
--- init_options = {
--- }
--- -- See https://docs.devsense.com/vscode/configuration/
--- settings = {
---   php = {
---   };
--- }
--- ```

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "devsense-php-ls", "--stdio" },
  filetypes = { "php" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    local cwd = util.cwd()
    util.root_of_path(fname, { "composer.json", ".git" }):next(function(root)
      -- prefer cwd if root is a descendant
      on_dir(root and util.relpath(cwd, root) and cwd)
    end)
  end,
  init_options = {
    ["0"] = "{}", --optional premium license validation from https://www.devsense.com/purchase/validation
  },
}
