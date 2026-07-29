---@brief
---
--- https://github.com/dotnet/roslyn
--
-- The server can be installed as a dotnet tool (see https://github.com/dotnet/roslyn/blob/main/src/LanguageServer/Microsoft.CodeAnalysis.LanguageServer/README.md).
-- This command will install the server in ~/.dotnet/tools:
-- ```bash
-- dotnet tool install --global roslyn-language-server --prerelease
-- ```
-- Alternatively, compile from source or download as nuget package.
-- Go to `https://dev.azure.com/azure-public/vside/_artifacts/feed/vs-impl/NuGet/Microsoft.CodeAnalysis.LanguageServer.<platform>/overview`
-- replace `<platform>` with one of the following `linux-x64`, `osx-x64`, `win-x64`, `neutral` (for more info on the download location see https://github.com/dotnet/roslyn/issues/71474#issuecomment-2177303207).
-- Download and extract it (nuget's are zip files).
-- - if you chose `neutral` nuget version, then you have to change the `cmd` like so:
--   ```lua
--   cmd = {
--     'dotnet',
--     '<my_folder>/Microsoft.CodeAnalysis.LanguageServer.dll',
--     '--stdio',
--   },
--   ```
--   where `<my_folder>` has to be the folder you extracted the nuget package to.
-- - for all other platforms put the extracted folder on `$PATH` (nxvim resolves the
--   server through it; `nx.env.get('PATH')` is what the editor sees)

local util = require("nxvim-lspconfig.util")

local group = nx.augroup.create("lspconfig.roslyn_ls", { clear = true })

-- Buffers whose refresh autocmd is already armed. `on_attach` runs once per (client,
-- buffer), and a buffer served by two roslyn instances would otherwise pull its
-- diagnostics twice per save.
local armed = {}

---@param client nx.lsp.Client
---@param target string
local function on_init_sln(client, target)
  nx.notify("Initializing: " .. target, nx.log.levels.TRACE, { title = "roslyn_ls" })
  ---@diagnostic disable-next-line: param-type-mismatch
  client:notify("solution/open", {
    solution = util.uri_from_path(target),
  })
end

---@param client nx.lsp.Client
---@param project_files string[]
local function on_init_project(client, project_files)
  nx.notify("Initializing: projects", nx.log.levels.TRACE, { title = "roslyn_ls" })
  ---@diagnostic disable-next-line: param-type-mismatch
  client:notify("project/open", {
    projects = nx.tbl.map(function(file)
      return util.uri_from_path(file)
    end, project_files),
  })
end

---Roslyn only recomputes a document's diagnostics when asked, so a pull is what makes
---them refresh after a save or after project initialization finishes.
---
---Upstream enumerates the server's dynamically-registered diagnostic identifiers and
---pulls once per identifier per attached buffer. nxvim does not model dynamic
---capability registration, so there is no identifier list to enumerate; the pull goes
---out without one, which is the request the server answers with its default set.
---@param client table
local function refresh_diagnostics(client)
  for _, buf in ipairs(nx.buf.list()) do
    local attached = false
    for _, c in ipairs(nx.lsp.clients({ bufnr = buf, name = client.name })) do
      attached = attached or c.id == client.id
    end
    if attached and nx.buf.is_loaded(buf) then
      client:request("textDocument/diagnostic", {
        textDocument = { uri = util.uri_from_buf(buf) },
      })
    end
  end
end

local function roslyn_handlers()
  return {
    ["workspace/projectInitializationComplete"] = function(_, _, ctx)
      nx.notify(
        "Roslyn project initialization complete",
        nx.log.levels.INFO,
        { title = "roslyn_ls" }
      )
      local client = assert(nx.lsp.client_by_id(ctx.client_id))
      refresh_diagnostics(client)
      return nx.json.null
    end,
    ["razor/provideDynamicFileInfo"] = function(_, _, _)
      nx.notify(
        "Razor is not supported.\nPlease use https://github.com/seblyng/roslyn.nvim",
        nx.log.levels.WARN,
        { title = "roslyn_ls" }
      )
      return nx.json.null
    end,
  }
end

---Is this buffer decompiled source rather than a file in the user's project? Roslyn
---writes those under `<tmp>/MetadataAsSource/...` when you jump into a library type,
---and they must NOT trigger a solution search of their own.
---
---The path shape is the whole test here: upstream additionally confirms the directory
---exists under the temp dir, which is a filesystem read inside a `root_dir` — and
---answers the same question, since only Roslyn creates that path.
---@param bufname string
---@return boolean
local function is_decompiled(bufname)
  return bufname:find("[/\\]MetadataAsSource[/\\]") ~= nil
end

---@param client nx.lsp.Client
---@param action table
local function apply_action(client, action)
  if action.edit then
    nx.lsp.apply_workspace_edit(action.edit, { encoding = client.offset_encoding })
  end
  if action.command then
    client:exec_cmd(action.command)
  end
end

---@param client nx.lsp.Client
---@param command table
---@param bufnr integer
local function handle_fix_all_action(client, command, bufnr)
  local arg = command.arguments and command.arguments[1]
  if type(arg) ~= "table" then
    nx.notify("roslyn_ls: invalid fixAllCodeAction arguments", nx.log.levels.ERROR)
    return
  end

  local flavors = arg.FixAllFlavors
  if type(flavors) ~= "table" or nx.tbl.is_empty(flavors) then
    nx.notify("roslyn_ls: fixAllCodeAction has no FixAllFlavors", nx.log.levels.WARN)
    return
  end

  nx.ui.select(flavors, {
    prompt = "Fix All Scope:",
  }, function(chosen_scope)
    if not chosen_scope then
      return
    end

    client:request("codeAction/resolveFixAll", {
      title = command.title,
      data = arg,
      scope = chosen_scope,
    }, function(err, resolved)
      if err then
        nx.notify(
          "roslyn_ls: fixAllCodeAction resolve error: " .. (err.message or tostring(err)),
          nx.log.levels.ERROR
        )
        return
      end
      if resolved then
        apply_action(client, resolved)
      end
    end, bufnr)
  end)
end

return {
  name = "roslyn_ls",
  -- Installed either as the nuget's own binary or as the `roslyn-language-server` dotnet
  -- tool, so which one is present decides the argv.
  cmd = nx.async(function()
    return {
      nx.await(util.which("Microsoft.CodeAnalysis.LanguageServer"))
          and "Microsoft.CodeAnalysis.LanguageServer"
        or "roslyn-language-server",
      "--stdio",
    }
  end),

  -- Fixes LSP navigation in decompiled files for systems with symlinked TMPDIR (macOS):
  -- the server writes the decompiled file under the resolved path and reports it under
  -- the symlinked one, so the editor opens a path the server has never heard of.
  before_init = nx.async(function(_init_params, config)
    local tmpdir = nx.env.get("TMPDIR")
    if tmpdir and tmpdir ~= "" then
      local real = nx.await(nx.fs.realpath(tmpdir):catch(function()
        return tmpdir
      end))
      config.cmd_env = nx.tbl.extend("force", config.cmd_env or {}, { TMPDIR = real })
    end
  end),

  filetypes = { "cs" },
  handlers = roslyn_handlers(),

  commands = {
    ["roslyn.client.completionComplexEdit"] = function(command, ctx)
      local client = assert(nx.lsp.client_by_id(ctx.client_id))
      local args = command.arguments or {}
      local uri, edit = args[1], args[2]

      ---@diagnostic disable: undefined-field
      if uri and edit and edit.newText and edit.range then
        local workspace_edit = {
          changes = {
            [uri.uri] = {
              {
                range = edit.range,
                newText = edit.newText,
              },
            },
          },
        }
        nx.lsp.apply_workspace_edit(workspace_edit, { encoding = client.offset_encoding })
      ---@diagnostic enable: undefined-field
      else
        nx.notify(
          "roslyn_ls: completionComplexEdit args not understood: " .. nx.inspect(args),
          nx.log.levels.WARN
        )
      end
    end,

    ["roslyn.client.nestedCodeAction"] = function(command, ctx)
      local client = assert(nx.lsp.client_by_id(ctx.client_id))
      local arg = command.arguments and command.arguments[1]

      if type(arg) ~= "table" then
        nx.notify("roslyn_ls: invalid nestedCodeAction arguments", nx.log.levels.ERROR)
        return
      end

      local function handle(action)
        if not action then
          return
        end

        if action.data and not action.edit and not action.command then
          client:request("codeAction/resolve", action, function(err, resolved)
            if err then
              nx.notify(err.message or tostring(err), nx.log.levels.ERROR)
              return
            end
            if resolved then
              handle(resolved)
            end
          end, ctx.bufnr)
          return
        end

        local nested = nx.list.is_list(action) and action or action.NestedCodeActions
        if type(nested) ~= "table" or nx.tbl.is_empty(nested) then
          apply_action(client, action)
          return
        end

        if #nested == 1 then
          handle(nested[1])
          return
        end

        nx.ui.select(nested, {
          prompt = action.title or "Select code action",
          format_item = function(item)
            return item.title or (item.command and item.command.title) or "Unnamed action"
          end,
        }, function(choice)
          if choice then
            handle(choice)
          end
        end)
      end

      handle(arg)
    end,

    ["roslyn.client.fixAllCodeAction"] = function(command, ctx)
      local client = assert(nx.lsp.client_by_id(ctx.client_id))
      handle_fix_all_action(client, command, ctx.bufnr)
    end,
  },

  root_dir = util.root_dir(function(bufnr, cb)
    local bufname = util.bufname(bufnr)
    -- Decompiled code (example: "/tmp/MetadataAsSource/f2bfba/DecompilationMetadataAsSourceFileProvider/d5782a/Console.cs")
    -- doesn't belong to any solution of its own — it was jumped into from one. Serve it
    -- from the server already running, and decline the buffer when there is none.
    if is_decompiled(bufname) then
      local client = nx.lsp.clients({ name = "roslyn_ls" })[1]
      if client then
        cb(client.config.root_dir)
      end
      return
    end

    -- A solution roots the server ahead of a bare project, wherever each is found:
    -- rooting at a nested .csproj inside a solution loses the cross-project references.
    local root_dir = nx.await(util.root_pattern("*.sln", "*.slnx", "*.csproj")(bufname))
    if root_dir then
      cb(root_dir)
    end
  end),
  on_init = {
    nx.async(function(client)
      local root_dir = client.config.root_dir
      local entries = nx.await(nx.fs.readdir(root_dir):catch(function()
        return {}
      end))

      -- try load first solution we find
      local projects = {}
      for _, entry in ipairs(entries) do
        if entry.type == "file" then
          if nx.str.endswith(entry.name, ".sln") or nx.str.endswith(entry.name, ".slnx") then
            return on_init_sln(client, util.joinpath(root_dir, entry.name))
          end
          if nx.str.endswith(entry.name, ".csproj") then
            projects[#projects + 1] = util.joinpath(root_dir, entry.name)
          end
        end
      end

      -- if no solution is found load the projects. Upstream sends one `project/open`
      -- per .csproj; the notification takes a LIST, and a second one replaces the first
      -- rather than adding to it, so a multi-project directory loaded only its last.
      if #projects > 0 then
        on_init_project(client, projects)
      end
    end),
  },

  on_attach = function(client, bufnr)
    -- avoid duplicate autocmds for same buffer
    if armed[bufnr] then
      return
    end
    armed[bufnr] = true

    nx.autocmd.create({ "BufWritePost", "InsertLeave" }, {
      group = group,
      buffer = bufnr,
      callback = function()
        refresh_diagnostics(client)
      end,
      desc = "roslyn_ls: refresh diagnostics",
    })
  end,

  capabilities = {
    -- HACK: Doesn't show any diagnostics if we do not set this to true
    textDocument = {
      diagnostic = {
        dynamicRegistration = true,
      },
    },
  },
  settings = {
    ["csharp|background_analysis"] = {
      dotnet_analyzer_diagnostics_scope = "fullSolution",
      dotnet_compiler_diagnostics_scope = "fullSolution",
    },
    ["csharp|inlay_hints"] = {
      csharp_enable_inlay_hints_for_implicit_object_creation = true,
      csharp_enable_inlay_hints_for_implicit_variable_types = true,
      csharp_enable_inlay_hints_for_lambda_parameter_types = true,
      csharp_enable_inlay_hints_for_types = true,
      dotnet_enable_inlay_hints_for_indexer_parameters = true,
      dotnet_enable_inlay_hints_for_literal_parameters = true,
      dotnet_enable_inlay_hints_for_object_creation_parameters = true,
      dotnet_enable_inlay_hints_for_other_parameters = true,
      dotnet_enable_inlay_hints_for_parameters = true,
      dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
    },
    ["csharp|symbol_search"] = {
      dotnet_search_reference_assemblies = true,
    },
    ["csharp|completion"] = {
      dotnet_show_name_completion_suggestions = true,
      dotnet_show_completion_items_from_unimported_namespaces = true,
      dotnet_provide_regex_completions = true,
    },
    ["csharp|code_lens"] = {
      dotnet_enable_references_code_lens = true,
    },
  },
}
