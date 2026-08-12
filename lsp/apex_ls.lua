--- @brief
---
--- https://github.com/forcedotcom/salesforcedx-vscode
---
--- Language server for Apex.
---
--- For manual installation, download the JAR file from the [VSCode
--- extension](https://github.com/forcedotcom/salesforcedx-vscode/tree/develop/packages/salesforcedx-vscode-apex) and adjust the `apex_jar_path` appropriately.
---
--- ```lua
--- btv.lsp.config('apex_ls', {
---   apex_jar_path = '/path/to/apex-jorje-lsp.jar',
---   apex_enable_semantic_errors = false, -- Whether to allow Apex Language Server to surface semantic errors
---   apex_enable_completion_statistics = false, -- Whether to allow Apex Language Server to collect telemetry on code completion usage
--- }
---```
---
--- Example configuration with the jar unpacked under bemtvi's data dir:
---
---```lua
--- btv.lsp.config('apex_ls', {
---   apex_jar_path = btv.stdpath('data') .. '/apex-language-server/apex-jorje-lsp.jar',
--- }
---```
---
--- For a complete experience, you may need to ensure the treesitter parsers for 'apex' are installed (:TSInstall apex) as well as configure the filetype for apex (*.cls) files:
---
--- ```lua
--- btv.autocmd.create({ 'BufReadPost', 'BufNewFile' }, {
---   pattern = '*.cls',
---   callback = function()
---     btv.cmd('setfiletype apex')
---   end,
--- })
--- ```

return {
  cmd = function(_dispatchers, config)
    ---@diagnostic disable: undefined-field
    local local_cmd = {
      btv.env.get("JAVA_HOME") and (btv.env.get("JAVA_HOME") .. "/bin/java") or "java",
      "-cp",
      config.apex_jar_path,
      "-Ddebug.internal.errors=true",
      "-Ddebug.semantic.errors=" .. tostring(config.apex_enable_semantic_errors or false),
      "-Ddebug.completion.statistics="
        .. tostring(config.apex_enable_completion_statistics or false),
      "-Dlwc.typegeneration.disabled=true",
    }
    if config.apex_jvm_max_heap then
      table.insert(local_cmd, "-Xmx" .. config.apex_jvm_max_heap)
    end
    ---@diagnostic enable: undefined-field
    table.insert(local_cmd, "apex.jorje.lsp.ApexLanguageServerLauncher")

    return local_cmd
  end,
  filetypes = { "apex", "apexcode" },
  root_markers = {
    "sfdx-project.json",
  },
}
