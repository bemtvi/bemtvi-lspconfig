---@brief
---
--- https://github.com/tintoy/msbuild-project-tools-server/
---
--- MSBuild Project Tools Server can be installed by following the README.MD on the above repository.
---
--- Example config:
--- ```lua
--- nx.lsp.config('msbuild_project_tools_server', {
---   cmd = {'dotnet', '/path/to/server/MSBuildProjectTools.LanguageServer.Host.dll'}
--- })
--- ```
---
--- There's no builtin filetypes for msbuild files, would require some filetype aliases:
---
--- nxvim has no filetype-table API; a filetype is set by `:setfiletype` from an
--- autocmd, whose `pattern` is a glob matched against the buffer's path:
---
--- ```lua
--- nx.autocmd.create({ 'BufReadPost', 'BufNewFile' }, {
---   pattern = { '*.props', '*.tasks', '*.targets', '*proj' },
---   callback = function()
---     nx.cmd('setfiletype msbuild')
---   end,
--- })
--- ```
---
--- For syntax highlighting, set the filetype to `xml` instead and let the msbuild
--- server attach anyway — this config declares `msbuild`, so add `xml` to its
--- filetypes rather than aliasing the grammar (nxvim has no filetype-to-grammar
--- alias table):
---
--- ```lua
--- nx.lsp.config('msbuild_project_tools_server', { filetypes = { 'msbuild', 'xml' } })
--- ```

local host_dll_name = "MSBuildProjectTools.LanguageServer.Host.dll"
local util = require("nxvim-lspconfig.util")

return {
  filetypes = { "msbuild" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    on_dir(util.root_pattern("*.sln", "*.slnx", "*.*proj", ".git")(fname))
  end,
  init_options = {},
  cmd = { "dotnet", host_dll_name },
}
