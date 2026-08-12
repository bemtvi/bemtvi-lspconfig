---@brief
---
--- https://github.com/FoamScience/foam-language-server
---
--- `foam-language-server` can be installed via `npm`
--- ```sh
--- npm install -g foam-language-server
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "foam-ls", "--stdio" },
  filetypes = { "foam", "OpenFOAM" },
  -- An OpenFOAM case is the directory holding `system/controlDict`; only when there is
  -- none above the file does the enclosing repo — then the file's own directory — stand
  -- in. The marker is a nested path rather than a plain name, so this walks the
  -- ancestors itself instead of declaring `root_markers`.
  root_dir = btv.async(function(bufnr)
    local fname = util.bufname(bufnr)
    for path in util.ancestors(fname) do
      if btv.await(util.exists(util.joinpath(path, "system/controlDict"))) then
        return path
      end
    end
    return btv.await(util.root(bufnr, { ".git" })) or util.dirname(fname)
  end),
}
