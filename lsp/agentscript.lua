---@brief
---
--- https://github.com/salesforce/agentscript
---
--- Language server for Agent Script, Salesforce's open agent specification
--- language for `*.agent` files. Install with
--- `npm install -g @sf-agentscript/lsp-server`.
---
--- nxvim does not detect the `agentscript` filetype by default:
---
--- ```lua
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.agent" }, function()
---   nx.bo.filetype = "agentscript"
--- end)
--- ```

return {
  cmd = { "agentscript-lsp", "--stdio" },
  filetypes = { "agentscript" },
  root_markers = { "package.json", ".git" },
}
