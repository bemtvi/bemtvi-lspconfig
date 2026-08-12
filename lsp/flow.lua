---@brief
---
--- https://flow.org/
--- https://github.com/facebook/flow
---
--- See below for how to setup Flow itself.
--- https://flow.org/en/docs/install/
---
--- See below for lsp command options.
---
--- ```sh
--- npx flow lsp --help
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = btv.async(function(_dispatchers, config)
    if btv.await(util.which("flow")) then
      return { "flow", "lsp" }
    end
    local flow_bin = btv.await(util.local_bin((config or {}).root_dir, "flow"))
    if flow_bin then
      return { flow_bin, "lsp" }
    end
    return { "npx", "--no-install", "flow", "lsp" }
  end),
  filetypes = { "javascript", "javascriptreact" },
  root_markers = { ".flowconfig" },
}
