---@brief
---
--- Renamed to [vsrocq](#vsrocq)

-- The whole of `vscoqtop` is `vsrocq` under its old name. `btv.lsp.get_config` resolves the
-- preset the same way the dispatcher would, so this stays a real alias — including any
-- override the user has already layered onto `vsrocq` — rather than a copy that drifts.
return btv.tbl.extend("force", btv.lsp.get_config("vsrocq"), {
  on_init = function(...)
    btv.notify_once(
      "bemtvi-lspconfig: 'vscoqtop' has been renamed to 'vsrocq'; enable that instead",
      btv.log.levels.WARN
    )
    local inner = btv.lsp.get_config("vsrocq").on_init
    if inner then
      return inner(...)
    end
  end,
})
