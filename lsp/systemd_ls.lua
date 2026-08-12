---@brief
---
--- Renamed to [systemd_lsp](#systemd_lsp)

-- The whole of `systemd_ls` is `systemd_lsp` under its old name. `btv.lsp.get_config` resolves the
-- preset the same way the dispatcher would, so this stays a real alias — including any
-- override the user has already layered onto `systemd_lsp` — rather than a copy that drifts.
return btv.tbl.extend("force", btv.lsp.get_config("systemd_lsp"), {
  on_init = function(...)
    btv.notify_once(
      "bemtvi-lspconfig: 'systemd_ls' has been renamed to 'systemd_lsp'; enable that instead",
      btv.log.levels.WARN
    )
    local inner = btv.lsp.get_config("systemd_lsp").on_init
    if inner then
      return inner(...)
    end
  end,
})
