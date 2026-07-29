---@brief
---
--- Combination of both lint server and client
---
--- https://github.com/nametake/golangci-lint-langserver
--- https://github.com/golangci/golangci-lint
---
---
--- Installation of binaries needed is done via
---
--- ```
--- go install github.com/nametake/golangci-lint-langserver@latest
--- go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
--- ```

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "golangci-lint-langserver" },
  filetypes = { "go", "gomod" },
  init_options = {
    command = {
      "golangci-lint",
      "run",
      -- disable all output formats that might be enabled by the users .golangci.yml
      "--output.text.path=",
      "--output.tab.path=",
      "--output.html.path=",
      "--output.checkstyle.path=",
      "--output.junit-xml.path=",
      "--output.teamcity.path=",
      "--output.sarif.path=",
      -- disable stats output
      "--show-stats=false",
      -- enable JSON output to be used by the language server
      "--output.json.path=stdout",
    },
  },
  root_markers = {
    ".golangci.yml",
    ".golangci.yaml",
    ".golangci.toml",
    ".golangci.json",
    "go.work",
    "go.mod",
    ".git",
  },
  before_init = nx.async(function(_init_params, config)
    -- Add support for golangci-lint V1 (in V2 `--out-format=json` was replaced by
    -- `--output.json.path=stdout`).

    local exe = nx.await(util.which("golangci-lint"))
    if not exe then
      return
    end

    local v1, v2 = false, false
    -- PERF: `golangci-lint version` is very slow (about 0.1 sec) so let's find
    -- version using `go version -m $(which golangci-lint) | grep '^\smod'`.
    if nx.await(util.which("go")) then
      local out = nx.await(util.output({ "go", "version", "-m", exe })) or ""
      v1 = string.match(out, "\tmod\tgithub.com/golangci/golangci%-lint\t")
      v2 = string.match(out, "\tmod\tgithub.com/golangci/golangci%-lint/v2\t")
    end
    if not v1 and not v2 then
      v1 =
        string.match(nx.await(util.output({ "golangci-lint", "version" })) or "", "version v?1%.")
    end
    if v1 then
      config.init_options = nx.tbl.extend("force", config.init_options or {}, {
        command = { "golangci-lint", "run", "--out-format", "json" },
      })
    end
  end),
}
