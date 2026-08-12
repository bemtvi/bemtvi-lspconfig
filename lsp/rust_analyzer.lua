---@brief
---
--- https://github.com/rust-lang/rust-analyzer
---
--- rust-analyzer (aka rls 2.0), a language server for Rust
---
---
--- See [docs](https://rust-analyzer.github.io/book/configuration.html) for extra settings. The settings can be used like this:
--- ```lua
--- btv.lsp.config('rust_analyzer', {
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

local util = require("bemtvi-lspconfig.util")

local function reload_workspace(bufnr)
  local clients = btv.lsp.clients({ bufnr = bufnr, name = "rust_analyzer" })
  for _, client in ipairs(clients) do
    btv.notify("Reloading Cargo Workspace")
    btv.lsp.request(client.id, "rust-analyzer/reloadWorkspace"):next(function()
      btv.notify("Cargo workspace reloaded")
    end, function(err)
      btv.notify("Cargo workspace reload failed: " .. tostring(err), btv.log.levels.ERROR)
    end)
  end
end

---The directory rust-analyzer should read the standard library's sources from, either
---as the user configured it or as the active toolchain reports it. Memoized: it is a
---property of the toolchain, and `rustc --print sysroot` is a subprocess.
local sysroot_src_cache = nil
local sysroot_src = btv.async(function()
  local cargo = btv.tbl.get(btv.lsp.get_config("rust_analyzer"), "settings", "rust-analyzer", "cargo")
    or {}
  if cargo.sysrootSrc then
    return cargo.sysrootSrc
  end
  if sysroot_src_cache then
    return sysroot_src_cache
  end
  local sysroot = cargo.sysroot
    or btv.await(util.output({ btv.env.get("RUSTC") or "rustc", "--print", "sysroot" }))
  if not sysroot then
    return nil
  end
  sysroot_src_cache = util.joinpath(sysroot, "lib/rustlib/src/rust/library")
  return sysroot_src_cache
end)

---A file under the crate registry, a git checkout or a toolchain's sources belongs to
---no project of its own — it was jumped into from one. Attach it to the rust-analyzer
---already serving that project instead of starting a second one rooted in `~/.cargo`.
local is_library = btv.async(function(fname)
  local user_home = util.home()
  local cargo_home = btv.env.get("CARGO_HOME") or util.joinpath(user_home, ".cargo")
  local rustup_home = btv.env.get("RUSTUP_HOME") or util.joinpath(user_home, ".rustup")

  local roots = {
    util.joinpath(rustup_home, "toolchains"),
    util.joinpath(cargo_home, "registry/src"),
    util.joinpath(cargo_home, "git/checkouts"),
    btv.await(sysroot_src()),
  }
  for _, item in ipairs(roots) do
    if item and util.relpath(item, fname) then
      local clients = btv.lsp.clients({ name = "rust_analyzer" })
      return #clients > 0 and clients[#clients].config.root_dir or nil
    end
  end
end)

return {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_dir = btv.async(function(bufnr)
    local fname = util.bufname(bufnr)
    local reused_dir = btv.await(is_library(fname))
    if reused_dir then
      return reused_dir
    end

    local cargo_crate_dir = btv.await(util.root_of_path(fname, { "Cargo.toml" }))
    if cargo_crate_dir == nil then
      return btv.await(util.root_of_path(fname, { { "rust-project.json" }, { ".git" } }))
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
    local output = btv.await(util.system(cmd))
    if output.code ~= 0 then
      btv.notify(
        ("[rust_analyzer] cmd failed with code %d: %s\n%s"):format(
          output.code,
          btv.inspect(cmd),
          output.stderr
        ),
        btv.log.levels.WARN
      )
      return cargo_crate_dir
    end

    local ok, result = pcall(btv.json.decode, output.stdout or "")
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
    btv.lsp.commands["rust-analyzer.runSingle"] = function(command)
      local r = command.arguments[1]
      local cmd = btv.list.extend({ "cargo" }, r.args.cargoArgs)
      if r.args.executableArgs and #r.args.executableArgs > 0 then
        btv.list.extend(btv.list.extend(cmd, { "--" }), r.args.executableArgs)
      end

      -- Upstream `:wait()`s on the test run here, freezing the editor for as long as
      -- `cargo test` takes. The result is only ever reported, so nothing needs the
      -- value in hand: report it when it arrives.
      util.system(cmd, { cwd = r.args.cwd, env = r.args.environment }):next(function(result)
        if result.code == 0 then
          btv.notify(result.stdout, btv.log.levels.INFO)
        else
          btv.notify(result.stderr, btv.log.levels.ERROR)
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
