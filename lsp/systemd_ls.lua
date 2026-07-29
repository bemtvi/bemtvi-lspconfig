---@brief
---
--- Renamed to [systemd_lsp](#systemd_lsp)

-- The whole of `systemd_ls` is `systemd_lsp` under its old name. `nx.lsp.get_config` resolves the
-- preset the same way the dispatcher would, so this stays a real alias — including any
-- override the user has already layered onto `systemd_lsp` — rather than a copy that drifts.
return nx.tbl.extend("force", nx.lsp.get_config("systemd_lsp"), {
  on_init = function(...)
    nx.notify_once(
      "nxvim-lspconfig: 'systemd_ls' has been renamed to 'systemd_lsp'; enable that instead",
      nx.log.levels.WARN
    )
    local inner = nx.lsp.get_config("systemd_lsp").on_init
    if inner then
      return inner(...)
    end
  end,
})
