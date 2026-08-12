--- @brief
---
--- https://github.com/oxc-project/oxc
--- https://oxc.rs/docs/guide/usage/linter.html
---
--- `oxlint` is a linter for JavaScript / TypeScript supporting over 500 rules from ESLint and its popular plugins.
--- It also supports linting framework files (Vue, Svelte, Astro) by analyzing their <script> blocks.
--- It can be installed via `npm`:
---
--- ```sh
--- npm i -g oxlint
--- ```
---
--- or used as a part of Vite+ through `lint` field in vite.config.ts: https://github.com/oxc-project/oxc/pull/20214
---
--- Type-aware linting will automatically be enabled if `tsgolint` exists in your
--- path and your `.oxlintrc.json` contains the string "typescript".
---
--- The default `on_attach` function provides an `:LspOxlintFixAll` command which
--- can be used to fix all fixable diagnostics. See the `eslint` config entry for
--- an example of how to use this to automatically fix all errors on write.
local util = require("bemtvi-lspconfig.util")

local oxlint_conf_mentions_typescript = btv.async(function(root_dir)
  if not root_dir then
    return false
  end
  local text = btv.await(btv.fs.read_text(util.joinpath(root_dir, ".oxlintrc.json")):catch(function()
    return nil
  end))
  return type(text) == "string" and text:find("typescript") ~= nil
end)

return {
  cmd = util.node_cmd("oxlint", { "--lsp" }),
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "vue",
    "svelte",
    "astro",
  },
  root_dir = util.root_dir(function(bufnr, on_dir)
    local fname = util.bufname(bufnr)

    local root_markers = btv.await(
      util.insert_package_json(
        { ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts" },
        { "oxlint", "vite%-plus" },
        fname
      )
    )
    -- find vite plus config with lint field
    root_markers = btv.await(
      util.root_markers_with_field(
        root_markers,
        { "vite.config.ts" },
        { "vite%-plus", "lint:" },
        fname,
        "all"
      )
    )
    local found = btv.await(util.find_upward(fname, root_markers))
    if found then
      on_dir(util.dirname(found))
    end
  end),
  workspace_required = true,
  on_attach = function(client, bufnr)
    util.buf_command(bufnr, "LspOxlintFixAll", function()
      client:exec_cmd({
        title = "Apply Oxlint automatic fixes",
        command = "oxc.fixAll",
        arguments = { { uri = util.uri_from_buf(bufnr) } },
      })
    end, {
      desc = "Apply Oxlint automatic fixes",
    })
  end,
  settings = {
    -- run = 'onType',
    -- configPath = nil,
    -- tsConfigPath = nil,
    -- unusedDisableDirectives = 'allow',
    -- typeAware = false,
    -- disableNestedConfig = false,
    -- fixKind = 'safe_fix',
  },
  before_init = btv.async(function(init_params, config)
    local settings = config.settings or {}
    local has_tsgolint = btv.await(util.which("tsgolint"))
      or btv.await(util.local_bin((config or {}).root_dir, "tsgolint"))
    if settings.typeAware == nil and has_tsgolint then
      if btv.await(oxlint_conf_mentions_typescript(config.root_dir)) then
        settings = btv.tbl.extend("force", settings, { typeAware = true })
      end
    end
    local init_options = config.init_options or {}
    init_options.settings =
      btv.tbl.extend("force", init_options.settings or {} --[[@as table]], settings)

    init_params.initializationOptions = init_options
  end),
}
