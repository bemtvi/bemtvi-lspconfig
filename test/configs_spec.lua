-- Every bundled server config loads, and resolves without blocking.
--
-- This is the suite the port is measured by. A config here is a chunk of Lua that
-- normally only runs when someone edits that language, so a mistake in one of the
-- 400+ — a `vim.*` that doesn't exist here, a helper renamed, a `root_dir` that
-- returns instead of calling back — is invisible until exactly the person who uses
-- that server hits it. Loading and *running* all of them in one pass is what makes
-- the port checkable at all.
--
-- The strong assertion is the third test: every `cmd` builder, `root_dir`,
-- `before_init` and `get_language_id` in the repo is CALLED, against a real buffer,
-- **with the same arguments `nx.lsp` passes** (a copy of the config carrying the
-- resolved `root_dir`) — so a hook reading a field off `config` is exercised the way
-- it really runs, not against a synthetic table that would make it fail here and
-- work in the editor, or the reverse.

local lspconfig = require("nxvim-lspconfig")

-- Load one server's config table the way `nx.lsp` does, off the runtimepath.
local function load_config(name)
  local paths = nx.runtime_file("lsp/" .. name .. ".lua", false)
  local chunk = assert(loadfile(paths[1]), "no chunk for " .. name)
  return chunk()
end

-- `nx.lsp`'s `start_cfg`: the config plus the resolved root, which is what both the
-- `cmd` builder and `before_init` receive as their `config` argument.
local function start_cfg(cfg, root)
  local out = {}
  for k, v in pairs(cfg) do
    out[k] = v
  end
  out.root_dir = root
  return out
end

-- A config that refuses to start reports it by RAISING with its own name in front
-- (`gdscript: Godot's language server is reached over TCP…`) — the fail-loud
-- convention, and the deliberate opposite of a silent no-op. Told apart from a real
-- defect by that prefix, so a genuine crash in the same hook still fails this suite.
local function is_deliberate_refusal(name, err)
  return tostring(err):find(name .. ": ", 1, true) ~= nil
end

-- The keys `nx.lsp` reads, plus the two it knowingly does not act on. Anything else
-- earns a WARN at dispatch time (`nx.lsp` never silently drops a key), so an entry
-- outside this set is a real defect: `root_markers` misspelled means the server
-- attaches at the wrong directory and nothing says so.
local KNOWN = {
  cmd = true,
  cmd_env = true,
  filetypes = true,
  root_dir = true,
  root_markers = true,
  workspace_required = true,
  single_file_support = true,
  init_options = true,
  settings = true,
  capabilities = true,
  commands = true,
  name = true,
  offset_encoding = true,
  get_language_id = true,
  before_init = true,
  on_init = true,
  on_attach = true,
  on_exit = true,
  -- Unsupported-but-modelled: nxvim does not route server-initiated messages into
  -- Lua (`handlers`), and always reuses one client per (config name, root)
  -- (`reuse_client`). Both warn rather than erroring, so a config may still carry
  -- one; they are listed so the suite doesn't flag the warning as a typo.
  handlers = true,
  reuse_client = true,
}

-- Servers upstream ships with NO default `cmd`: the binary has no conventional name
-- or location, so the user must supply one (`nx.lsp.config('bicep', { cmd = … })`).
-- Named here rather than skipped by a blanket `if cfg.cmd then`, so the list is
-- visible and a config that loses its `cmd` by accident still fails.
local NO_DEFAULT_CMD = {
  bicep = true,
  bsl_ls = true,
  nelua_lsp = true,
  visualforce_ls = true,
}

-- Servers with no `filetypes`: cross-language tools (a linter bridge, a spell
-- checker, a completion daemon) that have no language of their own and attach to
-- whatever the user enables them for.
local ANY_FILETYPE = {
  basics_ls = true,
  contextive = true,
  copilot = true,
  cspell_ls = true,
  ctags_lsp = true,
  custom_elements_ls = true,
  efm = true,
  kakehashi = true,
  termux_language_server = true,
  typos_lsp = true,
  vectorcode_server = true,
}

nx.test.describe("nxvim-lspconfig: the bundled configs", function()
  nx.test.it("ships a config for every name it advertises", function()
    nx.test.expect(#lspconfig.available() > 400).to_be(true)
  end)

  nx.test.it("loads every config, and each returns a table of known keys", function()
    local bad = {}
    for _, name in ipairs(lspconfig.available()) do
      local ok, cfg = pcall(load_config, name)
      if not ok then
        bad[#bad + 1] = name .. ": " .. tostring(cfg)
      elseif type(cfg) ~= "table" then
        bad[#bad + 1] = name .. ": returned " .. type(cfg)
      else
        for key in pairs(cfg) do
          if not KNOWN[key] then
            bad[#bad + 1] = name .. ": unknown key `" .. tostring(key) .. "`"
          end
        end
      end
    end
    nx.test.expect(bad).to_equal({})
  end)

  nx.test.it("runs every cmd builder, root_dir, before_init and get_language_id", function(t)
    -- A real buffer with a real path: the probes walk up from the buffer's file, so
    -- an unnamed buffer would take the "no path" early return in most of them and
    -- prove nothing.
    local root = nx.test.tempdir()
    local file = nx.utils.joinpath(root, "probe.txt")
    nx.await(nx.fs.write(file, "x\n"))
    t:cmd("edit " .. file)
    local bufnr = nx.buf.current()

    local bad = {}
    local function run(name, what, fn, ...)
      local ok, res = pcall(fn, ...)
      if ok and nx.promise.is_promise(res) then
        ok, res = pcall(nx.await, res)
      end
      if not ok and not is_deliberate_refusal(name, res) then
        bad[#bad + 1] = name .. "." .. what .. " failed: " .. tostring(res)
      end
    end

    for _, name in ipairs(lspconfig.available()) do
      local cfg = load_config(name)
      local resolved = start_cfg(cfg, root)

      -- The `node_modules/.bin` resolvers and friends: a promise of the argv.
      if type(cfg.cmd) == "function" then
        run(name, "cmd", cfg.cmd, {}, resolved)
      end
      -- `root_dir(bufnr, on_dir)` may DECLINE by returning without calling back, so
      -- the assertion is only that it runs — not that it answers.
      if type(cfg.root_dir) == "function" then
        run(name, "root_dir", cfg.root_dir, bufnr, function() end)
      end
      if type(cfg.before_init) == "function" then
        local init_params = { initializationOptions = cfg.init_options }
        run(name, "before_init", cfg.before_init, init_params, resolved)
      end
      if type(cfg.get_language_id) == "function" then
        for _, ft in ipairs(cfg.filetypes or {}) do
          run(name, "get_language_id(" .. ft .. ")", cfg.get_language_id, bufnr, ft)
        end
      end
    end
    nx.test.expect(bad).to_equal({})
  end)

  nx.test.it("declares a cmd and filetypes, except where it deliberately can't", function()
    -- Without either, `nx.lsp` has nothing to dispatch on or nothing to spawn and the
    -- server simply never starts — the quietest possible failure.
    local bad = {}
    for _, name in ipairs(lspconfig.available()) do
      local cfg = load_config(name)
      if not cfg.cmd and not NO_DEFAULT_CMD[name] then
        bad[#bad + 1] = name .. ": no cmd"
      end
      if not cfg.filetypes and not ANY_FILETYPE[name] then
        bad[#bad + 1] = name .. ": no filetypes"
      end
    end
    nx.test.expect(bad).to_equal({})
  end)
end)
