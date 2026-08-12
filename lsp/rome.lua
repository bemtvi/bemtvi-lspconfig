---@brief
---
--- https://rome.tools
---
--- Language server for the Rome Frontend Toolchain.
---
--- (Unmaintained, use [Biome](https://biomejs.dev/blog/annoucing-biome) instead.)
---
--- ```sh
--- npm install [-g] rome
--- ```

local util = require("bemtvi-lspconfig.util")

return {
  cmd = util.node_cmd("rome", { "lsp-proxy" }),
  filetypes = {
    "javascript",
    "javascriptreact",
    "json",
    "typescript",
    "typescriptreact",
  },
  root_markers = { "package.json", "node_modules", ".git" },
}
