---@brief
---
--- https://projects.eclipse.org/projects/eclipse.jdt.ls
---
--- Language server for Java.
---
--- IMPORTANT: If you want all the features jdtls has to offer, [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls)
--- is highly recommended. If all you need is diagnostics, completion, imports, gotos and formatting and some code actions
--- you can keep reading here.
---
--- For manual installation you can download precompiled binaries from the
--- [official downloads site](http://download.eclipse.org/jdtls/snapshots/?d)
--- and ensure that the `PATH` variable contains the `bin` directory of the extracted archive.
---
--- ```lua
---   -- init.lua
---   btv.lsp.enable('jdtls')
--- ```
---
--- You can also pass extra custom jvm arguments with the JDTLS_JVM_ARGS environment variable as a space separated list of arguments,
--- that will be converted to multiple --jvm-arg=<param> args when passed to the jdtls script. This will allow for example tweaking
--- the jvm arguments or integration with external tools like lombok:
---
--- ```sh
--- export JDTLS_JVM_ARGS="-javaagent:$HOME/.local/share/java/lombok.jar"
--- ```
---
--- For automatic installation you can use the following unofficial installers/launchers under your own risk:
---   - [jdtls-launcher](https://github.com/eruizc-dev/jdtls-launcher) (Includes lombok support by default)
---     ```lua
---       -- init.lua
---       btv.lsp.config('jdtls', { cmd = { 'jdtls' } })
---     ```

local util = require("bemtvi-lspconfig.util")

local function get_jdtls_cache_dir()
  return util.joinpath(btv.stdpath("cache"), "jdtls")
end

local function get_jdtls_workspace_dir()
  return util.joinpath(get_jdtls_cache_dir(), "workspace")
end

local function get_jdtls_jvm_args()
  local args = {}
  for a in string.gmatch(btv.env.get("JDTLS_JVM_ARGS") or "", "%S+") do
    table.insert(args, string.format("--jvm-arg=%s", a))
  end
  return args
end

local root_markers1 = {
  -- Multi-module projects
  "mvnw", -- Maven
  "gradlew", -- Gradle
  "settings.gradle", -- Gradle
  "settings.gradle.kts", -- Gradle
  -- Use git directory as last resort for multi-module maven projects
  -- In multi-module maven projects it is not really possible to determine what is the parent directory
  -- and what is submodule directory. And jdtls does not break if the parent directory is at higher level than
  -- actual parent pom.xml so propagating all the way to root git directory is fine
  ".git",
}
local root_markers2 = {
  -- Single-module projects
  "build.xml", -- Ant
  "pom.xml", -- Maven
  "build.gradle", -- Gradle
  "build.gradle.kts", -- Gradle
}

return {
  cmd = function(_dispatchers, config)
    local data_dir = get_jdtls_workspace_dir()

    if config.root_dir then
      -- one workspace per project, named after the project directory
      data_dir = util.joinpath(data_dir, util.basename(config.root_dir))
    end

    -- `$JDTLS_JVM_ARGS` becomes one `--jvm-arg=` per entry. Upstream splices them with
    -- `unpack()`, which Lua 5.4 (bemtvi's only backend) spells `table.unpack`; appending
    -- the list is the same result without depending on which one is in scope.
    return btv.list.extend({ "jdtls", "-data", data_dir }, get_jdtls_jvm_args())
  end,
  filetypes = { "java" },
  root_markers = { root_markers1, root_markers2 },
  init_options = {},
}
