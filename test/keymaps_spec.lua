-- The extended keymap set `setup()` installs on attach.
--
-- `on_attach_spec.lua` drives the per-server `on_attach` bodies off the bundled
-- configs; this drives the GLOBAL one `setup()` composes, which is what installs the
-- keymaps. The assertions read the mappings back out of the registry
-- (`nx.keymap.buf_get`) rather than pressing the keys, because what is under test is
-- the registration — that every entry lands on the buffer, in the right mode, at the
-- overridable rung. Whether a bound `nx.lsp.*` verb then works is the core's business
-- and the core's tests.

local lspconfig = require("nxvim-lspconfig")

-- The global `on_attach` `setup(opts)` registered, pulled back out of the `"*"` layer
-- — the same function `nx.lsp` would call when a server attaches.
local function global_on_attach(opts)
  lspconfig.setup(opts or {})
  return nx.lsp.get_config("*").on_attach
end

-- The buffer-local mappings on the current buffer for `mode`, as a lhs -> entry map.
local function buf_maps(mode)
  local out = {}
  for _, m in ipairs(nx.keymap.buf_get(nx.buf.current(), mode)) do
    out[m.lhs] = m
  end
  return out
end

-- A stand-in for the client handle `on_attach` is given. The keymap half of the hook
-- never touches it; the inlay-hint half reads `server_capabilities`.
local function fake_client()
  return { id = 1, name = "test", server_capabilities = {}, offset_encoding = "utf-16" }
end

local seq = 0

nx.test.describe("nxvim-lspconfig: keymaps", function()
  nx.test.before_each(function(t)
    -- `setup()` is ADDITIVE — it deep-merges into the `"*"` layer, and a merge cannot
    -- erase a key — so a previous test's `on_attach` would still be the one
    -- `get_config` hands back. Clear the layer so each test starts from "setup has
    -- never run", which is also the only state `keymaps = false` is meaningful in.
    nx.lsp._config["*"] = nil
    -- A fresh buffer per test too, so buffer-local maps never leak between them.
    seq = seq + 1
    local file = nx.utils.joinpath(nx.test.tempdir(), "probe" .. seq .. ".lua")
    nx.await(nx.fs.write(file, "local x = 1\n"))
    t:cmd("edit " .. file)
  end)

  nx.test.it("installs the extended set buffer-local on attach", function()
    global_on_attach()(fake_client(), nx.buf.current())
    local n = buf_maps("n")
    for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt", "gO" }) do
      nx.test.expect(n[lhs] ~= nil).to_be(true)
    end
  end)

  -- `<C-]>` is the tag jump: with a language server standing in for a tags file, it
  -- is the spelling a vim user reaches for before learning `gd`. nxvim's core set
  -- deliberately stops at `gd`, so if this plugin does not bind it, nothing does.
  nx.test.it("binds <C-]> to go-to-definition in normal mode", function()
    global_on_attach()(fake_client(), nx.buf.current())
    local map = buf_maps("n")["<C-]>"]
    nx.test.expect(map ~= nil).to_be(true)
    nx.test.expect(map.desc).to_be("LSP go to definition")
    -- The overridable rung, like the rest: your own `<C-]>` wins.
    nx.test.expect(map.buffer).to_be(nx.buf.current())
  end)

  -- neovim's `i_CTRL-S`, in insert AND select mode, beside nxvim's own `<C-k>`.
  nx.test.it("binds <C-s> to signature help in insert and select mode", function()
    global_on_attach()(fake_client(), nx.buf.current())
    nx.test.expect(buf_maps("i")["<C-s>"] ~= nil).to_be(true)
    nx.test.expect(buf_maps("s")["<C-s>"] ~= nil).to_be(true)
    nx.test.expect(buf_maps("i")["<C-s>"].desc).to_be("LSP signature help")
  end)

  -- The opt-out has to cover the new entries too, or `keymaps = false` quietly stops
  -- meaning "no keymaps from this plugin".
  nx.test.it("keymaps = false installs none of them", function()
    local hook = global_on_attach({ keymaps = false })
    if hook then
      hook(fake_client(), nx.buf.current())
    end
    local n = buf_maps("n")
    nx.test.expect(n["grn"] == nil).to_be(true)
    nx.test.expect(n["<C-]>"] == nil).to_be(true)
    nx.test.expect(buf_maps("i")["<C-s>"] == nil).to_be(true)
    nx.test.expect(buf_maps("s")["<C-s>"] == nil).to_be(true)
  end)
end)
