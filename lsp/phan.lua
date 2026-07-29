---@brief
---
--- https://github.com/phan/phan
---
--- Installation: https://github.com/phan/phan#getting-started

local util = require("nxvim-lspconfig.util")

local cmd = {
  "phan",
  "-m",
  "json",
  "--no-color",
  "--no-progress-bar",
  "-x",
  "-u",
  "-S",
  "--language-server-on-stdin",
  "--allow-polyfill-parser",
}

return {
  cmd = cmd,
  filetypes = { "php" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    local cwd = util.cwd()
    util.root_of_path(fname, { "composer.json", ".git" }):next(function(root)
      -- prefer cwd if root is a descendant
      on_dir(root and util.relpath(cwd, root) and cwd)
    end)
  end,
}
