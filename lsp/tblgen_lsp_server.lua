---@brief
---
--- https://mlir.llvm.org/docs/Tools/MLIRLSP/#tablegen-lsp-language-server--tblgen-lsp-server
---
--- The Language Server for the LLVM TableGen language
---
--- `tblgen-lsp-server` can be installed at the llvm-project repository (https://github.com/llvm/llvm-project)

local util = require("nxvim-lspconfig.util")

return {
  -- Point the server at the project's compilation database when there is one.
  -- Upstream resolves this at LOAD time from whatever buffer happened to be current,
  -- which pins one project's database into the whole session; searching from the root
  -- the server actually resolved gives each project its own.
  cmd = nx.async(function(_dispatchers, config)
    local cmd = { "tblgen-lsp-server" }
    local from = (config or {}).root_dir or util.cwd()
    -- Either beside the sources or inside the build tree, checked level by level so
    -- the nearest wins — the relative candidate can't be a `find_upward` NAME.
    for dir in util.ancestors(util.joinpath(from, "_")) do
      for _, rel in ipairs({
        "tablegen_compile_commands.yml",
        "build/tablegen_compile_commands.yml",
      }) do
        local candidate = util.joinpath(dir, rel)
        if nx.await(util.exists(candidate)) then
          table.insert(cmd, "--tablegen-compilation-database=" .. candidate)
          return cmd
        end
      end
    end
    return cmd
  end),
  filetypes = { "tablegen" },
  root_markers = { "tablegen_compile_commands.yml", ".git" },
}
