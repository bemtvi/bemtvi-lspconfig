-- The example's own spec: `bemtvi --test-plugin examples`.
--
-- It checks everything init.lua sets up that does not need a running language
-- server: the plugin loads from the checkout, the override merges over the bundled
-- lua_ls preset, setup() enables lua_ls and composes the global on_attach, and that
-- hook installs the keymaps the steps tell you to press. What the server then
-- answers (hover, rename, diagnostics) needs a real lua-language-server, so it is
-- verified by running the example, not here. The spec never opens a Lua buffer,
-- so lua_ls is never spawned. For the same reason step 7's `:LspStop` is checked
-- with nothing running: the command is there and says so.

local DIR = debug.getinfo(1, "S").source:match("^@(.*)/test/[^/]+$")

-- Record what init.lua enables. There is no public "is this server enabled?" read,
-- so watch the call instead of peeking at btv.lsp's private registry.
local enabled = {}
local real_enable = btv.lsp.enable
btv.lsp.enable = function(names, ...)
  for _, n in ipairs(type(names) == "table" and names or { names }) do
    enabled[n] = true
  end
  return real_enable(names, ...)
end
dofile(DIR .. "/init.lua")
btv.lsp.enable = real_enable

-- The buffer-local mappings on the current buffer for `mode`, keyed by lhs.
local function buf_maps(mode)
  local out = {}
  for _, m in ipairs(btv.keymap.buf_get(btv.buf.current(), mode)) do
    out[m.lhs] = m
  end
  return out
end

btv.test.describe("examples: bemtvi-lspconfig", function()
  btv.test.it("section 1: the plugin loads from the checkout", function()
    btv.test.expect(package.loaded["bemtvi-lspconfig"]).never.to_be(nil)
    btv.test.expect(require("bemtvi-lspconfig").is_available("lua_ls")).to_be(true)
  end)

  btv.test.it("section 2: the override merges over the bundled lua_ls", function()
    local cfg = btv.lsp.get_config("lua_ls")
    btv.test.expect(cfg.settings.Lua.runtime.version).to_be("Lua 5.4")
    btv.test.expect(cfg.settings.Lua.diagnostics.globals).to_equal({ "btv" })
    -- What the example did not name still comes from lsp/lua_ls.lua.
    btv.test.expect(cfg.cmd).to_equal({ "lua-language-server" })
    btv.test.expect(cfg.settings.Lua.codeLens.enable).to_be(true)
    btv.test.expect(cfg.filetypes).to_contain("lua")
  end)

  btv.test.it("section 3: setup() enabled lua_ls for Lua buffers", function()
    btv.test.expect(enabled.lua_ls).to_be(true)
    btv.test.expect(require("bemtvi-lspconfig").for_filetype("lua")).to_contain("lua_ls")
  end)

  btv.test.it("section 3: on attach, the keymaps land and on_attach notifies", function(t)
    t:cmd("enew!")
    local notified
    local real_notify = btv.notify
    btv.notify = function(msg)
      notified = msg
    end
    local ok, err = pcall(btv.lsp.get_config("*").on_attach, {
      id = 1,
      name = "lua_ls",
      server_capabilities = {},
      offset_encoding = "utf-16",
    }, btv.buf.current())
    btv.notify = real_notify
    btv.test.expect(err).to_be(nil)
    btv.test.expect(ok).to_be(true)
    btv.test.expect(notified).to_be(("lua_ls attached to buffer %d"):format(btv.buf.current()))
    local n = buf_maps("n")
    for _, lhs in ipairs({ "grn", "grr", "gO", "<C-]>", " lh" }) do
      btv.test.expect(n[lhs] ~= nil).to_be(true)
    end
  end)

  btv.test.it("section 7: the :Lsp* commands are there", function(t)
    local cmds = btv.user_command.get()
    for _, name in ipairs({ "LspStart", "LspStop", "LspRestart", "LspLog" }) do
      btv.test.expect(cmds[name] ~= nil).to_be(true)
    end
    t:cmd("LspStop")
    btv.test.expect(t:message()).to_contain("no language server is running")
  end)
end)
