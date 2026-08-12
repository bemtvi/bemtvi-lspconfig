---@brief
--- https://www.osohq.com/docs/develop/local-dev/env-setup
---
--- Oso Polar language server.
---
--- `oso-cloud` can be installed by following the instructions
--- [here](https://www.osohq.com/docs/develop/local-dev/env-setup).
---
--- The default `cmd` assumes that the `oso-cloud` binary can be found in the `$PATH`.
---
--- You may need to configure the filetype for Polar (*.polar) files:
---
--- ```
--- autocmd BufNewFile,BufRead *.polar set filetype=polar
--- ```
---
--- or
---
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.polar" }, function()
---   btv.bo.filetype = "polar"
--- end)
---
--- Alternatively, you may use a syntax plugin like https://github.com/osohq/polar.vim

return {
  cmd = { "oso-cloud", "lsp" },
  filetypes = { "polar" },
}
