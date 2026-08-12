---@brief
---
--- https://github.com/salesforce/agentscript
---
--- Language server for Agent Script, Salesforce's open agent specification
--- language for `*.agent` files. Install with
--- `npm install -g @sf-agentscript/lsp-server`.
---
--- bemtvi does not detect the `agentscript` filetype by default:
---
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.agent" }, function()
---   btv.bo.filetype = "agentscript"
--- end)
--- ```

return {
  cmd = { "agentscript-lsp", "--stdio" },
  filetypes = { "agentscript" },
  root_markers = { "package.json", ".git" },
}
