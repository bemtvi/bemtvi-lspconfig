---@brief
---
--- https://github.com/razzmatazz/csharp-language-server
---
--- Language Server for C#.
---
--- csharp-ls requires the [dotnet-sdk](https://dotnet.microsoft.com/download) to be installed.
---
--- The preferred way to install csharp-ls is with `dotnet tool install --global csharp-ls`.

local util = require("bemtvi-lspconfig.util")

return {
  -- csharp-ls locates the sln / slnx / csproj from its working directory, which bemtvi
  -- already sets to the resolved root for every server it spawns.
  cmd = { "csharp-ls" },
  root_dir = function(bufnr, on_dir)
    -- Pattern order is priority: a solution roots the server ahead of a project file
    -- even when the project file is nearer.
    util.root_pattern("*.sln", "*.slnx", "*.csproj")(util.bufname(bufnr)):next(on_dir)
  end,
  filetypes = { "cs" },
  init_options = {
    AutomaticWorkspaceInit = true,
  },
  get_language_id = function(_, ft)
    if ft == "cs" then
      return "csharp"
    end
    return ft
  end,
}
