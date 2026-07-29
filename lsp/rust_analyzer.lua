---@brief
---
--- https://github.com/rust-lang/rust-analyzer
---
--- rust-analyzer (aka rls 2.0), a language server for Rust
---
---
--- See [docs](https://rust-analyzer.github.io/book/configuration.html) for extra settings. The settings can be used like this:
--- ```lua
--- nx.lsp.config('rust_analyzer', {
---   settings = {
---     ['rust-analyzer'] = {
---       diagnostics = {
---         enable = false;
---       }
---     }
---   }
--- })
--- ```
---
--- Note: do not set `init_options` for this LS config, it will be automatically populated by the contents of settings["rust-analyzer"] per
--- https://github.com/rust-lang/rust-analyzer/blob/eb5da56d839ae0a9e9f50774fa3eb78eb0964550/docs/dev/lsp-extensions.md?plain=1#L26.

local util = require("nxvim-lspconfig.util")

local function reload_workspace(bufnr)
  local clients = nx.lsp.clients({ bufnr = bufnr, name = "rust_analyzer" })
  for _, client in ipairs(clients) do
    nx.notify("Reloading Cargo Workspace")
    nx.lsp.request(client.id, "rust-analyzer/reloadWorkspace"):next(function()
      nx.notify("Cargo workspace reloaded")
    end, function(err)
      nx.notify("Cargo workspace reload failed: " .. tostring(err), nx.log.levels.ERROR)
    end)
  end
end

---The directory rust-analyzer should read the standard library's sources from, either
---as the user configured it or as the active toolchain reports it. Memoized: it is a
---property of the toolchain, and `rustc --print sysroot` is a subprocess.
local sysroot_src_cache = nil
local sysroot_src = nx.async(function()
  local cargo = nx.tbl.get(nx.lsp.get_config("rust_analyzer"), "settings", "rust-analyzer", "cargo")
    or {}
  if cargo.sysrootSrc then
    return cargo.sysrootSrc
  end
  if sysroot_src_cache then
    return sysroot_src_cache
  end
  local sysroot = cargo.sysroot
    or nx.await(util.output({ nx.env.get("RUSTC") or "rustc", "--print", "sysroot" }))
  if not sysroot then
    return nil
  end
  sysroot_src_cache = util.joinpath(sysroot, "lib/rustlib/src/rust/library")
  return sysroot_src_cache
end)

---A file under the crate registry, a git checkout or a toolchain's sources belongs to
---no project of its own — it was jumped into from one. Attach it to the rust-analyzer
---already serving that project instead of starting a second one rooted in `~/.cargo`.
local is_library = nx.async(function(fname)
  local user_home = util.home()
  local cargo_home = nx.env.get("CARGO_HOME") or util.joinpath(user_home, ".cargo")
  local rustup_home = nx.env.get("RUSTUP_HOME") or util.joinpath(user_home, ".rustup")

  local roots = {
    util.joinpath(rustup_home, "toolchains"),
    util.joinpath(cargo_home, "registry/src"),
    util.joinpath(cargo_home, "git/checkouts"),
    nx.await(sysroot_src()),
  }
  for _, item in ipairs(roots) do
    if item and util.relpath(item, fname) then
      local clients = nx.lsp.clients({ name = "rust_analyzer" })
      return #clients > 0 and clients[#clients].config.root_dir or nil
    end
  end
end)

return {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_dir = nx.async(function(bufnr)
    local fname = util.bufname(bufnr)
    local reused_dir = nx.await(is_library(fname))
    if reused_dir then
      return reused_dir
    end

    local cargo_crate_dir = nx.await(util.root_of_path(fname, { "Cargo.toml" }))
    if cargo_crate_dir == nil then
      return nx.await(util.root_of_path(fname, { { "rust-project.json" }, { ".git" } }))
    end

    -- A crate inside a workspace must attach at the WORKSPACE, or rust-analyzer
    -- re-analyzes the same tree once per member. Only cargo knows where that is.
    local cmd = {
      "cargo",
      "metadata",
      "--no-deps",
      "--format-version",
      "1",
      "--manifest-path",
      util.joinpath(cargo_crate_dir, "Cargo.toml"),
    }
    local output = nx.await(util.system(cmd))
    if output.code ~= 0 then
      nx.notify(
        ("[rust_analyzer] cmd failed with code %d: %s\n%s"):format(
          output.code,
          nx.inspect(cmd),
          output.stderr
        ),
        nx.log.levels.WARN
      )
      return cargo_crate_dir
    end

    local ok, result = pcall(nx.json.decode, output.stdout or "")
    local workspace_root = ok and type(result) == "table" and result["workspace_root"] or nil
    return workspace_root and util.normalize(workspace_root) or cargo_crate_dir
  end),
  capabilities = {
    experimental = {
      serverStatusNotification = true,
      commands = {
        commands = {
          "rust-analyzer.showReferences",
          "rust-analyzer.runSingle",
          "rust-analyzer.debugSingle",
        },
      },
    },
  },
  settings = {
    ["rust-analyzer"] = {
      lens = {
        debug = { enable = true },
        enable = true,
        implementations = { enable = true },
        references = {
          adt = { enable = true },
          enumVariant = { enable = true },
          method = { enable = true },
          trait = { enable = true },
        },
        run = { enable = true },
        updateTest = { enable = true },
      },
    },
  },
  before_init = function(init_params, config)
    -- See https://github.com/rust-lang/rust-analyzer/blob/eb5da56d839ae0a9e9f50774fa3eb78eb0964550/docs/dev/lsp-extensions.md?plain=1#L26
    if config.settings and config.settings["rust-analyzer"] then
      init_params.initializationOptions = config.settings["rust-analyzer"]
    end
    ---@param command table{ title: string, command: string, arguments: any[] }
    nx.lsp.commands["rust-analyzer.runSingle"] = function(command)
      local r = command.arguments[1]
      local cmd = nx.list.extend({ "cargo" }, r.args.cargoArgs)
      if r.args.executableArgs and #r.args.executableArgs > 0 then
        nx.list.extend(nx.list.extend(cmd, { "--" }), r.args.executableArgs)
      end

      -- Upstream `:wait()`s on the test run here, freezing the editor for as long as
      -- `cargo test` takes. The result is only ever reported, so nothing needs the
      -- value in hand: report it when it arrives.
      util.system(cmd, { cwd = r.args.cwd, env = r.args.environment }):next(function(result)
        if result.code == 0 then
          nx.notify(result.stdout, nx.log.levels.INFO)
        else
          nx.notify(result.stderr, nx.log.levels.ERROR)
        end
      end)
    end
  end,
  on_attach = function(_, bufnr)
    util.buf_command(bufnr, "LspCargoReload", function()
      reload_workspace(bufnr)
    end, { desc = "Reload current cargo workspace" })
  end,
}
