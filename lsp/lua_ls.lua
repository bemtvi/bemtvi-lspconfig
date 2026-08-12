---@brief
---
--- https://github.com/luals/lua-language-server
---
--- Lua language server.
---
--- `lua-language-server` can be installed by following the instructions [here](https://luals.github.io/#neovim-install).
---
--- The default `cmd` assumes that the `lua-language-server` binary can be found in `$PATH`.
---
--- ## Editing your bemtvi config or a plugin
---
--- Point the server at the Lua bemtvi actually runs, and tell it about `btv` — otherwise
--- every `btv.*` call in your config is flagged as an undefined global.
---
--- ```lua
--- btv.lsp.config('lua_ls', {
---   settings = {
---     Lua = {
---       -- bemtvi's Lua is PUC 5.4, NOT LuaJIT (which bemtvi dropped).
---       runtime = {
---         version = 'Lua 5.4',
---         -- Resolve `require("mod")` the way bemtvi's runtimepath does.
---         path = { 'lua/?.lua', 'lua/?/init.lua' },
---       },
---       diagnostics = {
---         -- `btv` is the plugin API; `vim` is the bounded compat surface.
---         globals = { 'btv', 'vim' },
---       },
---       workspace = {
---         checkThirdParty = false,
---         -- Every `lua/` directory on the runtimepath, so a plugin's modules
---         -- resolve. This can be slow on a large plugin set.
---         library = btv.runtime_file('lua', true),
---       },
---     },
---   },
--- })
--- ```
---
--- There is no on-disk copy of the `btv.*` API to add to `workspace.library` — the
--- prelude is compiled into the editor — so `btv` is declared a global rather than
--- type-checked. The rendered API reference is in the book and at `:help`.
---
--- See `lua-language-server`'s [documentation](https://luals.github.io/wiki/settings/) for an explanation of the above fields:
--- * [Lua.runtime.path](https://luals.github.io/wiki/settings/#runtimepath)
--- * [Lua.workspace.library](https://luals.github.io/wiki/settings/#workspacelibrary)
---

local root_markers1 = {
  ".emmyrc.json",
  ".luarc.json",
  ".luarc.jsonc",
}
local root_markers2 = {
  ".luacheckrc",
  ".stylua.toml",
  "stylua.toml",
  "selene.toml",
  "selene.yml",
}

return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { root_markers1, root_markers2, { ".git" } },
  settings = {
    Lua = {
      codeLens = { enable = true },
      hint = { enable = true, semicolon = "Disable" },
    },
  },
}
