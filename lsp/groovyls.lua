---@brief
---
--- https://github.com/prominic/groovy-language-server.git
---
--- Requirements:
---  - Linux/macOS (for now)
---  - Java 11+
---
--- `groovyls` can be installed by following the instructions [here](https://github.com/prominic/groovy-language-server.git#build).
---
--- If you have installed groovy language server, you can set the `cmd` custom path as follow:
---
--- ```lua
--- nx.lsp.config("groovyls", {
---     -- Unix
---     cmd = { "java", "-jar", "path/to/groovyls/groovy-language-server-all.jar" },
---     ...
--- })
--- ```

return {
  -- When installed via mason
  cmd = { "groovy-language-server" },
  -- If installed/built locally, please provide the correct filepath to Java.
  -- cmd = {
  --   'java',
  --   '-jar',
  --   'groovy-language-server-all.jar',
  -- },
  filetypes = { "groovy" },
  root_markers = { "Jenkinsfile", ".git" },
}
