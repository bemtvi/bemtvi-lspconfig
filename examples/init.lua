-- Runnable demo for bemtvi-lspconfig: one language server, enabled in one line.
--
--     BEMTVI_CONFIG=examples bemtvi examples/sample.lua
--
-- Run it from a checkout of this repo, with `lua-language-server` on your PATH
-- (https://luals.github.io). The plugin is loaded straight from the checkout, so
-- there is nothing to clone and no `:PluginSync` to run.
--
-- Type this / see that:
--
--   1. Open sample.lua and wait a second or two.  →  "lua_ls attached to buffer 1"
--      (section 3's on_attach), and `:LspInfo` lists `lua_ls` with its root and
--      capabilities. Nothing here says which binary to run or which filetypes it
--      serves: that came off the bundled `lsp/lua_ls.lua`.
--   2. `:LspInfo` and read the root.  →  this repo's root. The bundled markers come
--      in tiers (`.luarc.json`-class, then `stylua.toml`-class, then `.git`), and
--      the repo's `stylua.toml` wins in the second tier.
--   3. Line 10 of sample.lua: `undefined_global`.  →  a diagnostic. `btv` on line 6
--      is NOT flagged, because section 2 declared it a global.
--   4. Cursor on `greet` (line 15), press `K`.  →  a hover float with its signature.
--      `<C-]>` jumps to the definition (line 9); `<C-o>` comes back.
--   5. `grn` on `greet`, type `salute`, Enter.  →  every use in the file renamed.
--      `grr` lists the references, `gO` the file's symbols.
--   6. `<leader>lh` (leader is Space here).  →  inlay hints toggle: the parameter
--      names appear at the call on line 15.
--   7. `:LspStop`.  →  "LspStop: stopped lua_ls", and the server stays off for new
--      Lua buffers too. `:LspStart` turns it back on.

btv.g.mapleader = " "

-- This file's directory, and the repo root above it. Taken from the chunk's own
-- source path rather than `btv.stdpath("config")`, so the same file works whether
-- it is the config ($BEMTVI_CONFIG) or sourced by the spec in test/.
local example_dir = debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$")
local plugin_root = btv.utils.normalize(btv.utils.joinpath(example_dir, ".."))

------------------------------------------------------------------------------
-- 1. Put the plugin on the runtimepath.
--
--    A real config writes `{ "bemtvi/bemtvi-lspconfig" }` and runs `:PluginSync`.
--    A `dir` spec loads a local checkout and is never cloned.
------------------------------------------------------------------------------
btv.plugins({
  { name = "bemtvi-lspconfig", dir = plugin_root },
})

------------------------------------------------------------------------------
-- 2. Override the bundled config.
--
--    Your table is deep-merged OVER `lsp/lua_ls.lua`: `cmd`, `filetypes` and the
--    root markers still come from the plugin, only what you name here changes.
------------------------------------------------------------------------------
btv.lsp.config("lua_ls", {
  settings = {
    Lua = {
      -- bemtvi runs PUC Lua 5.4, not LuaJIT.
      runtime = { version = "Lua 5.4" },
      -- Without this, every `btv.*` call reads as an undefined global (step 3).
      diagnostics = { globals = { "btv" } },
    },
  },
})

------------------------------------------------------------------------------
-- 3. Enable it, with the plugin's keymaps.
--
--    `setup()` enables the listed servers and installs the extended keymap set on
--    attach (grn, gra, grr, gri, grt, gO, <C-]>, <leader>lf, <leader>lh, …) at the
--    overridable rung, so a mapping of your own always wins. `on_attach` runs for
--    every server, after the plugin's own hook.
--
--    The bare native path is a single line, with no keymaps:
--      btv.lsp.enable("lua_ls")
------------------------------------------------------------------------------
require("bemtvi-lspconfig").setup({
  servers = { "lua_ls" },
  inlay_hints = false, -- step 6 toggles them by hand
  on_attach = function(client, bufnr)
    btv.notify(("%s attached to buffer %d"):format(client.name, bufnr))
  end,
})

btv.o.number = true
btv.o.signcolumn = "yes"
