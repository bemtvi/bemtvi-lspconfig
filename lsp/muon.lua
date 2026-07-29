---@brief
---
--- https://muon.build

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "muon", "analyze", "lsp" },
  filetypes = { "meson" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    local cmd = { "muon", "analyze", "root-for", fname }
    util.system(cmd):next(function(output)
      if output.code ~= 0 then
        return nx.notify(
          ("[muon] cmd failed with code %d: %s\n%s"):format(
            output.code,
            nx.inspect(cmd),
            output.stderr
          ),
          nx.log.levels.ERROR
        )
      end
      on_dir(output.stdout and nx.str.trim(output.stdout) or nil)
    end)
  end,
}
