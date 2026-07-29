---@brief
---
--- https://github.com/golang/tools/tree/master/gopls
---
--- Google's lsp server for golang.
---
--- [Settings documentation](https://go.dev/gopls/settings)
---
--- NOTE: since v0.22.0 gopls no longer advertises semantic tokens to clients
--- by default. To maintain previous behavior, semantic tokens are enabled on client side.
--- To disable this feature, set `semanticTokens` option to `false`.
---
--- ```lua
---   nx.lsp.config('gopls', {
---     settings = {
---       gopls = {
---         semanticTokens = false
---       }
---     }
---   })
--- ```

--- @class go_dir_custom_args
---
--- @field envvar_id string
---
--- @field custom_subdir string?

local util = require("nxvim-lspconfig.util")

--- `go env <VAR>`, memoized for the session — the values are properties of the
--- toolchain, not of the buffer, and shelling out once per buffer open would be a
--- subprocess on every `:e`. `nil` means the probe failed and stays retryable.
---
--- Upstream fires this probe from a `root_dir` that cannot wait for it, so the FIRST
--- Go buffer of a session always decides its root with an empty cache — the branch
--- below never fires when it matters. Awaiting the answer is what makes it work.
local go_dir_cache = {}
--- @param custom_args go_dir_custom_args
--- @return string?
local identify_go_dir = nx.async(function(custom_args)
  local key = custom_args.envvar_id
  if go_dir_cache[key] then
    return go_dir_cache[key]
  end
  local cmd = { "go", "env", key }
  local output = nx.await(util.system(cmd))
  local res = nx.str.trim(output.stdout or "")
  if output.code ~= 0 or res == "" then
    nx.notify(
      ("[gopls] identify " .. key .. " dir cmd failed with code %d: %s\n%s"):format(
        output.code,
        nx.inspect(cmd),
        output.stderr
      ),
      nx.log.levels.WARN
    )
    return nil
  end
  if custom_args.custom_subdir and custom_args.custom_subdir ~= "" then
    res = res .. custom_args.custom_subdir
  end
  go_dir_cache[key] = res
  return res
end)

--- The root a Go buffer belongs to. A file inside the module cache or the standard
--- library is not part of any project of its own — it was jumped into from one — so it
--- attaches to the gopls already serving that project rather than starting a second
--- server rooted in `$GOMODCACHE`.
--- @param fname string
--- @return string?
local get_root_dir = nx.async(function(fname)
  local std_lib = nx.await(identify_go_dir({ envvar_id = "GOROOT", custom_subdir = "/src" }))
  local mod_cache = nx.await(identify_go_dir({ envvar_id = "GOMODCACHE" }))

  for _, dir in ipairs({ mod_cache, std_lib }) do
    if dir and fname:sub(1, #dir) == dir then
      local clients = nx.lsp.clients({ name = "gopls" })
      if #clients > 0 then
        return clients[#clients].config.root_dir
      end
    end
  end
  -- see: https://github.com/neovim/nvim-lspconfig/issues/804
  return nx.await(util.root_of_path(fname, { { "go.work" }, { "go.mod" }, { ".git" } }))
end)

return {
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_dir = nx.async(function(bufnr)
    return nx.await(get_root_dir(util.bufname(bufnr)))
  end),
  settings = {
    gopls = {
      semanticTokens = true,
    },
  },
}
