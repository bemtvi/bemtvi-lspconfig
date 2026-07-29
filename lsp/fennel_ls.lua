---@brief
---
--- https://sr.ht/~xerool/fennel-ls/
---
--- A language server for fennel.
---
--- fennel-ls is configured using the closest file to your working directory named `flsproject.fnl`.
--- All fennel-ls configuration options [can be found here](https://git.sr.ht/~xerool/fennel-ls/tree/HEAD/docs/manual.md#configuration).

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "fennel-ls" },
  filetypes = { "fennel" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    util.root_of_path(fname, { "flsproject.fnl" }):next(function(project)
      if project then
        return on_dir(project)
      end
      util.root(bufnr, { ".git" }):next(on_dir)
    end)
  end,
  settings = {},
  capabilities = {
    offsetEncoding = { "utf-8", "utf-16" },
  },
}
