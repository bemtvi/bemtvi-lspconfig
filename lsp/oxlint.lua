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
local util = require("nxvim-lspconfig.util")

local function oxlint_conf_mentions_typescript(root_dir)
  local fn = util.joinpath(root_dir, ".oxlintrc.json")
  for line in io.lines(fn) do
    if line:find("typescript") then
      return true
    end
  end
  return false
end

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
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)

    local root_markers = util.insert_package_json(
      { ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts" },
      { "oxlint", "vite%-plus" },
      fname
    )
    -- find vite plus config with lint field
    root_markers = util.root_markers_with_field(
      root_markers,
      { "vite.config.ts" },
      { "vite%-plus", "lint:" },
      fname,
      "all"
    )
    on_dir(util.dirname(vim.fs.find(root_markers, { path = fname, upward = true })[1]))
  end,
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
  before_init = function(init_params, config)
    local settings = config.settings or {}
    local has_tsgolint = vim.fn.executable("tsgolint") == 1
    if not has_tsgolint and (config or {}).root_dir then
      local local_cmd = util.joinpath(config.root_dir, "node_modules/.bin", "tsgolint")
      has_tsgolint = vim.fn.executable(local_cmd) == 1
    end
    if settings.typeAware == nil and has_tsgolint then
      local ok, res = pcall(oxlint_conf_mentions_typescript, config.root_dir)
      if ok and res then
        settings = nx.tbl.extend("force", settings, { typeAware = true })
      end
    end
    local init_options = config.init_options or {}
    init_options.settings =
      nx.tbl.extend("force", init_options.settings or {} --[[@as table]], settings)

    init_params.initializationOptions = init_options
  end,
}
