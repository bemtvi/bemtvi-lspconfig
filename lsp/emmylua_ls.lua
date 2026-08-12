---@brief
---
--- https://github.com/EmmyLuaLs/emmylua-analyzer-rust
---
--- EmmyluaLs, a language server for Lua.
---
--- `emmylua_ls` can be installed using `cargo` by following the [instructions](https://github.com/EmmyLuaLs/emmylua-analyzer-rust#install).
---
--- The default `cmd` assumes that the `emmylua_ls` binary can be found in `$PATH`.
--- You may want to symlink to the cargo artifact:
--- ```
--- ln -s $(pwd)/target/release/emmylua_ls ~/bin/emmylua_ls
--- ```
---
--- See the emmylua_ls [configuration guide](https://github.com/EmmyLuaLs/emmylua-analyzer-rust/blob/main/docs/config/emmyrc_json_EN.md)
--- for settings documentation.
---
--- ## Editing your bemtvi config or a plugin
---
--- Point the server at the Lua bemtvi actually runs, and tell it about `btv` — otherwise
--- every `btv.*` call in your config is flagged as an undefined global. A project that
--- ships its own `.emmyrc.json` overrides all of this, so there is nothing to guard.
---
--- ```lua
--- btv.lsp.config('emmylua_ls', {
---   settings = {
---     emmylua = {
---       -- bemtvi's Lua is PUC 5.4, NOT LuaJIT (which bemtvi dropped).
---       runtime = { version = 'Lua 5.4' },
---       -- `btv` is the plugin API; `vim` is the bounded compat surface.
---       diagnostics = { globals = { 'btv', 'vim' } },
---       workspace = {
---         -- Every `lua/` directory on the runtimepath, so a plugin's modules
---         -- resolve. This can be slow on a large plugin set.
---         library = btv.runtime_file('lua', true),
---       },
---     },
---   },
--- })
--- ```

local root_markers1 = {
  ".emmyrc.json",
  ".emmyrc.lua",
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
  cmd = { "emmylua_ls" },
  filetypes = { "lua" },
  root_markers = { root_markers1, root_markers2, { ".git" } },
  workspace_required = false,
  settings = {
    emmylua = {
      codeLens = { enable = true },
      hint = { enable = true },
    },
  },
}
