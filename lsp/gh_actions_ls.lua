---@brief
--- https://github.com/lttb/gh-actions-language-server
---
--- Language server for GitHub Actions.
---
--- The projects [forgejo](https://forgejo.org/) and [gitea](https://about.gitea.com/)
--- design their actions to be as compatible to github as possible
--- with only [a few differences](https://docs.gitea.com/usage/actions/comparison#unsupported-workflows-syntax) between the systems.
--- The `gh_actions_ls` is therefore enabled for those `yaml` files as well.
---
--- The `gh-actions-language-server` can be installed via `npm`:
---
--- ```sh
--- npm install -g gh-actions-language-server
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = { "gh-actions-language-server", "--stdio" },
  filetypes = { "yaml" },

  -- `root_dir` ensures that the LSP does not attach to all yaml files
  root_dir = function(bufnr, on_dir)
    local parent = util.dirname(util.bufname(bufnr))
    if
      btv.str.endswith(parent, "/.github/workflows")
      or btv.str.endswith(parent, "/.forgejo/workflows")
      or btv.str.endswith(parent, "/.gitea/workflows")
    then
      on_dir(parent)
    end
  end,
  -- The server asks the editor to read files it can't reach itself (reusable workflows,
  -- composite actions in another repo) through a server-initiated `actions/readFile`.
  -- bemtvi does not route server-initiated requests into Lua, so `btv.lsp` reports this
  -- key loud and the request goes unanswered: completion and validation still work, but
  -- stop at the boundary of the file being edited. The key is kept rather than deleted
  -- precisely so that report keeps naming the gap.
  --
  -- The body cannot be carried over either — an LSP reply must be produced
  -- synchronously, and bemtvi has no synchronous file read (all fs is `btv.fs`, async).
  -- Closing this needs server-initiated request routing in the core, not a shim here.
  handlers = {
    ["actions/readFile"] = function()
      error("gh_actions_ls: bemtvi does not route server-initiated requests into Lua")
    end,
  },
  init_options = {}, -- needs to be present https://github.com/neovim/nvim-lspconfig/pull/3713#issuecomment-2857394868
  capabilities = {
    workspace = {
      didChangeWorkspaceFolders = {
        dynamicRegistration = true,
      },
    },
  },
}
