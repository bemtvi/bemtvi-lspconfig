---@brief
---
--- Renamed to [vue_ls](#vue_ls)

-- The whole of `volar` is `vue_ls` under its old name. `btv.lsp.get_config` resolves the
-- preset the same way the dispatcher would, so this stays a real alias — including any
-- override the user has already layered onto `vue_ls` — rather than a copy that drifts.
return btv.tbl.extend("force", btv.lsp.get_config("vue_ls"), {
  on_init = function(...)
    btv.notify_once(
      "bemtvi-lspconfig: 'volar' has been renamed to 'vue_ls'; enable that instead",
      btv.log.levels.WARN
    )
    local inner = btv.lsp.get_config("vue_ls").on_init
    if inner then
      return inner(...)
    end
  end,
})
