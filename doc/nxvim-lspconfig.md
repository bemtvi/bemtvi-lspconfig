<!-- DO NOT EDIT doc/nxvim-lspconfig.txt BY HAND. It is generated from this file by
panvimdoc — run `scripts/gen-vimdoc.sh` after editing. -->

Ready-made `nx.lsp` configurations for **407 language servers** — a native port of
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) to
[nxvim](https://github.com/davidrios/nxvim).

This is a **port, not a compatibility layer.** nxvim runs no neovim plugins; upstream's
configs were treated as a behavioral spec and rewritten against nxvim's own `nx.*`
surfaces. Everything that touches the filesystem or runs a program is asynchronous,
because nxvim does no blocking I/O on the editor thread — ever.

This plugin only *configures* servers; it does not install them. Install the language
server binaries yourself. A server whose binary isn't there fails loud — nxvim never
pretends a server that isn't running is working.

<!-- Passed through verbatim so `:help nxvim-lspconfig` lands on this page
     (panvimdoc derives per-section tags but no bare project tag). -->

```vimdoc
                                                              *nxvim-lspconfig*
```

# Install

With the built-in package manager:

```lua
nx.plugins({
  {
    "nxvim/nxvim-lspconfig",
    config = function()
      nx.lsp.enable({ "lua_ls", "gopls", "rust_analyzer" })
    end,
  },
})
```

Run `:PluginSync` to clone it. Open a file of a matching type and, if the server is
installed, it attaches.

# Enabling servers

## The native path

`nx.lsp` reads each server's config straight off this plugin's runtimepath
(`lsp/<name>.lua`), so once the plugin is installed there is nothing to require and no
registration step:

```lua
nx.lsp.enable("rust_analyzer")
nx.lsp.enable({ "lua_ls", "gopls", "pyright" })
```

Customize any of them with `nx.lsp.config` — your override is deep-merged over the
bundled config and wins:

```lua
nx.lsp.config("rust_analyzer", {
  settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
})

-- The "*" layer applies to every server.
nx.lsp.config("*", { capabilities = my_capabilities })
```

Order does not matter: `nx.lsp.enable` may be called before or after `nx.lsp.config`,
and a late `enable` serves buffers that are already open.

## The setup() path

`setup()` enables a batch, applies settings shared by every server, installs the
extended keymap set, and takes per-server overrides inline:

```lua
require("nxvim-lspconfig").setup({
  servers = {
    "lua_ls", "pyright", "gopls",
    rust_analyzer = { settings = { ["rust-analyzer"] = { … } } },
    eslint = false,                        -- skip one
  },
  on_attach = function(client, bufnr) end,
  inlay_hints = true,
})
```

It is additive and idempotent — call it as often as you like — and it is a convenience
over the native path, not a replacement for it. An unknown server name raises rather
than enabling nothing.

# setup() options

```
servers       "all" | a name | a list | a map name -> (override | false)
capabilities  client capabilities broadcast to every server
settings      settings merged into every server
root_markers  extra root markers for every server
on_attach     function(client, bufnr) run when any server attaches
keymaps       install the extended LSP keymaps (default true)
inlay_hints   enable inlay hints for capable servers (default false)
```

`capabilities`, `settings`, `root_markers` and `on_attach` are applied through
`nx.lsp.config("*", …)`, so they compose with anything else that writes that layer.

The `servers` value accepts five shapes:

```lua
servers = "all"                          -- every bundled server
servers = "gopls"                        -- one name
servers = { "lua_ls", "pyright" }        -- a list of names
servers = { lua_ls = { settings = {} } } -- a map of name -> override
servers = { "gopls", eslint = false }    -- mixed; false skips one
```

# API

```
require("nxvim-lspconfig")
  .setup(opts)              the one-call entry point (above)
  .enable(servers)          register + enable a batch, no global layer
  .available()              a sorted list of every bundled server name
  .is_available(name)       is there a bundled config by that name?
  .for_filetype(ft)         the bundled servers that declare filetype `ft`
  .util                     the helper surface configs are written against
```

`for_filetype` reads each config **as resolved** — bundled preset plus your override —
not the preset file alone, so a filetype you added with `nx.lsp.config` counts.

# Commands

`:LspStart`, `:LspStop`, `:LspRestart` and `:LspLog` come from this plugin. Everything
else is **native to nxvim** and works without it — `:LspInfo`, `:LspDefinition`,
`:LspReferences`, `:LspHover`, `:LspFormat`, `:LspRename`, `:LspCodeAction`,
`:LspDiagnostics`.

```
:LspStart [server …]    enable and launch; with no argument, every server
                        whose filetypes include this buffer's
:LspStop [server …]     stop AND disable; with none, all that run
:LspRestart [server …]  respawn with the config in force now
:LspLog                 open nxvim's LSP log in a new tab
```

`:LspStop` disables as well as stopping, because stopping alone would leave the config
enabled and the next matching buffer would silently start it back up. `:LspStart` turns
it on again.

`:LspRestart` exists to pick up a `nx.lsp.config` change made since the server started
— a running server cannot be reconfigured in place, because most read their
configuration only at `initialize`.

`:LspLog` resolves the same path the engine writes to: `$NXVIM_LSP_LOG_FILE`, else
`$XDG_STATE_HOME/nxvim/lsp.log`, else `~/.local/state/nxvim/lsp.log`. Logging is off
below WARN by default — set `$NXVIM_LSP_LOG_LEVEL=debug` to get something worth
reading.

Some servers add their own buffer-local commands when they attach
(`:LspClangdSwitchSourceHeader`, `:LspTexlabBuild`, `:LspEslintFixAll`, …). They exist
only on the buffers that server serves; `:Lsp` in the command line lists what is
available where you are.

# Keymaps

nxvim installs the core maps itself, buffer-local, when a server attaches — `gd`, `gD`,
`gr`, `K`, `<C-k>`. This plugin adds the rest of the standard set (opt out with
`setup({ keymaps = false })`):

```
grn           rename
gra           code action
grr           references
gri           implementation
grt           type definition
gO            document symbols
<leader>ls    workspace symbols
<leader>lf    format buffer
<leader>lh    toggle inlay hints
```

All are installed at the *overridable* rung, so your own mapping for the same key wins
whether you set it before or after.

# Config fields

A config is a plain table. These are the fields `nx.lsp` reads:

```
cmd                 argv, or a function(dispatchers, config) returning
                    an argv or a PROMISE of one
cmd_env             { NAME = "value" } layered over the editor's env
filetypes           filetypes that activate this server
root_markers        markers to search upward for; a list of lists is
                    priority tiers
root_dir            function(bufnr, on_dir), or one returning a promise;
                    never calling on_dir declines the buffer
workspace_required  no root: do not start, rather than start rootless
                    (starting rootless is the default)
init_options        sent at `initialize`
settings            sent at `initialize` and via didChangeConfiguration
capabilities        merged over nxvim's base client capabilities
commands            client-side handlers for this server's code-action
                    commands
name                the client name, when it differs from the file's name
offset_encoding     force a position encoding rather than negotiating one
get_language_id     function(bufnr, filetype) -> the LSP languageId
before_init         function(init_params, config) — may return a promise
on_init             function(client, result)
on_attach           function(client, bufnr)
on_exit             function(code, signal, client)
```

To add a server of your own, create `lsp/<name>.lua` anywhere on the runtimepath
returning such a table. It is picked up with no registration step.

Every bundled server's install notes and the defaults it sets are in a generated
companion page: `:help lspconfig-all`, or one server at a time with
`:help lspconfig-clangd`.

## Priority tiers

A flat `root_markers` list is one tier of equals — the nearest directory holding any of
them wins. A list of lists is several tiers, and **each tier is exhausted over the whole
tree before the next is tried anywhere**:

```lua
root_markers = { { "package-lock.json", "yarn.lock" }, { ".git" } },
```

That is what attaches a package inside a monorepo at the monorepo root rather than at
its own nested `.git`. The conventional trailing `".git"` is a *fallback*, not a
competitor.

## Unsupported keys

A config carrying `handlers` or `reuse_client` gets a warning naming the key and what
happens instead — nxvim does not route server-initiated messages into Lua, and always
reuses one client per (config name, root). A key that is simply not recognised is named
too, because a silently-ignored `filetype` (singular) looks exactly like a server that
won't start.

# Writing a config

`require("nxvim-lspconfig.util")` is the helper surface every bundled config is written
against — the native replacement for upstream's `lspconfig.util`. Everything that
touches the filesystem or a subprocess returns a **promise**.

```lua
local util = require("nxvim-lspconfig.util")

return {
  -- Prefers the project's own node_modules/.bin copy, else $PATH —
  -- resolved asynchronously, without the editor pausing.
  cmd = util.node_cmd("typescript-language-server"),
  filetypes = { "typescript", "typescriptreact" },
  root_markers = { { "package-lock.json", "yarn.lock" }, { ".git" } },
}
```

## Paths and buffers

```
util.joinpath / dirname / basename / normalize / relpath / ancestors
                            re-exported from nx.utils — one implementation
util.cwd()                  the editor's effective working directory
util.home()                 the user's home directory
util.bufname(bufnr)         the buffer's full path, "" when unnamed
util.buf_command(bufnr, name, fn[, opts])
                            define a buffer-local :Name
util.tabsize([bufnr])       'shiftwidth', or 'tabstop' when it is 0
util.exe(name[, ext])       name with this platform's executable extension
```

## The filesystem

```
util.root(bufnr, markers)   promise of the root, with priority tiers
util.root_of_path(path, markers)
                            the same, walking up from a path
util.root_pattern(...)      function(path) -> promise of the root;
                            markers are GLOBS, argument order is priority
util.root_dir(fn)           a root_dir whose body may nx.await
util.find_upward(from, names[, opts])
                            promise of the nearest matching path
util.find_upward_all(from, names[, opts])
                            promise of all of them, nearest first
                            (opts.limit caps; opts.stop bounds the walk)
util.exists(path)           promise of a boolean
util.is_dir(path)           promise of a boolean
util.read_json(path)        promise of the decoded file, or nil
util.root_markers_with_field(root_files, names, field, fname[, mode])
                            append names whose manifest mentions field
util.insert_package_json(root_files, field, fname)
                            the package.json special case of the above
util.get_typescript_server_path(root_dir)
                            the nearest node_modules/typescript/lib, or ""
```

## Programs and URIs

```
util.which(name)            promise of the absolute path, or nil
util.local_bin(root, name)  promise of <root>/node_modules/.bin/<name>
util.node_cmd(name[, args]) a cmd builder preferring the local copy
util.system(cmd[, opts])    promise of { code, stdout, stderr }
util.output(cmd[, opts])    promise of trimmed stdout, or nil if it failed
util.uri_from_path(path)    a percent-encoded file:// URI
util.uri_from_buf(bufnr)    the buffer's file:// URI ("" when it has none)
util.uri_to_path(uri)       the path a file:// URI names, or nil
```

## Declining a buffer

`root_dir` has three answers, and they are all different:

```lua
root_dir = util.root_dir(function(bufnr, on_dir)
  local deno = util.root_pattern("deno.json", "deno.jsonc")
  local dir = nx.await(deno(util.bufname(bufnr)))
  if dir then
    return          -- DECLINE: this is a Deno tree, ts_ls should stay out
  end
  on_dir(nx.await(util.root(bufnr, { "package.json" })))  -- may be nil
end)
```

Calling `on_dir(dir)` attaches at `dir`; calling `on_dir(nil)` says "no root found", and
the server starts rootless unless it declares `workspace_required`; **returning without
calling back at all** declines the buffer outright, which is how a config says another
server owns this file.

# What changed from upstream

**The `require('lspconfig').server.setup{}` framework is gone** — deleted, not aliased,
along with `lua/lspconfig/`, `plugin/lspconfig.lua`, and the neovim-internals plumbing
they depended on (`vim.lsp.config._configs`, `vim.uv.new_timer`, `vim.deprecate`,
`:checkhealth`). Use `nx.lsp.enable` / `nx.lsp.config`, or `setup()`.

**Nothing blocks.** Upstream's helpers are built on `vim.fs.root`, `vim.fn.executable`,
`vim.uv.fs_stat`, `io.open` and `vim.system(…):wait()`, all of which stop the editor
while they work. Here, a config field that needs I/O returns a promise and `nx.lsp`
awaits it before spawning. Roughly fifty upward probes, every tool query, and every
`node_modules/.bin` lookup were rewritten for this.

**No version gating.** Upstream's `vim.fn.has('nvim-0.11')` branches are gone; nxvim is
not versioned by neovim.

**`:checkhealth` is not ported.** `:LspInfo` reports what is running, its root, its
capabilities and its log path, which is what those health checks were read for.

**Two configs lost their `handlers`.** denols' `deno:` virtual-document handler and
ts_ls' `_typescript.rename` follow-up needed server-initiated message routing that
`nx.lsp` does not do; leaving them in would have been code that cannot run. Each is
documented in its own config's `---@brief`.

# Troubleshooting

**The server doesn't start.** `:LspInfo` lists what is running and what is configured.
The three usual causes are the binary not being on `$PATH` (check with `:LspLog` after
`$NXVIM_LSP_LOG_LEVEL=debug`), no root being found for a server that declares
`workspace_required`, or the buffer's filetype not being one the config declares.

**It attached at the wrong directory.** The config's `root_markers` tiers decide this.
Override them for one server:

```lua
nx.lsp.config("ts_ls", {
  root_markers = { { "tsconfig.json" }, { ".git" } },
})
```

**A config change had no effect.** Most servers read their configuration once, at
`initialize`. Run `:LspRestart` after editing `nx.lsp.config`.

**Two servers are fighting over formatting.** `nx.lsp.format()` uses the first attached
server that advertises formatting, in config-name order. Name the one you want:
`nx.lsp.format({ name = "ruff" })`.

# Development

The plugin carries a Lua test suite on nxvim's native `nx.test` harness. Run it from a
checkout with:

```sh
nxvim --test-plugin .
```

It loads and runs all 407 configs — every `cmd` builder, `root_dir`, `before_init` and
`get_language_id`, with the arguments `nx.lsp` really passes — enters the reworked
`on_attach` bodies against a recording client, and exercises the `util` helpers against
real project trees.

Two sets of generated files, neither edited by hand. This page's `.txt` comes from
its `.md` via [panvimdoc](https://github.com/kdheepak/panvimdoc)
(`bash scripts/gen-vimdoc.sh`, needs `pandoc` + `git`). The per-server reference —
`doc/configs.md` and `doc/configs.txt` — comes from the `---@brief` block in each
`lsp/<name>.lua`, rendered by `scripts/docgen.lua` running under nxvim itself
(`bash scripts/gen-configs.sh`); to change what it says, edit the config's own doc
comment. A pre-push hook (via [pre-commit](https://pre-commit.com)) verifies both are
current — enable it once after cloning with `pre-commit install --hook-type pre-push`.

Lua is formatted with [stylua](https://github.com/JohnnyMorganz/StyLua): `stylua .`.

# Credits

A native nxvim port of [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) by the
Neovim contributors, which supplies the curated server configurations ported here.

Licensed under the terms of the Apache 2.0 license — see `LICENSE.md`.
