---@brief
---
--- Renamed to [pony_lsp](#pony_lsp)

-- The whole of `pony_language_server` is `pony_lsp` under its old name. `nx.lsp.get_config` resolves the
-- preset the same way the dispatcher would, so this stays a real alias — including any
-- override the user has already layered onto `pony_lsp` — rather than a copy that drifts.
return nx.tbl.extend("force", nx.lsp.get_config("pony_lsp"), {
  on_init = function(...)
    nx.notify_once(
      "nxvim-lspconfig: 'pony_language_server' has been renamed to 'pony_lsp'; enable that instead",
      nx.log.levels.WARN
    )
    local inner = nx.lsp.get_config("pony_lsp").on_init
    if inner then
      return inner(...)
    end
  end,
})
