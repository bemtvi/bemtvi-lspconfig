---@brief
---
--- https://muon.build

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "muon", "analyze", "lsp" },
  filetypes = { "meson" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    local cmd = { "muon", "analyze", "root-for", fname }
    util.system(cmd):next(function(output)
      if output.code ~= 0 then
        return btv.notify(
          ("[muon] cmd failed with code %d: %s\n%s"):format(
            output.code,
            btv.inspect(cmd),
            output.stderr
          ),
          btv.log.levels.ERROR
        )
      end
      on_dir(output.stdout and btv.str.trim(output.stdout) or nil)
    end)
  end,
}
