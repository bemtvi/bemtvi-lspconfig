---@brief
---
--- Renamed to [vue_ls](#vue_ls)

-- The whole of `volar` is `vue_ls` under its old name. `nx.lsp.get_config` resolves the
-- preset the same way the dispatcher would, so this stays a real alias — including any
-- override the user has already layered onto `vue_ls` — rather than a copy that drifts.
return nx.tbl.extend("force", nx.lsp.get_config("vue_ls"), {
  on_init = function(...)
    nx.notify_once(
      "nxvim-lspconfig: 'volar' has been renamed to 'vue_ls'; enable that instead",
      nx.log.levels.WARN
    )
    local inner = nx.lsp.get_config("vue_ls").on_init
    if inner then
      return inner(...)
    end
  end,
})
