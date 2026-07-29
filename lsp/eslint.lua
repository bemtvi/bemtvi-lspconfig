--- @brief
---
--- https://github.com/hrsh7th/vscode-langservers-extracted
---
--- `vscode-eslint-language-server` is a linting engine for JavaScript / Typescript.
--- It can be installed via `npm`:
---
--- ```sh
--- npm i -g vscode-langservers-extracted
--- ```
---
--- The default `on_attach` config provides the `LspEslintFixAll` command that can be used to format a document on save:
--- ```lua
--- local base_on_attach = nx.lsp.get_config("eslint").on_attach
--- nx.lsp.config("eslint", {
---   on_attach = function(client, bufnr)
---     if not base_on_attach then return end
---
---     base_on_attach(client, bufnr)
---     nx.autocmd.create("BufWritePre", {
---       buffer = bufnr,
---       command = "LspEslintFixAll",
---     })
---   end,
--- })
--- ```
---
--- See [vscode-eslint](https://github.com/microsoft/vscode-eslint/blob/55871979d7af184bf09af491b6ea35ebd56822cf/server/src/eslintServer.ts#L216-L229) for configuration options.
---
--- Messages handled in lspconfig: `eslint/openDoc`, `eslint/confirmESLintExecution`, `eslint/probeFailed`, `eslint/noLibrary`
---
--- Additional messages you can handle: `eslint/noConfig`
---
--- ### Monorepo support
---
--- `vscode-eslint-language-server` supports monorepos by default. It will automatically find the config file corresponding to the package you are working on. You can use different configs in different packages.
--- This works without the need of spawning multiple instances of `vscode-eslint-language-server`.
--- You can use a different version of ESLint in each package, but it is recommended to use the same version of ESLint in all packages. The location of the ESLint binary will be determined automatically.
---
--- /!\ When using flat config files, you need to use them across all your packages in your monorepo, as it's a global setting for the server.
---
--- ### Flat config in ESLint versions prior to 10.0
---
--- If you're using a ESLint version that supports both flat config and eslintrc (>= 8.21, < 10.0) and want to change
--- the [default behavior](https://eslint.org/blog/2023/10/flat-config-rollout-plans/), you'll need to set
--- `experimental.useFlatConfig` accordingly:
--- ```lua
--- nx.lsp.config("eslint", {
---   settings = {
---     experimental = {
---       -- If you want to use flat config on >= 8.21, < 9.0
---       useFlatConfig = true,
---       -- Or if you want to use eslintrc on 9.*
---       -- useFlatConfig = false,
---     }
---   }
--- })
--- ```

local util = require("nxvim-lspconfig.util")

local eslint_config_files = {
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.yaml",
  ".eslintrc.yml",
  ".eslintrc.json",
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
}

return {
  cmd = util.node_cmd("vscode-eslint-language-server"),
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "vue",
    "svelte",
    "astro",
    "htmlangular",
  },
  workspace_required = true,
  on_attach = function(_client, bufnr)
    -- `:LspEslintFixAll` — fix everything eslint can fix in this buffer.
    --
    -- Upstream drives this through eslint's private `eslint.applyAllFixes` command,
    -- carrying the document's version by hand and issuing it with a BLOCKING
    -- `request_sync`. Both are neovim shapes: nxvim does no blocking I/O, and it has
    -- no reason to hand-carry a version the engine already tracks.
    --
    -- The same operation is standard protocol: eslint advertises `source.fixAll.eslint`
    -- as a code-action kind, and `apply` runs a lone match without a chooser. Same
    -- result, over the path nxvim already implements — and it stays correct if the
    -- server ever renames its private command.
    util.buf_command(bufnr, "LspEslintFixAll", function()
      nx.lsp.code_action({ context = { only = { "source.fixAll.eslint" } }, apply = true })
    end, { desc = "Apply every eslint autofix in this buffer" })
  end,
  root_dir = util.root_dir(function(bufnr, on_dir)
    -- The project root is where the LSP can be started from
    -- As stated in the documentation above, this LSP supports monorepos and simple projects.
    -- We select then from the project root, which is identified by the presence of a package
    -- manager lock file.
    local root_markers =
      { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
    -- Give the root markers equal priority by wrapping them in a table
    root_markers = { root_markers, { ".git" } }

    -- exclude deno
    if nx.await(util.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" })) then
      return
    end

    -- We fallback to the current working directory if no project root is found
    local project_root = nx.await(util.root(bufnr, root_markers)) or util.cwd()

    -- We know that the buffer is using ESLint if it has a config file
    -- in its directory tree.
    --
    -- Eslint used to support package.json files as config files, but it doesn't anymore.
    -- We keep this for backward compatibility.
    local filename = util.bufname(bufnr)
    local eslint_config_files_with_package_json =
      nx.await(util.insert_package_json(eslint_config_files, "eslintConfig", filename))
    local is_buffer_using_eslint =
      nx.await(util.find_upward(filename, eslint_config_files_with_package_json, {
        stop = util.dirname(project_root),
      }))
    if not is_buffer_using_eslint then
      return
    end

    on_dir(project_root)
  end),
  -- Refer to https://github.com/Microsoft/vscode-eslint#settings-options for documentation.
  settings = {
    validate = "on",
    ---@diagnostic disable-next-line: assign-type-mismatch
    packageManager = nil,
    useESLintClass = false,
    experimental = {},
    codeActionOnSave = {
      enable = false,
      mode = "all",
    },
    format = true,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = {
      shortenToSingleLine = false,
    },
    -- nodePath configures the directory in which the eslint server should start its node_modules resolution.
    -- This path is relative to the workspace folder (root dir) of the server instance.
    nodePath = "",
    -- use the workspace folder location or the file location (if no workspace folder is open) as the working directory
    workingDirectory = { mode = "auto" },
    codeAction = {
      disableRuleComment = {
        enable = true,
        location = "separateLine",
      },
      showDocumentation = {
        enable = true,
      },
    },
  },
  -- Async because the Yarn PnP probe below is two filesystem lookups, which upstream
  -- does with a blocking `vim.uv.fs_stat`. `nx.lsp` awaits a `before_init` that
  -- returns a promise before it spawns, so the decision still lands before the server
  -- sees its `initialize`.
  before_init = nx.async(function(_, config)
    -- The "workspaceFolder" is a VSCode concept. It limits how far the
    -- server will traverse the file system when locating the ESLint config
    -- file (e.g., .eslintrc).
    local root_dir = config.root_dir

    if root_dir then
      config.settings = config.settings or {}
      config.settings.workspaceFolder = {
        uri = util.uri_from_path(root_dir),
        name = util.basename(root_dir),
      }

      -- Support Yarn2 (PnP) projects
      local pnp_cjs = nx.await(util.exists(util.joinpath(root_dir, ".pnp.cjs")))
      local pnp_js = nx.await(util.exists(util.joinpath(root_dir, ".pnp.js")))
      if type(config.cmd) == "table" and (pnp_cjs or pnp_js) then
        config.cmd = nx.list.extend({ "yarn", "exec" }, config.cmd --[[@as table]])
      end
    end
  end),
  handlers = {
    ["eslint/openDoc"] = function(_, result)
      if result then
        nx.ui.open(result.url)
      end
      return {}
    end,
    ["eslint/confirmESLintExecution"] = function(_, result)
      if not result then
        return
      end
      return 4 -- approved
    end,
    ["eslint/probeFailed"] = function()
      nx.notify("[lspconfig] ESLint probe failed.", nx.log.levels.WARN)
      return {}
    end,
    ["eslint/noLibrary"] = function()
      nx.notify("[lspconfig] Unable to find ESLint library.", nx.log.levels.WARN)
      return {}
    end,
  },
}
