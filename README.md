# nxvim-lspconfig

Ready-made `nx.lsp` configurations for **407 language servers** — a native port of
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) to
[nxvim](https://github.com/davidrios/nxvim).

This is a **port, not a compatibility layer.** nxvim runs no neovim plugins; upstream's
configs were treated as a behavioral spec and rewritten against nxvim's own `nx.*`
surfaces. Everything that touches the filesystem or runs a program is asynchronous,
because nxvim does no blocking I/O on the editor thread — ever.

> This plugin only *configures* servers; it does not install them. Install the language
> server binaries yourself. A server whose binary isn't there fails loud — nxvim never
> pretends a server that isn't running is working.

## Install

Declare it with the built-in `:Plugins` manager, then enable the servers you want:

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

`nx.lsp` reads each server's config straight off this plugin's runtimepath
(`lsp/<name>.lua`), so there is nothing to require and no registration step. Override
any of them with `nx.lsp.config("gopls", { … })`, or use the `setup()` convenience
entry point:

```lua
require("nxvim-lspconfig").setup({
  servers = { "lua_ls", "pyright", gopls = { settings = { … } } },
  inlay_hints = true,
})
```

## Documentation

Full docs — enabling servers, `setup()` options, the `:Lsp*` commands, keymaps, the
config fields, the `util` helper surface, and what changed from upstream — live in the
help file:

- In editor: `:help nxvim-lspconfig`
- On GitHub: [doc/nxvim-lspconfig.md](./doc/nxvim-lspconfig.md) (the help source)

Per-server install notes and the defaults each config sets — all 407 of them,
generated from the configs themselves:

- In editor: `:help lspconfig-all`, or one server with `:help lspconfig-clangd`
- On GitHub: [doc/configs.md](./doc/configs.md)

## Development

Run the Lua test suite from a checkout with `nxvim --test-plugin .`; format with
`stylua .`.

Two generated files, neither of which is edited by hand:

- `doc/nxvim-lspconfig.txt` — from `doc/nxvim-lspconfig.md` via
  [panvimdoc](https://github.com/kdheepak/panvimdoc): `bash scripts/gen-vimdoc.sh`
  (needs `pandoc` + `git`). **Edit the `.md`.**
- `doc/configs.md` + `doc/configs.txt` — from the `---@brief` block in each
  `lsp/<name>.lua`, by `scripts/docgen.lua` running under nxvim itself:
  `bash scripts/gen-configs.sh`. **Edit the config's doc comment.**

A pre-push hook (via [pre-commit](https://pre-commit.com)) verifies both are current
— enable it once after cloning with `pre-commit install --hook-type pre-push`.

## License

Copyright Neovim contributors and nxvim contributors. All rights reserved.

Licensed under the terms of the Apache 2.0 license — see [LICENSE.md](LICENSE.md).
