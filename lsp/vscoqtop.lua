---@brief
---
--- Renamed to [vsrocq](#vsrocq)

-- The whole of `vscoqtop` is `vsrocq` under its old name. `nx.lsp.get_config` resolves the
-- preset the same way the dispatcher would, so this stays a real alias — including any
-- override the user has already layered onto `vsrocq` — rather than a copy that drifts.
return nx.tbl.extend("force", nx.lsp.get_config("vsrocq"), {
  on_init = function(...)
    nx.notify_once(
      "nxvim-lspconfig: 'vscoqtop' has been renamed to 'vsrocq'; enable that instead",
      nx.log.levels.WARN
    )
    local inner = nx.lsp.get_config("vsrocq").on_init
    if inner then
      return inner(...)
    end
  end,
})
