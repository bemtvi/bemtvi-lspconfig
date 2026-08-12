---@brief
---
---Vacuum is the worlds fastest OpenAPI 3, OpenAPI 2 / Swagger linter and quality analysis tool.
---
--- You can install vacuum using mason or follow the instructions here: https://github.com/daveshanley/vacuum
---
--- The file types are not detected automatically, you can register them manually (see below) or override the filetypes:
---
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*openapi*%.ya?ml" }, function()
---   btv.bo.filetype = "yaml.openapi"
--- end)
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*openapi*%.json" }, function()
---   btv.bo.filetype = "json.openapi"
--- end)
--- ```

return {
  cmd = { "vacuum", "language-server" },
  filetypes = { "yaml.openapi", "json.openapi" },
  root_markers = { ".git" },
}
