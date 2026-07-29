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

local function reload_workspace(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "rust_analyzer" })
  for _, client in ipairs(clients) do
    vim.notify("Reloading Cargo Workspace")
    ---@diagnostic disable-next-line:param-type-mismatch
    client:request("rust-analyzer/reloadWorkspace", nil, function(err)
      if err then
        error(tostring(err))
      end
      vim.notify("Cargo workspace reloaded")
    end, 0)
  end
end

local function user_sysroot_src()
  return nx.tbl.get(
    vim.lsp.config["rust_analyzer"],
    "settings",
    "rust-analyzer",
    "cargo",
    "sysrootSrc"
  )
end

local function default_sysroot_src()
  local sysroot =
    nx.tbl.get(vim.lsp.config["rust_analyzer"], "settings", "rust-analyzer", "cargo", "sysroot")
  if not sysroot then
    local rustc = os.getenv("RUSTC") or "rustc"
    local result = vim.system({ rustc, "--print", "sysroot" }, { text = true }):wait()

    local stdout = result.stdout
    if result.code == 0 and stdout then
      if string.sub(stdout, #stdout) == "\n" then
        if #stdout > 1 then
          sysroot = string.sub(stdout, 1, #stdout - 1)
        else
          sysroot = ""
        end
      else
        sysroot = stdout
      end
    end
  end

  return sysroot and util.joinpath(sysroot, "lib/rustlib/src/rust/library") or nil
end

local function is_library(fname)
  local user_home = util.normalize(vim.env.HOME)
  local cargo_home = os.getenv("CARGO_HOME") or user_home .. "/.cargo"
  local registry = cargo_home .. "/registry/src"
  local git_registry = cargo_home .. "/git/checkouts"

  local rustup_home = os.getenv("RUSTUP_HOME") or user_home .. "/.rustup"
  local toolchains = rustup_home .. "/toolchains"

  local sysroot_src = user_sysroot_src() or default_sysroot_src()

  for _, item in ipairs({ toolchains, registry, git_registry, sysroot_src }) do
    if item and util.relpath(item, fname) then
      local clients = vim.lsp.get_clients({ name = "rust_analyzer" })
      return #clients > 0 and clients[#clients].config.root_dir or nil
    end
  end
end

return {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    local reused_dir = is_library(fname)
    if reused_dir then
      on_dir(reused_dir)
      return
    end

    local cargo_crate_dir = vim.fs.root(fname, { "Cargo.toml" })
    local cargo_workspace_root

    if cargo_crate_dir == nil then
      on_dir(
        vim.fs.root(fname, { "rust-project.json" })
          or util.dirname(vim.fs.find(".git", { path = fname, upward = true })[1])
      )
      return
    end

    local cmd = {
      "cargo",
      "metadata",
      "--no-deps",
      "--format-version",
      "1",
      "--manifest-path",
      cargo_crate_dir .. "/Cargo.toml",
    }

    vim.system(cmd, { text = true }, function(output)
      if output.code == 0 then
        if output.stdout then
          local result = nx.json.decode(output.stdout)
          if result["workspace_root"] then
            cargo_workspace_root = util.normalize(result["workspace_root"])
          end
        end

        on_dir(cargo_workspace_root or cargo_crate_dir)
      else
        nx.schedule(function()
          nx.notify(
            ("[rust_analyzer] cmd failed with code %d: %s\n%s"):format(
              output.code,
              cmd,
              output.stderr
            )
          )
        end)
      end
    end)
  end,
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
      local cmd = { "cargo", unpack(r.args.cargoArgs) }
      if r.args.executableArgs and #r.args.executableArgs > 0 then
        nx.list.extend(cmd, { "--", unpack(r.args.executableArgs) })
      end

      local proc = vim.system(cmd, { cwd = r.args.cwd, env = r.args.environment })

      local result = proc:wait()

      if result.code == 0 then
        nx.notify(result.stdout, vim.log.levels.INFO)
      else
        nx.notify(result.stderr, vim.log.levels.ERROR)
      end
    end
  end,
  on_attach = function(_, bufnr)
    util.buf_command(bufnr, "LspCargoReload", function()
      reload_workspace(bufnr)
    end, { desc = "Reload current cargo workspace" })
  end,
}
