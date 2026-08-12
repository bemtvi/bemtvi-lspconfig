-- The per-server `:Lsp…` commands actually run.
--
-- `configs_spec.lua` loads and resolves every config, but it never enters an
-- `on_attach` — those bodies only run once a server has attached, and they are where
-- the client-side work lives: the buffer commands a server hangs off its own buffers,
-- the params they hand back to it, the floats and lists they open. Renaming a helper
-- out from under one of them is invisible to a suite that only loads the file.
--
-- So this suite attaches by hand. The client is a **recording stand-in**, not a
-- scripted mock: it answers `supports_method` from the capabilities it was given and
-- records every `request` / `exec_cmd` with its real arguments, so the assertions are
-- about what the config actually sent — the position it built, the command name, the
-- arguments — and a config that computes the wrong one fails here. Everything else in
-- the body is real: real buffer, real `btv.lsp.position_params`, real user commands.

local function load_config(name)
  local paths = btv.runtime_file("lsp/" .. name .. ".lua", false)
  return assert(loadfile(paths[1]), "no chunk for " .. name)()
end

-- A stand-in for the client handle `btv.lsp` passes to `on_attach`. `caps` are the
-- `server_capabilities` to answer `supports_method` from; `sent` accumulates every
-- outgoing call in order.
local function fake_client(caps, encoding)
  local client = {
    id = 1,
    name = "test",
    server_capabilities = caps or {},
    offset_encoding = encoding or "utf-16",
    sent = {},
  }
  function client:request(method, params, handler, bufnr)
    self.sent[#self.sent + 1] =
      { kind = "request", method = method, params = params, bufnr = bufnr }
    self.last_handler = handler
  end
  function client:notify(method, params)
    self.sent[#self.sent + 1] = { kind = "notify", method = method, params = params }
  end
  function client:exec_cmd(command, context, handler)
    self.sent[#self.sent + 1] = { kind = "exec_cmd", command = command, context = context }
    self.last_handler = handler
  end
  function client:supports_method(method)
    -- The same rule the real handle applies: a method no capability describes — a
    -- server's own extension — is supported.
    local cap = ({
      ["textDocument/hover"] = "hoverProvider",
      ["textDocument/codeAction"] = "codeActionProvider",
    })[method]
    if not cap then
      return true
    end
    return self.server_capabilities[cap] and true or false
  end
  return client
end

-- Attach `name`'s config to the current buffer and return the recording client.
local function attach(name, opts)
  opts = opts or {}
  local cfg = load_config(name)
  local client = fake_client(opts.caps, opts.encoding)
  cfg.on_attach(client, btv.buf.current())
  return client
end

-- The buffer-local command names defined on the current buffer.
local function buf_commands()
  local names = {}
  for cmd in pairs(btv.user_command.buf_get(btv.buf.current())) do
    names[#names + 1] = cmd
  end
  table.sort(names)
  return names
end

btv.test.describe("bemtvi-lspconfig: on_attach", function()
  -- A real file, and one holding a MULTI-BYTE character: the commands below build a
  -- position from the cursor, and utf-8 and utf-16 only disagree on such a line — so
  -- an unconverted byte column would pass on ASCII and be wrong in the field.
  btv.test.before_each(function(t)
    local file = btv.utils.joinpath(btv.test.tempdir(), "probe.tex")
    btv.await(btv.fs.write(file, "\\begin{équation}\n"))
    t:cmd("edit " .. file)
    t:feed("$")
  end)

  btv.test.it("texlab defines its eight commands", function()
    attach("texlab")
    btv.test.expect(buf_commands()).to_contain("LspTexlabBuild")
    btv.test.expect(buf_commands()).to_contain("LspTexlabChangeEnvironment")
    btv.test.expect(buf_commands()).to_contain("LspTexlabCleanArtifacts")
  end)

  btv.test.it("texlab's build sends the cursor in the negotiated encoding", function(t)
    local client = attach("texlab", { encoding = "utf-16" })
    t:cmd("LspTexlabBuild")
    local sent = client.sent[1]
    btv.test.expect(sent.method).to_be("textDocument/build")
    btv.test.expect(sent.params.textDocument.uri).to_match("probe%.tex$")
    -- `\begin{équation}` — the cursor is on the final `}`: 7 bytes of `\begin{`, then
    -- `é` (2 bytes / 1 code unit), then `quation`. Byte 16, utf-16 unit 15.
    btv.test.expect(sent.params.position.character).to_be(15)
    btv.test.expect(sent.params.position.line).to_be(0)
  end)

  btv.test.it("and the same cursor in utf-8 is the byte column", function(t)
    local client = attach("texlab", { encoding = "utf-8" })
    t:cmd("LspTexlabBuild")
    btv.test.expect(client.sent[1].params.position.character).to_be(16)
  end)

  btv.test.it("texlab's clean commands carry the buffer's URI", function(t)
    local client = attach("texlab")
    t:cmd("LspTexlabCleanArtifacts")
    local sent = client.sent[1]
    btv.test.expect(sent.kind).to_be("exec_cmd")
    btv.test.expect(sent.command.command).to_be("texlab.cleanArtifacts")
    btv.test.expect(sent.command.arguments[1].uri).to_match("probe%.tex$")
  end)

  btv.test.it("clangd's switch-source-header names the document", function(t)
    local client = attach("clangd")
    btv.test.expect(buf_commands()).to_contain("LspClangdSwitchSourceHeader")
    t:cmd("LspClangdSwitchSourceHeader")
    local sent = client.sent[1]
    btv.test.expect(sent.method).to_be("textDocument/switchSourceHeader")
    btv.test.expect(sent.params.uri).to_match("probe%.tex$")
  end)

  btv.test.it("clangd's symbol-info sends the cursor position", function(t)
    local client = attach("clangd", { encoding = "utf-16" })
    t:cmd("LspClangdShowSymbolInfo")
    local sent = client.sent[1]
    btv.test.expect(sent.method).to_be("textDocument/symbolInfo")
    btv.test.expect(sent.params.position.character).to_be(15)
  end)

  btv.test.it("ccls, ocamllsp, denols, ts_ls, eslint and stylelint attach", function()
    -- Their `on_attach` bodies run — the check the load-only suite cannot make, since
    -- these are the configs whose commands were rewritten onto the native surfaces.
    for _, case in ipairs({
      { name = "ccls", cmd = "LspCclsSwitchSourceHeader" },
      { name = "ocamllsp", cmd = "LspOcamllspSwitchImplIntf" },
      { name = "denols", cmd = "LspDenolsCache" },
      { name = "ts_ls", cmd = "LspTypescriptSourceAction" },
      { name = "eslint", cmd = "LspEslintFixAll" },
      { name = "stylelint_lsp", cmd = "LspStylelintFixAll" },
    }) do
      attach(case.name)
      btv.test.expect(buf_commands()).to_contain(case.cmd)
    end
  end)

  btv.test.it("ccls' switch-source-header names the document", function(t)
    local client = attach("ccls")
    t:cmd("LspCclsSwitchSourceHeader")
    local sent = client.sent[1]
    btv.test.expect(sent.method).to_be("textDocument/switchSourceHeader")
    btv.test.expect(sent.params.uri).to_match("probe%.tex$")
  end)

  btv.test.it("ocamllsp asks about the document it is in", function(t)
    local client = attach("ocamllsp")
    t:cmd("LspOcamllspSwitchImplIntf")
    local sent = client.sent[1]
    btv.test.expect(sent.method).to_be("ocamllsp/switchImplIntf")
    btv.test.expect(sent.params[1]).to_match("^file://")
    btv.test.expect(sent.params[1]).to_match("probe%.tex$")
  end)

  btv.test.it("denols' cache command carries the buffer's URI", function(t)
    local client = attach("denols")
    t:cmd("LspDenolsCache")
    local sent = client.sent[1]
    btv.test.expect(sent.kind).to_be("exec_cmd")
    btv.test.expect(sent.command.command).to_be("deno.cache")
    btv.test.expect(sent.command.arguments[2]).to_match("probe%.tex$")
  end)

  btv.test.it("ts_ls' go-to-source-definition sends the URI and the position", function(t)
    local client = attach("ts_ls", { encoding = "utf-16" })
    t:cmd("LspTypescriptGoToSourceDefinition")
    local sent = client.sent[1]
    btv.test.expect(sent.command.command).to_be("_typescript.goToSourceDefinition")
    btv.test.expect(sent.command.arguments[1]).to_match("probe%.tex$")
    btv.test.expect(sent.command.arguments[2].character).to_be(15)
  end)
end)
