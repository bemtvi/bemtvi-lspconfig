---@brief
---
--- https://github.com/zizmorcore/zizmor
---
--- Zizmor language server.
---
--- `zizmor` can be installed by following the instructions [here](https://docs.zizmor.sh/installation/).
---
--- The default `cmd` assumes that the `zizmor` binary can be found in `$PATH`.
---
--- See `zizmor`'s [documentation](https://docs.zizmor.sh/) for additional documentation.

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "zizmor", "--lsp" },
  filetypes = { "yaml" },

  -- `root_dir` ensures that the LSP does not attach to all yaml files
  root_dir = function(bufnr, on_dir)
    local bufname = util.bufname(bufnr)
    local parent = util.dirname(bufname)
    if
      nx.str.endswith(parent, "/.github/workflows")
      or nx.str.endswith(parent, "/.forgejo/workflows")
      or nx.str.endswith(parent, "/.gitea/workflows")
      or (nx.str.endswith(bufname, "/.github/dependabot.yml") or nx.str.endswith(
        bufname,
        "/.github/dependabot.yaml"
      ))
      or (nx.str.endswith(bufname, "action.yml") or nx.str.endswith(bufname, "action.yaml")) -- Composite actions can live in any repository subdirectory
    then
      on_dir(parent)
    end
  end,
  init_options = {}, -- needs to be present https://github.com/neovim/nvim-lspconfig/pull/3713#issuecomment-2857394868
  capabilities = {
    workspace = {
      didChangeWorkspaceFolders = {
        dynamicRegistration = true,
      },
    },
  },
}
