---@brief
---
--- https://github.com/typed-ember/glint
--- https://typed-ember.gitbook.io/glint/
--- `glint-language-server` is installed when adding `@glint/core` to your project's devDependencies:
---
--- ```sh
--- npm install @glint/core --save-dev
--- yarn add -D @glint/core
---
--- This configuration uses the local installation of `glint-language-server`
--- (found in the `node_modules` directory of your project).
---
--- To use a global installation of `glint-language-server`,
--- set the `init_options.glint.useGlobal` to `true`.
---
--- btv.lsp.config('glint', {
---   init_options = {
---     glint = {
---       useGlobal = true,
---     },
---   },
--- })

local util = require("bemtvi-lspconfig.util")

return {
  cmd = btv.async(function(_dispatchers, config)
    config = config or {}
    ---@diagnostic disable-next-line: undefined-field
    local use_global = ((config.init_options or {}).glint or {}).useGlobal
    if not use_global then
      local local_cmd = btv.await(util.local_bin(config.root_dir, "glint-language-server"))
      if local_cmd then
        return { local_cmd }
      end
    end
    return { "glint-language-server" }
  end),
  init_options = {
    glint = {
      useGlobal = false,
    },
  },
  filetypes = {
    "html.handlebars",
    "handlebars",
    "typescript",
    "typescript.glimmer",
    "javascript",
    "javascript.glimmer",
  },
  root_markers = {
    ".glintrc.yml",
    ".glintrc",
    ".glintrc.json",
    ".glintrc.js",
    "glint.config.js",
    "package.json",
  },
  workspace_required = true,
}
