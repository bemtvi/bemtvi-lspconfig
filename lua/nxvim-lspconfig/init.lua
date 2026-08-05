-- nxvim-lspconfig — ready-made `nx.lsp` configs for every language server
-- nvim-lspconfig knows about, ported natively.
--
-- This is a port, not a compatibility layer. Upstream's `require('lspconfig').x
-- .setup{}` framework is gone — deleted, not aliased — along with everything that
-- depended on neovim internals (`vim.lsp.config._configs`, `vim.uv.new_timer`,
-- `vim.deprecate`, `:checkhealth`). What remains is what actually carries value:
-- one curated config table per server, rewritten against `nx.*` so that nothing
-- blocks the editor.
--
-- ## Two ways to use it
--
-- **The native path.** `nx.lsp` reads each server's preset straight off this
-- plugin's runtimepath (`lsp/<name>.lua`), so once it is installed there is nothing
-- to require:
--
-- ```lua
-- nx.lsp.enable("rust_analyzer")
-- nx.lsp.config("rust_analyzer", { settings = { … } })  -- to override
-- ```
--
-- **The convenience path.** `setup()` enables a batch, applies global
-- `capabilities` / `on_attach`, installs the extended keymap set, and takes
-- per-server overrides inline:
--
-- ```lua
-- require("nxvim-lspconfig").setup({
--   servers = {
--     "lua_ls", "pyright", "gopls",
--     rust_analyzer = { settings = { ["rust-analyzer"] = { … } } },
--   },
-- })
-- ```
--
-- ## What "everything async" means here
--
-- Every config field that needs to touch the filesystem or run a program — locating
-- a project-local binary, probing for a manifest, asking a toolchain where its
-- sources live — is a promise. `nx.lsp` awaits `cmd` builders and `before_init`
-- hooks before it spawns, so a config never blocks the editor to answer a question
-- about the project. See `nxvim-lspconfig.util` for the helpers configs use.

local M = {}

-- ----- the bundled set --------------------------------------------------------

-- The bundled server names, discovered from THIS plugin's `lsp/` directory via the
-- runtimepath rather than hard-coded, so the list can't drift from the files that
-- actually exist (a hard-coded list is a lie the moment a config is added or
-- renamed). Computed once and memoized — it is a runtimepath glob, not free.
local available_cache

-- `M.available()` -> a sorted list of every server this plugin ships a config for.
function M.available()
  if available_cache then
    return available_cache
  end
  local seen, names = {}, {}
  for _, path in ipairs(nx.runtime_file("lsp/*.lua", true)) do
    local name = nx.utils.basename(path)
    name = name and name:match("^(.*)%.lua$")
    if name and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  table.sort(names)
  available_cache = names
  return names
end

-- `M.is_available(name)` -> is there a bundled config by that name?
function M.is_available(name)
  for _, n in ipairs(M.available()) do
    if n == name then
      return true
    end
  end
  return false
end

-- `M.for_filetype(ft)` -> the bundled servers whose `filetypes` include `ft`, sorted.
-- Backs argument-less `:LspStart`.
--
-- The filetypes come from `nx.lsp.get_config`, i.e. the config **as resolved** —
-- preset plus any override the user has applied — rather than from the preset file
-- alone. That matters: someone who added `htmldjango` to `html`'s filetypes expects
-- `:LspStart` in an htmldjango buffer to find it. It also means there is one loader
-- for `lsp/<name>.lua` in the editor, not a second copy here that could disagree with
-- the dispatcher about what a config says.
function M.for_filetype(ft)
  local out = {}
  if type(ft) ~= "string" or ft == "" then
    return out
  end
  for _, name in ipairs(M.available()) do
    local cfg = nx.lsp.get_config(name)
    if cfg.filetypes and nx.tbl.contains(cfg.filetypes, ft) then
      out[#out + 1] = name
    end
  end
  return out
end

-- ----- the default keymaps ----------------------------------------------------
-- nxvim already installs the core LSP maps buffer-local on attach (gd / gD / gr /
-- K / <C-k>), so this adds only the rest of the now-standard set, at the
-- OVERRIDABLE rung (`default = true`) so a user's own map for the same key always
-- wins. Opt out of the whole set with `setup({ keymaps = false })`.
--
-- Two of these are *alternative spellings* of maps the core already provides —
-- `<C-]>` for `gd`, `<C-s>` for `<C-k>` — rather than new verbs. They live here for
-- that reason: they are the muscle memory a vim/neovim user arrives with, and the
-- core's built-in set stays the small one that earns its place on every buffer a
-- server touches.
local DEFAULT_KEYMAPS = {
  { "n", "grn", nx.lsp.rename, "LSP rename" },
  { "n", "gra", nx.lsp.code_action, "LSP code action" },
  { "n", "grr", nx.lsp.references, "LSP references" },
  { "n", "gri", nx.lsp.implementation, "LSP implementation" },
  { "n", "grt", nx.lsp.type_definition, "LSP type definition" },
  { "n", "gO", nx.lsp.document_symbol, "LSP document symbols" },
  { "n", "<leader>ls", nx.lsp.workspace_symbol, "LSP workspace symbols" },
  { "n", "<leader>lf", nx.lsp.format, "LSP format buffer" },
  -- `<C-]>` is the TAG JUMP, and a language server is what you have instead of a
  -- tags file here — neovim reaches the same place by pointing `'tagfunc'` at the
  -- client, a mechanism nxvim has no other use for, so this binds it directly.
  -- `<C-o>` still comes back: a goto records the jumplist.
  { "n", "<C-]>", nx.lsp.definition, "LSP go to definition" },
  -- neovim's `i_CTRL-S`, in insert AND select mode, beside nxvim's own `<C-k>`.
  -- Terminal flow control would eat `<C-s>` as XOFF, but raw mode clears `IXON`,
  -- so it reaches the editor.
  { "i", "<C-s>", nx.lsp.signature_help, "LSP signature help" },
  { "s", "<C-s>", nx.lsp.signature_help, "LSP signature help" },
}

local function install_default_keymaps(bufnr)
  for _, m in ipairs(DEFAULT_KEYMAPS) do
    nx.keymap.set(m[1], m[2], m[3], { buffer = bufnr, default = true, desc = m[4] })
  end
end

-- Flip inlay hints for the current buffer (the RHS of the `<leader>lh` toggle).
local function toggle_inlay_hints()
  nx.lsp.inlay_hint.enable(not nx.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end

-- ----- the global "*" layer ---------------------------------------------------

-- Compose the global `on_attach`: default keymaps (unless opted out), the
-- inlay-hint toggle map and initial enable (when asked), then the user's own hook.
-- Returns nil when there is nothing to do, so an empty hook is never registered.
local function build_on_attach(opts)
  local want_keymaps = opts.keymaps ~= false
  local want_inlay = opts.inlay_hints == true
  local user = opts.on_attach
  if not (want_keymaps or want_inlay or user) then
    return nil
  end
  return function(client, bufnr)
    if want_keymaps then
      install_default_keymaps(bufnr)
      nx.keymap.set("n", "<leader>lh", toggle_inlay_hints, {
        buffer = bufnr,
        default = true,
        desc = "LSP toggle inlay hints",
      })
    end
    if want_inlay and client.server_capabilities and client.server_capabilities.inlay_hints then
      nx.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end
    if user then
      user(client, bufnr)
    end
  end
end

-- Apply the `"*"` all-clients override layer, which every server inherits.
local function apply_global(opts)
  local star = {}
  for _, key in ipairs({ "capabilities", "root_markers", "settings" }) do
    if opts[key] ~= nil then
      star[key] = opts[key]
    end
  end
  local on_attach = build_on_attach(opts)
  if on_attach then
    star.on_attach = on_attach
  end
  if next(star) ~= nil then
    nx.lsp.config("*", star)
  end
end

-- ----- per-server registration ------------------------------------------------

-- Register one server's override into `nx.lsp`'s registry. The bundled preset is
-- NOT merged in here: `nx.lsp` resolves `"*"` ⊕ the runtimepath preset ⊕ this
-- override itself, so merging it a second time would just duplicate work — and,
-- with list-replacing deep-merge semantics, could quietly re-introduce a preset
-- list the user meant to replace.
--
-- An unknown name fails loud. The whole point of this plugin is its curated set, so
-- a typo is a mistake to report, not a config to silently enable nothing for.
local function register(name, override)
  if not M.is_available(name) then
    error(
      "nxvim-lspconfig: unknown server '"
        .. tostring(name)
        .. "' (there are "
        .. #M.available()
        .. " bundled configs; see :LspInfo or the README for the list)",
      2
    )
  end
  if override and next(override) ~= nil then
    nx.lsp.config(name, override)
  end
end

-- Walk a `servers` value, calling `fn(name, override)` for each. Accepts:
--
-- ```
-- "all"                          every bundled server (rarely what you want)
-- "gopls"                        a single name
-- { "lua_ls", "pyright" }        a list of names, no overrides
-- { lua_ls = { settings = … } }  a map of name -> override
-- { "gopls", eslint = false }    mixed; a `false` value skips that server
-- ```
local function each_server(servers, fn)
  if type(servers) == "string" then
    if servers == "all" then
      for _, n in ipairs(M.available()) do
        fn(n, nil)
      end
    else
      fn(servers, nil)
    end
    return
  end
  if type(servers) ~= "table" then
    error('nxvim-lspconfig: `servers` must be a name, a list, a map, or "all"', 2)
  end
  for k, v in pairs(servers) do
    if type(k) == "number" then
      fn(v, nil)
    elseif v ~= false then
      fn(k, type(v) == "table" and v or nil)
    end
  end
end

-- ----- public API --------------------------------------------------------------

-- `M.enable(servers)` — register and enable a batch (see `each_server` for the
-- accepted shapes). Idempotent and additive: call it as often as you like.
function M.enable(servers)
  local names = {}
  each_server(servers, function(name, override)
    register(name, override)
    names[#names + 1] = name
  end)
  if #names > 0 then
    nx.lsp.enable(names)
  end
  return M
end

-- `M.setup(opts)` — the one-call entry point.
--
-- ```
-- opts.servers       "all" | a name | a list of names | a map name -> (override | false)
-- opts.capabilities  client capabilities broadcast to every server ("*")
-- opts.settings      settings merged into every server ("*")
-- opts.root_markers  extra root markers for every server ("*")
-- opts.on_attach     function(client, bufnr) run when any server attaches
-- opts.keymaps       install the extended LSP keymaps? (default true)
-- opts.inlay_hints   turn inlay hints on for capable servers? (default false)
-- ```
function M.setup(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    error("nxvim-lspconfig.setup: opts must be a table", 2)
  end
  apply_global(opts)
  if opts.servers ~= nil then
    M.enable(opts.servers)
  end
  M.config = opts
  return M
end

-- The helper surface bundled configs are written against, re-exported so a user's
-- own config can build on the same helpers (`util.node_cmd`, `util.root`, …)
-- without a second `require`.
M.util = require("nxvim-lspconfig.util")

return M
