---@brief
---
--- https://github.com/mathworks/MATLAB-language-server
---
--- MATLAB® language server implements the Microsoft® Language Server Protocol for the MATLAB language.
---
--- Make sure to set `MATLAB.installPath` to your MATLAB path, e.g.:
--- ```lua
--- settings = {
---   MATLAB = {
---     ...
---     installPath = '/usr/local/MATLAB/R2023a',
---     ...
---   },
--- },
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "matlab-language-server", "--stdio" },
  filetypes = { "matlab" },
  root_dir = function(bufnr, on_dir)
    util.root(bufnr, { ".git" }):next(function(root_dir)
      on_dir(root_dir or util.cwd())
    end)
  end,
  settings = {
    MATLAB = {
      indexWorkspace = true,
      installPath = "", -- NOTE: Set this to your MATLAB installation path.
      matlabConnectionTiming = "onStart",
      telemetry = true,
    },
  },
}
