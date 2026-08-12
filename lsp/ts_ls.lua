---@brief
---
--- https://github.com/typescript-language-server/typescript-language-server
---
--- `ts_ls`, aka `typescript-language-server`, is a Language Server Protocol implementation for TypeScript wrapping `tsserver`. Note that `ts_ls` is not `tsserver`.
---
--- `typescript-language-server` depends on `typescript`. Both packages can be installed via `npm`:
--- ```sh
--- npm install -g typescript typescript-language-server
--- ```
---
--- ### The `_typescript.rename` follow-up is not intercepted
---
--- Some ts_ls refactors (extract function / extract type) finish by asking the editor
--- to start a rename at the position they just created, through a server→client
--- `_typescript.rename` request. bemtvi does not route server-initiated requests into
--- per-config `handlers` (`btv.lsp` warns about the key at load), so the refactor
--- applies and the rename prompt does not follow — run `:LspRename` on the new name.
--- The interception is dropped rather than kept as code that cannot run.
---
--- To configure typescript language server, add a
--- [`tsconfig.json`](https://www.typescriptlang.org/docs/handbook/tsconfig-json.html) or
--- [`jsconfig.json`](https://code.visualstudio.com/docs/languages/jsconfig) to the root of your
--- project.
---
--- Here's an example that disables type checking in JavaScript files.
---
--- ```json
--- {
---   "compilerOptions": {
---     "module": "commonjs",
---     "target": "es6",
---     "checkJs": false
---   },
---   "exclude": [
---     "node_modules"
---   ]
--- }
--- ```
---
--- Use the `:LspTypescriptSourceAction` command to see "whole file" ("source") code-actions such as:
--- - organize imports
--- - remove unused code
---
--- Use the `:LspTypescriptGoToSourceDefinition` command to navigate to the source definition of a symbol (e.g., jump to the original implementation instead of type definitions).
---
--- ### Monorepo support
---
--- `ts_ls` supports monorepos by default. It will automatically find the `tsconfig.json` or `jsconfig.json` corresponding to the package you are working on.
--- This works without the need of spawning multiple instances of `ts_ls`, saving memory.
---
--- It is recommended to use the same version of TypeScript in all packages, and therefore have it available in your workspace root. The location of the TypeScript binary will be determined automatically, but only once.
---
--- Some care must be taken here to correctly infer whether a file is part of a Deno program, or a TS program that
--- expects to run in Node or Web Browsers. This supports having a Deno module using the denols LSP as a part of a
--- mostly-not-Deno monorepo. We do this by finding the nearest package manager lock file, and the nearest deno.json
--- or deno.jsonc.
---
--- Example:
---
--- ```
--- project-root
--- +-- node_modules/...
--- +-- package-lock.json
--- +-- package.json
--- +-- packages
---     +-- deno-module
---     |   +-- deno.json
---     |   +-- package.json <-- It's normal for Deno projects to have package.json files!
---     |   +-- src
---     |       +-- index.ts <-- this is a Deno file
---     +-- node-module
---         +-- package.json
---         +-- src
---             +-- index.ts <-- a non-Deno file (ie, should use ts_ls or tsgols)
--- ```
---
--- From the file being edited, we walk up to find the nearest package manager lockfile. This is PROJECT ROOT.
--- From the file being edited, find the nearest deno.json or deno.jsonc. This is DENO ROOT.
--- From the file being edited, find the nearest deno.lock. This is DENO LOCK ROOT
--- If DENO LOCK ROOT is found, and PROJECT ROOT is missing or shorter, then this is a deno file, and we abort.
--- If DENO ROOT is found, and it's longer than or equal to PROJECT ROOT, then this is a Deno file, and we abort.
--- Otherwise, attach at PROJECT ROOT, or the cwd if not found.

local util = require("bemtvi-lspconfig.util")

return {
  init_options = { hostInfo = "neovim" },
  cmd = util.node_cmd("typescript-language-server"),
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
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
    local deno_root = btv.await(util.root(bufnr, { "deno.json", "deno.jsonc" }))
    local deno_lock_root = btv.await(util.root(bufnr, { "deno.lock" }))
    local project_root = btv.await(util.root(bufnr, root_markers))
    if deno_lock_root and (not project_root or #deno_lock_root > #project_root) then
      -- deno lock is closer than package manager lock, abort
      return
    end
    if deno_root and (not project_root or #deno_root >= #project_root) then
      -- deno config is closer than or equal to package manager lock, abort
      return
    end
    -- project is standard TS, not deno
    -- We fallback to the current working directory if no project root is found
    on_dir(project_root or util.cwd())
  end),
  commands = {
    -- `editor.action.showReferences` is a CLIENT-side command: ts_ls hands over the
    -- references it already found and asks the editor to present them. The list goes
    -- to the quickfix stack (bemtvi's own list surface) and the cursor jumps to the
    -- symbol the action was about.
    ["editor.action.showReferences"] = function(command, ctx)
      local client = assert(btv.lsp.client_by_id(ctx.client_id))
      local file_uri, position, references = unpack(command.arguments)

      -- A promise: an item quotes its source line, and a reference into a file no
      -- buffer holds means reading it. Nothing blocks, so the jump below is sequenced
      -- after the list rather than racing it.
      btv.lsp
        .locations_to_items(references, { encoding = client.offset_encoding })
        :next(function(items)
          btv.qf.setqflist({}, " ", {
            title = command.title,
            items = items,
            context = { command = command, bufnr = ctx.bufnr },
          })
          btv.lsp.show_document({
            uri = file_uri,
            range = { start = position, ["end"] = position },
          }, { encoding = client.offset_encoding })
          btv.qf.open()
        end)
        :catch(function(err)
          btv.notify("ts_ls: could not build the reference list: " .. tostring(err), "error")
        end)
    end,
  },
  on_attach = function(client, bufnr)
    -- ts_ls's `source.*` actions apply to the whole file (organize imports, add all
    -- missing imports, …) and a code-action request only offers them when they are
    -- asked for by kind — an unfiltered request answers with the actions for what is
    -- under the cursor.
    --
    -- `only = { "source" }` asks for the whole family. LSP action kinds are
    -- HIERARCHICAL — `source` matches `source.organizeImports.ts` — so the one entry
    -- says what upstream says by enumerating the server's advertised kinds and
    -- prefix-matching them, without depending on that list being advertised at all.
    util.buf_command(bufnr, "LspTypescriptSourceAction", function()
      btv.lsp.code_action({ context = { only = { "source" }, diagnostics = {} } })
    end, { desc = "Choose a whole-file source action" })

    -- Go to source definition command
    util.buf_command(bufnr, "LspTypescriptGoToSourceDefinition", function()
      local params = btv.lsp.position_params({
        bufnr = bufnr,
        encoding = client.offset_encoding,
      })
      client:exec_cmd({
        command = "_typescript.goToSourceDefinition",
        title = "Go to source definition",
        arguments = { params.textDocument.uri, params.position },
      }, { bufnr = bufnr }, function(err, result)
        if err then
          btv.notify("Go to source definition failed: " .. err.message, btv.log.levels.ERROR)
          return
        end
        if not result or btv.tbl.is_empty(result) then
          btv.notify("No source definition found", btv.log.levels.INFO)
          return
        end
        btv.lsp.show_document(result[1], { encoding = client.offset_encoding })
      end)
    end, { desc = "Go to source definition" })
  end,
}
