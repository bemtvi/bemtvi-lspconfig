---@brief
---
--- https://robotcode.io
---
--- RobotCode - Language Server Protocol implementation for Robot Framework.

local util = require("nxvim-lspconfig.util")

local venv = nx.env.get("VIRTUAL_ENV")

return {
  cmd = { "robotcode", "language-server" },
  filetypes = { "robot", "resource" },
  root_markers = { "robot.toml", "pyproject.toml", "Pipfile", ".git" },
  -- The active virtualenv's site-packages has to be on `$PYTHONPATH` for robotcode to
  -- resolve the project's own libraries. Which pythonN.M directory that is isn't known
  -- until it is looked at, so `before_init` reads the venv rather than glob-expanding
  -- a path at load time (nxvim has no synchronous glob — all fs is async).
  before_init = venv and nx.async(function(_init_params, config)
    local libdir = util.joinpath(venv, "lib")
    local entries = nx.await(nx.fs.readdir(libdir):catch(function()
      return {}
    end))
    local paths = {}
    for _, e in ipairs(entries) do
      if e.name:match("^python%d+%.%d+$") then
        paths[#paths + 1] = util.joinpath(libdir, e.name, "site-packages")
      end
    end
    if #paths > 0 then
      config.cmd_env =
        nx.tbl.extend("force", config.cmd_env or {}, { PYTHONPATH = table.concat(paths, ":") })
    end
  end) or nil,
  get_language_id = function(_, _)
    return "robotframework"
  end,
}
