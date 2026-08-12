---@brief
---
--- https://github.com/latex-lsp/texlab
---
--- A completion engine built from scratch for (La)TeX.
---
--- See https://github.com/latex-lsp/texlab/wiki/Configuration for configuration options.
---
--- There are some non standard commands supported, namely:
--- `LspTexlabBuild`, `LspTexlabForward`, `LspTexlabCancelBuild`,
--- `LspTexlabDependencyGraph`, `LspTexlabCleanArtifacts`,
--- `LspTexlabCleanAuxiliary`, `LspTexlabFindEnvironments`,
--- and `LspTexlabChangeEnvironment`.

local util = require("bemtvi-lspconfig.util")

local function buf_build(client, bufnr)
  local params = btv.lsp.position_params({ encoding = client.offset_encoding })
  client:request("textDocument/build", params, function(err, result)
    if err then
      error(tostring(err))
    end
    local texlab_build_status = {
      [0] = "Success",
      [1] = "Error",
      [2] = "Failure",
      [3] = "Cancelled",
    }
    btv.notify("Build " .. texlab_build_status[result.status], btv.log.levels.INFO)
  end, bufnr)
end

local function buf_search(client, bufnr)
  local params = btv.lsp.position_params({ encoding = client.offset_encoding })
  client:request("textDocument/forwardSearch", params, function(err, result)
    if err then
      error(tostring(err))
    end
    local texlab_forward_status = {
      [0] = "Success",
      [1] = "Error",
      [2] = "Failure",
      [3] = "Unconfigured",
    }
    btv.notify("Search " .. texlab_forward_status[result.status], btv.log.levels.INFO)
  end, bufnr)
end

local function buf_cancel_build(client, bufnr)
  return client:exec_cmd({
    title = "cancel",
    command = "texlab.cancelBuild",
  }, { bufnr = bufnr })
end

local function dependency_graph(client)
  client:exec_cmd({ command = "texlab.showDependencyGraph" }, { bufnr = 0 }, function(err, result)
    if err then
      return btv.notify(err.code .. ": " .. err.message, btv.log.levels.ERROR)
    end
    btv.notify("The dependency graph has been generated:\n" .. result, btv.log.levels.INFO)
  end)
end

local function command_factory(cmd)
  local cmd_tbl = {
    Auxiliary = "texlab.cleanAuxiliary",
    Artifacts = "texlab.cleanArtifacts",
  }
  return function(client, bufnr)
    return client:exec_cmd({
      title = ("clean_%s"):format(cmd),
      command = cmd_tbl[cmd],
      arguments = { { uri = util.uri_from_buf(bufnr) } },
    }, { bufnr = bufnr }, function(err, _)
      if err then
        btv.notify(("Failed to clean %s files: %s"):format(cmd, err.message), btv.log.levels.ERROR)
      else
        btv.notify(("Command %s executed successfully"):format(cmd), btv.log.levels.INFO)
      end
    end)
  end
end

local function buf_find_envs(client, bufnr)
  client:exec_cmd({
    command = "texlab.findEnvironments",
    arguments = { btv.lsp.position_params({ encoding = client.offset_encoding }) },
  }, { bufnr = bufnr }, function(err, result)
    if err then
      return btv.notify(err.code .. ": " .. err.message, btv.log.levels.ERROR)
    end
    local env_names = {}
    for _, env in ipairs(result) do
      table.insert(env_names, env.name.text)
    end
    -- Indent each name one step further than the one before it: the environments at
    -- a position are NESTED, and the staircase is what shows the nesting.
    for i, name in ipairs(env_names) do
      env_names[i] = string.rep(" ", i - 1) .. name
    end
    -- A transient content float, sized by the server's answer and dismissed by the
    -- next key — bemtvi's float owns its own geometry, so upstream's explicit
    -- height/width (and the `focusable = false` that expressed "don't put me in
    -- it") have nothing to set: a non-persistent `btv.ui.float` is already that.
    btv.ui.float(env_names, { title = "Environments" })
  end)
end

local function buf_change_env(client, bufnr)
  btv.ui.input({ prompt = "New environment name: " }, function(input)
    if not input or input == "" then
      return btv.notify("No environment name provided", btv.log.levels.WARN)
    end
    -- The whole params shape, cursor included, in the encoding this server agreed
    -- to — a hand-built `{ line, character }` from the cursor's BYTE column is off
    -- by one per multi-byte character on the line, which for `\begin{…}` names in a
    -- non-ASCII document is exactly where it matters.
    local params = btv.lsp.position_params({ bufnr = bufnr, encoding = client.offset_encoding })
    return client:exec_cmd({
      title = "change_environment",
      command = "texlab.changeEnvironment",
      arguments = {
        {
          textDocument = params.textDocument,
          position = params.position,
          newName = tostring(input),
        },
      },
    }, { bufnr = bufnr })
  end)
end

return {
  cmd = { "texlab" },
  filetypes = { "tex", "plaintex", "bib" },
  root_markers = { ".git", ".latexmkrc", "latexmkrc", ".texlabroot", "texlabroot", "Tectonic.toml" },
  settings = {
    texlab = {
      rootDirectory = nil,
      build = {
        executable = "latexmk",
        args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
        onSave = false,
        forwardSearchAfter = false,
      },
      forwardSearch = {
        executable = nil,
        args = {},
      },
      chktex = {
        onOpenAndSave = false,
        onEdit = false,
      },
      diagnosticsDelay = 300,
      latexFormatter = "latexindent",
      latexindent = {
        ["local"] = nil, -- local is a reserved keyword
        modifyLineBreaks = false,
      },
      bibtexFormatter = "texlab",
      formatterLineLength = 80,
    },
  },
  on_attach = function(client, bufnr)
    for _, cmd in ipairs({
      { name = "TexlabBuild", fn = buf_build, desc = "Build the current buffer" },
      { name = "TexlabForward", fn = buf_search, desc = "Forward search from current position" },
      { name = "TexlabCancelBuild", fn = buf_cancel_build, desc = "Cancel the current build" },
      { name = "TexlabDependencyGraph", fn = dependency_graph, desc = "Show the dependency graph" },
      {
        name = "TexlabCleanArtifacts",
        fn = command_factory("Artifacts"),
        desc = "Clean the artifacts",
      },
      {
        name = "TexlabCleanAuxiliary",
        fn = command_factory("Auxiliary"),
        desc = "Clean the auxiliary files",
      },
      {
        name = "TexlabFindEnvironments",
        fn = buf_find_envs,
        desc = "Find the environments at current position",
      },
      {
        name = "TexlabChangeEnvironment",
        fn = buf_change_env,
        desc = "Change the environment at current position",
      },
    }) do
      util.buf_command(bufnr, "Lsp" .. cmd.name, function()
        cmd.fn(client, bufnr)
      end, { desc = cmd.desc })
    end
  end,
}
