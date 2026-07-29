# nxvim-lspconfig

Ready-made `nx.lsp` configurations for **407 language servers** — a native port of
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) to
[nxvim](https://github.com/nxvim/nxvim).

This is a **port, not a compatibility layer.** nxvim runs no neovim plugins; upstream's
configs were treated as a behavioral spec and rewritten against nxvim's own `nx.*`
surfaces. Everything that touches the filesystem or runs a program is asynchronous,
because nxvim does no blocking I/O on the editor thread — ever.

## Install

With the built-in package manager:

```lua
nx.plugins.add({ "nxvim/nxvim-lspconfig" })
```

## Use

### The native path

`nx.lsp` reads each server's config straight off this plugin's runtimepath
(`lsp/<name>.lua`), so once it is installed there is nothing to require:

```lua
nx.lsp.enable("rust_analyzer")
nx.lsp.enable({ "lua_ls", "gopls", "pyright" })

-- Customize any of them; your override wins over the bundled config.
nx.lsp.config("rust_analyzer", {
  settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
})
```

### The convenience path

`setup()` enables a batch, applies settings shared by every server, installs the
extended keymap set, and takes per-server overrides inline:

```lua
require("nxvim-lspconfig").setup({
  servers = {
    "lua_ls", "pyright", "gopls",
    rust_analyzer = { settings = { ["rust-analyzer"] = { checkOnSave = true } } },
    eslint = false,                        -- skip one
  },
  on_attach = function(client, bufnr) end,
  inlay_hints = true,
})
```

| option | meaning |
| --- | --- |
| `servers` | `"all"` \| a name \| a list \| a map `name -> (override \| false)` |
| `capabilities` | client capabilities broadcast to every server |
| `settings` | settings merged into every server |
| `root_markers` | extra root markers for every server |
| `on_attach` | `function(client, bufnr)` run when any server attaches |
| `keymaps` | install the extended LSP keymaps (default `true`) |
| `inlay_hints` | enable inlay hints for capable servers (default `false`) |

## Commands

`:LspStart`, `:LspStop`, `:LspRestart` and `:LspLog` come from this plugin. Everything
else is **native to nxvim** and works without it — `:LspInfo`, `:LspDefinition`,
`:LspReferences`, `:LspHover`, `:LspFormat`, `:LspRename`, `:LspCodeAction`,
`:LspDiagnostics`.

| command | |
| --- | --- |
| `:LspStart [server …]` | enable and launch; with no argument, every server for this filetype |
| `:LspStop [server …]` | stop **and** disable; with no argument, everything running |
| `:LspRestart [server …]` | respawn with the config in force now |
| `:LspLog` | open nxvim's LSP log |

`:LspStop` disables as well as stopping, because stopping alone would leave the config
enabled and the next matching buffer would silently start it back up.

## Keymaps

nxvim installs the core maps itself, buffer-local, when a server attaches — `gd`, `gD`,
`gr`, `K`, `<C-k>`. This plugin adds the rest of the standard set (opt out with
`setup({ keymaps = false })`):

| key | |
| --- | --- |
| `grn` | rename |
| `gra` | code action |
| `grr` | references |
| `gri` | implementation |
| `grt` | type definition |
| `gO` | document symbols |
| `<leader>ls` | workspace symbols |
| `<leader>lf` | format buffer |
| `<leader>lh` | toggle inlay hints |

All are installed at the *overridable* rung, so your own mapping for the same key wins.

## What changed from upstream

**The `require('lspconfig').server.setup{}` framework is gone** — deleted, not aliased,
along with `lua/lspconfig/`, `plugin/lspconfig.lua`, and the neovim-internals plumbing
they depended on (`vim.lsp.config._configs`, `vim.uv.new_timer`, `vim.deprecate`,
`:checkhealth`). Use `nx.lsp.enable` / `nx.lsp.config`, or `setup()` above.

**Nothing blocks.** Upstream's helpers are built on `vim.fs.root`, `vim.fn.executable`,
`vim.uv.fs_stat` and `vim.system(…):wait()`, all of which stop the editor while they
work. Here, a config field that needs I/O returns a promise and `nx.lsp` awaits it
before spawning:

```lua
return {
  -- Prefers the project's own node_modules/.bin copy, else $PATH — resolved
  -- asynchronously, without the editor pausing.
  cmd = util.node_cmd("typescript-language-server"),
  filetypes = { "typescript", "typescriptreact" },
  root_markers = { { "package-lock.json", "yarn.lock" }, { ".git" } },
}
```

**Root markers support priority tiers.** `{ {a, b}, {".git"} }` means the first tier is
exhausted over the whole tree before `.git` is considered anywhere — so a package inside
a monorepo attaches at the monorepo root, not at its own nested `.git`.

**Unsupported config keys are reported, not dropped.** A config carrying `handlers`,
`reuse_client` or `offset_encoding` gets a warning naming the key and what happens
instead. A typo'd key is named too, because a silently-ignored `filetype` (singular)
looks exactly like a server that won't start.

## Writing a config

Configs are plain tables; see [`lua/nxvim-lspconfig/util.lua`](lua/nxvim-lspconfig/util.lua)
for the helper surface. The fields `nx.lsp` reads:

```
cmd                 argv, or a function(dispatchers, config) returning an argv
                    or a PROMISE of one
cmd_env             { NAME = "value" } layered over the editor's environment
filetypes           filetypes that activate this server
root_markers        markers to search upward for; a list of lists = priority tiers
root_dir            function(bufnr, on_dir) — or one returning a promise; never
                    calling on_dir declines the buffer
workspace_required  no root: do not start, rather than start rootless
init_options        sent at `initialize`
settings            sent at `initialize` and via didChangeConfiguration
capabilities        merged over nxvim's base client capabilities
commands            client-side handlers for this server's code-action commands
name                the client name, when it differs from the file's name
get_language_id     function(bufnr, filetype) -> the LSP languageId
before_init         function(init_params, config) — may return a promise
on_init             function(client, result)
on_attach           function(client, bufnr)
on_exit             function(code, signal, client)
```

To add a server, create `lsp/<name>.lua` returning such a table. It is picked up off
the runtimepath with no registration step.

## License

Copyright Neovim contributors and nxvim contributors. All rights reserved.

Licensed under the terms of the Apache 2.0 license — see [LICENSE.md](LICENSE.md).
