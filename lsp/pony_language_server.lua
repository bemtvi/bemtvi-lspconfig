---@brief
---
--- Renamed to [pony_lsp](#pony_lsp)

-- The whole of `pony_language_server` is `pony_lsp` under its old name. `btv.lsp.get_config` resolves the
-- preset the same way the dispatcher would, so this stays a real alias — including any
-- override the user has already layered onto `pony_lsp` — rather than a copy that drifts.
return btv.tbl.extend("force", btv.lsp.get_config("pony_lsp"), {
  on_init = function(...)
    btv.notify_once(
      "bemtvi-lspconfig: 'pony_language_server' has been renamed to 'pony_lsp'; enable that instead",
      btv.log.levels.WARN
    )
    local inner = btv.lsp.get_config("pony_lsp").on_init
    if inner then
      return inner(...)
    end
  end,
})
