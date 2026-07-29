--- @brief
---
--- https://github.com/oxc-project/oxc
--- https://oxc.rs/docs/guide/usage/formatter.html
---
--- `oxfmt` is a Prettier-compatible code formatter that supports multiple languages
--- including JavaScript, TypeScript, JSON, YAML, HTML, CSS, Markdown, and more.
--- It can be installed via `npm`:
---
--- ```sh
--- npm i -g oxfmt
--- ```
---
--- or used as a part of Vite+ through `fmt` field in `vite.config.ts`: https://github.com/oxc-project/oxc/pull/20197

local util = require("nxvim-lspconfig.util")

return {
  cmd = util.node_cmd("oxfmt", { "--lsp" }),
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "toml",
    "json",
    "jsonc",
    "json5",
    "yaml",
    "html",
    "vue",
    "handlebars",
    "css",
    "scss",
    "less",
    "graphql",
    "markdown",
  },
  workspace_required = true,
  root_dir = util.root_dir(function(bufnr, on_dir)
    local fname = util.bufname(bufnr)

    -- Oxfmt resolves configuration by walking upward and using the nearest config file
    -- to the file being processed. We therefore compute the root directory by locating
    -- the closest `.oxfmtrc.json` / `.oxfmtrc.jsonc` / `oxfmt.config.ts` (or `package.json` fallback) above the buffer.
    local root_markers = nx.await(
      util.insert_package_json(
        { ".oxfmtrc.json", ".oxfmtrc.jsonc", "oxfmt.config.ts" },
        { "oxfmt", "vite%-plus" },
        fname
      )
    )
    -- find vite plus config with fmt field
    root_markers = nx.await(
      util.root_markers_with_field(
        root_markers,
        { "vite.config.ts" },
        { "vite%-plus", "fmt:" },
        fname,
        "all"
      )
    )
    local found = nx.await(util.find_upward(fname, root_markers))
    if found then
      on_dir(util.dirname(found))
    end
  end),
}
