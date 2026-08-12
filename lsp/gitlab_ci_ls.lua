---@brief
---
--- https://github.com/alesbrelih/gitlab-ci-ls
---
--- Language Server for Gitlab CI
---
--- `gitlab-ci-ls` can be installed via cargo:
--- cargo install gitlab-ci-ls

local util = require("bemtvi-lspconfig.util")

local cache_dir = util.joinpath(util.home(), ".cache/gitlab-ci-ls")

return {
  cmd = { "gitlab-ci-ls" },
  filetypes = { "yaml.gitlab" },
  root_dir = function(bufnr, on_dir)
    util.root_pattern(".git", ".gitlab*")(util.bufname(bufnr)):next(on_dir)
  end,
  init_options = {
    cache_path = cache_dir,
    log_path = util.joinpath(cache_dir, "log/gitlab-ci-ls.log"),
  },
}
