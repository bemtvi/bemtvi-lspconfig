---@brief
---
--- https://github.com/unisonweb/unison/blob/trunk/docs/language-server.markdown

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "nc", "localhost", os.getenv("UNISON_LSP_PORT") or "5757" },
  filetypes = { "unison" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    on_dir(util.root_pattern("*.u")(fname))
  end,
  settings = {},
}
