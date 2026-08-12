---@brief
---
--- https://github.com/angular/angular/tree/main/vscode-ng-language-service
--- `angular-language-server` can be installed via npm `npm install -g @angular/language-server`.
---
--- ```lua
--- local project_library_path = "/path/to/project/lib"
--- local cmd = {"ngserver", "--stdio", "--tsProbeLocations", project_library_path , "--ngProbeLocations", project_library_path}
---
--- btv.lsp.config('angularls', {
---   cmd = cmd,
--- })
--- ```

-- Angular requires a node_modules directory to probe for @angular/language-service and typescript
-- in order to use your projects configured versions.
local util = require("bemtvi-lspconfig.util")

--- Recursively solve for the original ngserver path on Windows
-- For a given ngserver path:
--   - If it is not a CMD wrapper, return the path;
--   - Or else, extract the path from the CMD wrapper.
--
-- @param cmd_path (string) path for the ngserver executable or its CMD wrapper.
-- @return (string) the original executable path for ngserver
-- @usage
-- -- Base case: cmd_path already points to ngserver (expected behavior on Linux)
-- resolve_cmd_shim('/home/user/project/node_modules/@angular/language-server/bin/ngserver')
-- => '/home/user/project/node_modules/@angular/language-server/bin/ngserver'
--
-- -- Recursive case: cmd_path points to a CMD wrapper (Windows)
-- resolve_cmd_shim('C:/Users/user/project/node_modules/.bin/ngserver.cmd')
-- => 'C:/Users/user/project/node_modules/@angular/language-server/bin/ngserver'
local resolve_cmd_shim
resolve_cmd_shim = btv.async(function(cmd_path)
  -- Upstream writes this pattern `%ngserver.cmd$`, where `%n` is an escape for a plain
  -- `n` and the `.` stays a wildcard — it happens to work, but only by accident.
  if not cmd_path:lower():match("ngserver%.cmd$") then
    return cmd_path
  end

  local content = btv.await(btv.fs.read_text(cmd_path):catch(function()
    return nil
  end))
  if type(content) ~= "string" then
    return cmd_path
  end

  local target = content:match('%s%"%%dp0%%\\([^\r\n]-ngserver[^\r\n]-)%"')
  if not target then
    return cmd_path
  end

  return btv.await(resolve_cmd_shim(util.normalize(util.joinpath(util.dirname(cmd_path), target))))
end)

local collect_node_modules = btv.async(function(root_dir)
  local results = {}

  local project_node = util.joinpath(root_dir, "node_modules")
  if btv.await(util.exists(project_node)) then
    table.insert(results, project_node)
  end

  local ngserver_exe = btv.await(util.which("ngserver"))
  if ngserver_exe then
    local realpath = btv.await(btv.fs.realpath(ngserver_exe):catch(function()
      return ngserver_exe
    end))
    realpath = btv.await(resolve_cmd_shim(realpath))
    local candidate = util.normalize(util.joinpath(util.dirname(realpath), "../../.."))
    if btv.await(util.exists(candidate)) then
      table.insert(results, candidate)
    end
  end

  return results
end)

local get_angular_core_version = btv.async(function(root_dir)
  local json = btv.await(util.read_json(util.joinpath(root_dir, "package.json")))
  if type(json) ~= "table" then
    return ""
  end

  local version = (json.dependencies or {})["@angular/core"]
    or (json.devDependencies or {})["@angular/core"]
    or ""
  return version:match("%d+%.%d+%.%d+") or ""
end)

return {
  cmd = btv.async(function(_dispatchers, config)
    local root_dir = (config and config.root_dir) or util.cwd()
    local node_paths = btv.await(collect_node_modules(root_dir))

    local ng_paths = {}
    for i, p in ipairs(node_paths) do
      ng_paths[i] = util.joinpath(p, "@angular/language-server/node_modules")
    end

    return {
      "ngserver",
      "--stdio",
      "--tsProbeLocations",
      table.concat(node_paths, ","),
      "--ngProbeLocations",
      table.concat(ng_paths, ","),
      "--angularCoreVersion",
      btv.await(get_angular_core_version(root_dir)),
    }
  end),

  filetypes = { "typescript", "html", "typescriptreact", "htmlangular" },
  root_markers = { "angular.json", "nx.json" },
}
