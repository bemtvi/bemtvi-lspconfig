---@brief
---
--- https://github.com/denoland/deno
---
--- Deno's built-in language server
---
--- To appropriately highlight codefences returned from denols, you will need to augment nx.g.markdown_fenced languages
---  in your init.lua. Example:
---
--- ```lua
--- nx.g.markdown_fenced_languages = {
---   "ts=typescript"
--- }
--- ```
---
--- Some care must be taken here to correctly infer whether a file is part of a Deno program, or a TS program that
--- expects to run in Node or Web Browsers. This supports having a Deno module that is a part of a mostly-not-Deno
--- monorepo. We do this by finding the nearest package manager lock file, and the nearest deno.json or deno.jsonc.
--- Note that this means that without a deno.json, deno.jsonc, or deno.lock file, this LSP client will not attach.
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
---             +-- index.ts <-- a non-Deno file (ie, should use ts_ls or tsgo)
--- ```
---
--- ### `deno:` virtual documents are not opened
---
--- A goto into Deno's own standard library resolves to a `deno:` URI — a document that
--- exists only inside the server, fetched with `deno/virtualTextDocument`. Upstream
--- intercepts the goto reply and fills a scratch buffer with the fetched text.
---
--- nxvim does not route server *replies* through per-config `handlers` (`nx.lsp` warns
--- about the key at load), and it has no Lua buffer-mutation API to fill such a buffer
--- with, so that interception is gone rather than kept as code that cannot run. A goto
--- landing on a `deno:` URI reports that it has no path instead of opening a blank
--- buffer named after one. Everything else — diagnostics, completion, hover, the
--- in-project gotos — is unaffected.
---
--- From the file being edited, we walk up to find the nearest package manager lockfile. This is PROJECT ROOT.
--- From the file being edited, find the nearest deno.json or deno.jsonc. This is DENO ROOT.
--- From the file being edited, find the nearest deno.lock. This is DENO LOCK ROOT
--- If DENO LOCK ROOT is found, and PROJECT ROOT is missing or shorter, then this is a deno file, and we attach.
--- If DENO ROOT is found, and it's longer than or equal to PROJECT ROOT, then this is a Deno file, and we attach.
--- Otherwise, we abort, because this is a non-Deno TS file.

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "deno", "lsp" },
  cmd_env = { NO_COLOR = true },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  root_dir = util.root_dir(function(bufnr, on_dir)
    -- The project root is where the LSP can be started from
    local root_markers = { "deno.lock", "deno.json", "deno.jsonc" }
    -- Give the root markers equal priority by wrapping them in a table
    root_markers = { root_markers, { ".git" } }
    -- only include deno projects
    local deno_root = nx.await(util.root(bufnr, { "deno.json", "deno.jsonc" }))
    local deno_lock_root = nx.await(util.root(bufnr, { "deno.lock" }))
    local project_root = nx.await(util.root(bufnr, root_markers))
    if
      (deno_lock_root and (not project_root or #deno_lock_root > #project_root))
      or (deno_root and (not project_root or #deno_root >= #project_root))
    then
      -- deno config is closer than or equal to package manager lock,
      -- or deno lock is closer than package manager lock. Attach at the project root,
      -- or deno lock or deno config path. At least one of these is always set at this point.
      on_dir(project_root or deno_lock_root or deno_root)
    end
  end),
  settings = {
    deno = {
      enable = true,
      suggest = {
        imports = {
          hosts = {
            ["https://deno.land"] = true,
          },
        },
      },
    },
  },
  on_attach = function(client, bufnr)
    util.buf_command(bufnr, "LspDenolsCache", function()
      client:exec_cmd({
        title = "DenolsCache",
        command = "deno.cache",
        arguments = { {}, util.uri_from_buf(bufnr) },
      }, { bufnr = bufnr }, function(err, _, ctx)
        if err then
          local uri = ctx.params.arguments[2]
          nx.notify("cache command failed for" .. util.uri_to_path(uri), nx.log.levels.ERROR)
        end
      end)
    end, {
      desc = "Cache a module and all of its dependencies.",
    })
  end,
}
