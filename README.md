# bemtvi-lspconfig

Ready-made `btv.lsp` configurations for **407 language servers** — a native port of
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) to
[bemtvi](https://github.com/bemtvi/bemtvi).

This is a **port, not a compatibility layer.** bemtvi runs no neovim plugins; upstream's
configs were treated as a behavioral spec and rewritten against bemtvi's own `btv.*`
surfaces. Everything that touches the filesystem or runs a program is asynchronous,
because bemtvi does no blocking I/O on the editor thread — ever.

> This plugin only *configures* servers; it does not install them. Install the language
> server binaries yourself. A server whose binary isn't there fails loud — bemtvi never
> pretends a server that isn't running is working.

## Install

Declare it with the built-in `:Plugins` manager, then enable the servers you want:

```lua
btv.plugins({
  {
    "bemtvi/bemtvi-lspconfig",
    config = function()
      btv.lsp.enable({ "lua_ls", "gopls", "rust_analyzer" })
    end,
  },
})
```

Run `:PluginSync` to clone it. Open a file of a matching type and, if the server is
installed, it attaches.

`btv.lsp` reads each server's config straight off this plugin's runtimepath
(`lsp/<name>.lua`), so there is nothing to require and no registration step. Override
any of them with `btv.lsp.config("gopls", { … })`, or use the `setup()` convenience
entry point:

```lua
require("bemtvi-lspconfig").setup({
  servers = { "lua_ls", "pyright", gopls = { settings = { … } } },
  inlay_hints = true,
})
```

To try it before touching your own config, `examples/` is a runnable demo with
`lua_ls` (needs `lua-language-server` on `$PATH`):

```sh
BEMTVI_CONFIG=examples bemtvi examples/sample.lua
```

## Documentation

Full docs — enabling servers, `setup()` options, the `:Lsp*` commands, keymaps, the
config fields, the `util` helper surface, and what changed from upstream — live in the
help file:

- In editor: `:help bemtvi-lspconfig`
- On GitHub: [doc/bemtvi-lspconfig.md](./doc/bemtvi-lspconfig.md) (the help source)

Per-server install notes and the defaults each config sets — all 407 of them,
generated from the configs themselves:

- In editor: `:help lspconfig-all`, or one server with `:help lspconfig-clangd`
- On GitHub: [doc/configs.md](./doc/configs.md)

## Development

Run the Lua test suite from a checkout with `bemtvi --test-plugin .`, and the
example's own spec with `bemtvi --test-plugin examples`. Format with `stylua .` and
lint with `selene .` (a selene built with the Lua 5.4 grammar:
`cargo install selene --features selene-lib/lua54`).

Two generated files, neither of which is edited by hand:

- `doc/bemtvi-lspconfig.txt` — from `doc/bemtvi-lspconfig.md` via
  [panvimdoc](https://github.com/kdheepak/panvimdoc): `bash scripts/gen-vimdoc.sh`
  (needs `pandoc` + `git`). **Edit the `.md`.**
- `doc/configs.md` + `doc/configs.txt` — from the `---@brief` block in each
  `lsp/<name>.lua`, by `scripts/docgen.lua` running under bemtvi itself:
  `bash scripts/gen-configs.sh`. **Edit the config's doc comment.**

[pre-commit](https://pre-commit.com) hooks run stylua and selene on each commit and,
before a push, verify both generated files are current. Enable them once after
cloning with `pre-commit install --hook-type pre-commit --hook-type pre-push`.

## License

Copyright Neovim contributors and bemtvi contributors. All rights reserved.

Licensed under the terms of the Apache 2.0 license — see [LICENSE.md](LICENSE.md).
