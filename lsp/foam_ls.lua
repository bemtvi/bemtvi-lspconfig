---@brief
---
--- https://github.com/FoamScience/foam-language-server
---
--- `foam-language-server` can be installed via `npm`
--- ```sh
--- npm install -g foam-language-server
--- ```

return {
  cmd = { "foam-ls", "--stdio" },
  filetypes = { "foam", "OpenFOAM" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    for path in util.ancestors(fname) do
      if vim.uv.fs_stat(path .. "/system/controlDict") then
        on_dir(path)
        return
      end
    end
    local git_root = vim.fs.root(bufnr, { ".git" })
    if git_root then
      on_dir(git_root)
      return
    end
    on_dir(util.dirname(fname))
  end,
}
