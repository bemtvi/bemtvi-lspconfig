---@brief
---
--- https://github.com/JCWasmx86/mesonlsp
---
--- An unofficial, unendorsed language server for meson written in C++

local util = require("bemtvi-lspconfig.util")

---Does `dir` hold the meson.build that DECLARES the project? A meson tree has a
---`meson.build` in every subdirectory, but only the top one opens with `project()` —
---the rest are includes, and rooting the server at one of those loses the build graph.
---The first non-blank, non-comment statement decides it.
local declares_project = btv.async(function(dir)
  local text = btv.await(btv.fs.read_text(util.joinpath(dir, "meson.build")):catch(function()
    return nil
  end))
  if type(text) ~= "string" then
    return false
  end
  for line in text:gmatch("[^\n]*") do
    -- skip meson comments
    if not line:match("^%s*#.*") then
      local str = line:gsub("%s+", "")
      if str ~= "" then
        return str:match("^project%(") ~= nil
      end
    end
  end
  return false
end)

return {
  cmd = { "mesonlsp", "--lsp" },
  filetypes = { "meson" },
  root_dir = btv.async(function(bufnr)
    local fname = util.bufname(bufnr)
    for dir in util.ancestors(fname) do
      if btv.await(declares_project(dir)) then
        return dir
      end
    end
    return btv.await(util.root(bufnr, { ".git" }))
  end),
}
