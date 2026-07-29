---@brief
---
--- https://github.com/julia-vscode/julia-vscode
---
--- LanguageServer.jl, SymbolServer.jl and StaticLint.jl can be installed with `julia` and `Pkg`:
--- ```sh
--- julia --project=~/.julia/environments/nvim-lspconfig -e 'using Pkg; Pkg.add("LanguageServer"); Pkg.add("SymbolServer"); Pkg.add("StaticLint")'
--- ```
--- where `~/.julia/environments/nvim-lspconfig` is the location where
--- the default configuration expects LanguageServer.jl, SymbolServer.jl and StaticLint.jl to be installed.
---
--- To update an existing install, use the following command:
--- ```sh
--- julia --project=~/.julia/environments/nvim-lspconfig -e 'using Pkg; Pkg.update()'
--- ```
---
--- Note: In order to have LanguageServer.jl pick up installed packages or dependencies in a
--- Julia project, you must make sure that the project is instantiated:
--- ```sh
--- julia --project=/path/to/my/project -e 'using Pkg; Pkg.instantiate()'
--- ```
---
--- To activate a Julia environment, use the `:LspJuliaActivateEnv` command. A prompt will ask you to select a Julia
--- environment from the list of environments found in the current working directory and the `environments/` folder of
--- `$JULIA_DEPOT_PATH` entries. You can also provide a path to a Julia environment directly.
--- Example: `:LspJuliaActivateEnv /path/to/my/project`.
---
--- Note: The julia programming language searches for global environments within the `environments/`
--- folder of `$JULIA_DEPOT_PATH` entries. By default this simply `~/.julia/environments`

local util = require("nxvim-lspconfig.util")

local root_files = { "Project.toml", "JuliaProject.toml" }

local activate_env = nx.async(function(args)
  local bufnr = nx.buf.current()
  local julials_clients = nx.lsp.clients({ bufnr = bufnr, name = "julials" })
  assert(
    #julials_clients > 0,
    "method julia/activateenvironment is not supported by any servers active on the current buffer"
  )
  local function _activate_env(environment)
    if environment then
      for _, julials_client in ipairs(julials_clients) do
        ---@diagnostic disable-next-line: param-type-mismatch
        julials_client:notify("julia/activateenvironment", { envPath = environment })
      end
      nx.notify("Julia environment activated: \n`" .. environment .. "`", nx.log.levels.INFO)
    end
  end
  local path = args.args
  if path ~= nil and #path > 0 then
    path = util.normalize(nx.fname.modify(nx.utils.expanduser(path), ":p"))
    local found_env = false
    for _, project_file in ipairs(root_files) do
      if nx.await(util.exists(util.joinpath(path, project_file))) then
        found_env = true
        break
      end
    end
    if not found_env then
      nx.notify("Path is not a julia environment: \n`" .. path .. "`", nx.log.levels.WARN)
      return
    end
    return _activate_env(path)
  end

  -- Every environment the user could switch to: the project ones above this buffer,
  -- plus the global ones julia keeps in `environments/` under each depot.
  local sep = nx.utils.is_windows() and ";" or ":"
  local depot_paths = nx.env.get("JULIA_DEPOT_PATH")
      and nx.str.split(nx.env.get("JULIA_DEPOT_PATH"), sep)
    or { nx.utils.expanduser("~/.julia") }

  local environments = {}
  for _, found in ipairs(nx.await(util.find_upward_all(util.bufname(nx.buf.current()), root_files))) do
    environments[#environments + 1] = util.dirname(found)
  end
  for _, depot_path in ipairs(depot_paths) do
    local depot_env = util.joinpath(util.normalize(depot_path), "environments")
    for _, entry in
      ipairs(nx.await(nx.fs.readdir(depot_env):catch(function()
        return {}
      end)))
    do
      local dir = util.joinpath(depot_env, entry.name)
      for _, project_file in ipairs(root_files) do
        if nx.await(util.exists(util.joinpath(dir, project_file))) then
          environments[#environments + 1] = dir
          break
        end
      end
    end
  end
  nx.ui.select(environments, { prompt = "Select a Julia environment" }, _activate_env)
end)

local cmd = {
  "julia",
  "--startup-file=no",
  "--history-file=no",
  "-e",
  [[
    # Load LanguageServer.jl: attempt to load from ~/.julia/environments/nvim-lspconfig
    # with the regular load path as a fallback
    ls_install_path = joinpath(
        get(DEPOT_PATH, 1, joinpath(homedir(), ".julia")),
        "environments", "nvim-lspconfig"
    )
    pushfirst!(LOAD_PATH, ls_install_path)
    using LanguageServer, SymbolServer, StaticLint
    popfirst!(LOAD_PATH)
    depot_path = get(ENV, "JULIA_DEPOT_PATH", "")
    project_path = let
        dirname(something(
            ## 1. Finds an explicitly set project (JULIA_PROJECT)
            Base.load_path_expand((
                p = get(ENV, "JULIA_PROJECT", nothing);
                p === nothing ? nothing : isempty(p) ? nothing : p
            )),
            ## 2. Look for a Project.toml file in the current working directory,
            ##    or parent directories, with $HOME as an upper boundary
            Base.current_project(),
            ## 3. First entry in the load path
            get(Base.load_path(), 1, nothing),
            ## 4. Fallback to default global environment,
            ##    this is more or less unreachable
            Base.load_path_expand("@v#.#"),
        ))
    end
    @info "Running language server" VERSION pwd() project_path depot_path
    server = LanguageServer.LanguageServerInstance(stdin, stdout, project_path, depot_path)
    server.runlinter = true
    run(server)
  ]],
}

return {
  cmd = cmd,
  filetypes = { "julia" },
  root_markers = root_files,
  on_attach = function(_, bufnr)
    util.buf_command(bufnr, "LspJuliaActivateEnv", activate_env, {
      desc = "Activate a Julia environment",
      nargs = "?",
      complete = "file",
    })
  end,
}
