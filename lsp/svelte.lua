---@brief
---
--- https://github.com/sveltejs/language-tools/tree/master/packages/language-server
---
--- Note: assuming that [ts_ls](#ts_ls) is setup, full JavaScript/TypeScript support (find references, rename, etc of symbols in Svelte files when working in JS/TS files) requires per-project installation and configuration of [typescript-svelte-plugin](https://github.com/sveltejs/language-tools/tree/master/packages/typescript-plugin#usage).
---
--- `svelte-language-server` can be installed via `npm`:
--- ```sh
--- npm install [-g] svelte-language-server
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = util.node_cmd("svelteserver"),
  filetypes = { "svelte" },
  settings = {
    typescript = {
      inlayHints = {
        parameterNames = {
          enabled = "literals",
          suppressWhenArgumentMatchesName = true,
        },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
    },
  },
  root_dir = util.root_dir(function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    -- Svelte LSP only supports file:// schema. https://github.com/sveltejs/language-tools/issues/2777
    if btv.await(util.exists(fname)) then
      local root_markers =
        { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock", "deno.lock" }
      root_markers = { root_markers, { ".git" } }
      -- We fallback to the current working directory if no project root is found
      local project_root = btv.await(util.root(bufnr, root_markers)) or util.cwd()
      on_dir(project_root)
    end
  end),
  on_attach = function(client, bufnr)
    -- Workaround to trigger reloading JS/TS files
    -- See https://github.com/sveltejs/language-tools/issues/2008
    btv.autocmd.create("BufWritePost", {
      pattern = { "*.js", "*.ts" },
      group = btv.augroup.create("lspconfig.svelte", {}),
      callback = function(ctx)
        -- internal API to sync changes that have not yet been saved to the file system
        ---@diagnostic disable-next-line: param-type-mismatch
        client:notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
      end,
    })
    util.buf_command(bufnr, "LspMigrateToSvelte5", function()
      client:exec_cmd({
        title = "Migrate Component to Svelte 5 Syntax",
        command = "migrate_to_svelte_5",
        arguments = { util.uri_from_buf(bufnr) },
      })
    end, { desc = "Migrate Component to Svelte 5 Syntax" })
  end,
}
