---@brief
---
--- A kotlin language server which was developed for internal usage and
--- released afterwards. Maintaining is not done by the original author,
--- but by fwcd.
---
--- It is built via gradle and developed on github.
--- Source and additional description:
--- https://github.com/fwcd/kotlin-language-server
---
--- This server requires vim to be aware of the kotlin-filetype.
--- You could refer for this capability to:
--- https://github.com/udalov/kotlin-vim (recommended)
--- Note that there is no LICENSE specified yet.
---
--- For faster startup, you can setup caching by specifying a storagePath
--- in the init_options. The default is your home directory.

--- The presence of one of these files indicates a project root directory
--
--  These are configuration files for the various build systems supported by
--  Kotlin. I am not sure whether the language server supports Ant projects,
--  but I'm keeping it here as well since Ant does support Kotlin.
local root_files = {
  "settings.gradle", -- Gradle (multi-project)
  "settings.gradle.kts", -- Gradle (multi-project)
  "build.xml", -- Ant
  "pom.xml", -- Maven
  "build.gradle", -- Gradle
  "build.gradle.kts", -- Gradle
}

return {
  filetypes = { "kotlin" },
  root_markers = root_files,
  cmd = { "kotlin-language-server" },
  -- Enables caching, using the project root to store the cache data. Upstream computes
  -- this at *load* time from whatever buffer happened to be current, which freezes one
  -- project's path into every session; `before_init` runs once per server with the root
  -- that server actually resolved, which is the value it wanted. With no root the key
  -- is left unset and the server falls back to the home directory itself.
  before_init = function(_init_params, config)
    config.init_options = btv.tbl.deep_extend("force", config.init_options or {}, {
      storagePath = config.root_dir,
    })
  end,
}
