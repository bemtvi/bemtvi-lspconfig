---@brief
---
--- https://github.com/japhib/pico8-ls
---
--- Full language support for the PICO-8 dialect of Lua.

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "pico8-ls", "--stdio" },
  filetypes = { "p8" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    on_dir(util.root_pattern("*.p8")(fname))
  end,
  settings = {},
}
