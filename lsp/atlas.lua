---@brief
---
--- https://github.com/ariga/atlas
---
--- Language server for Atlas config and schema files.
---
--- You may also need to configure the filetype for *.hcl files:
---
--- ```vim
--- autocmd BufNewFile,BufRead atlas.hcl set filetype=atlas-config
--- autocmd BufNewFile,BufRead *.my.hcl set filetype=atlas-schema-mysql
--- autocmd BufNewFile,BufRead *.pg.hcl set filetype=atlas-schema-postgresql
--- autocmd BufNewFile,BufRead *.lt.hcl set filetype=atlas-schema-sqlite
--- autocmd BufNewFile,BufRead *.ch.hcl set filetype=atlas-schema-clickhouse
--- autocmd BufNewFile,BufRead *.ms.hcl set filetype=atlas-schema-mssql
--- autocmd BufNewFile,BufRead *.rs.hcl set filetype=atlas-schema-redshift
--- autocmd BufNewFile,BufRead *.test.hcl set filetype=atlas-test
--- autocmd BufNewFile,BufRead *.plan.hcl set filetype=atlas-plan
--- autocmd BufNewFile,BufRead *.rule.hcl set filetype=atlas-rule
--- ```
---
--- or
---
--- ```lua
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "atlas.hcl" }, function()
---   nx.bo.filetype = "atlas-config"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.my.hcl" }, function()
---   nx.bo.filetype = "atlas-schema-mysql"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.pg.hcl" }, function()
---   nx.bo.filetype = "atlas-schema-postgresql"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.lt.hcl" }, function()
---   nx.bo.filetype = "atlas-schema-sqlite"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.ch.hcl" }, function()
---   nx.bo.filetype = "atlas-schema-clickhouse"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.ms.hcl" }, function()
---   nx.bo.filetype = "atlas-schema-mssql"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.rs.hcl" }, function()
---   nx.bo.filetype = "atlas-schema-redshift"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.test.hcl" }, function()
---   nx.bo.filetype = "atlas-test"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.plan.hcl" }, function()
---   nx.bo.filetype = "atlas-plan"
--- end)
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.rule.hcl" }, function()
---   nx.bo.filetype = "atlas-rule"
--- end)
--- ```
---
--- These filetypes are all HCL. nxvim has no filetype-to-grammar alias, so they are
--- not highlighted under their own names; `:setf hcl` in such a buffer gives HCL
--- highlighting for that session.
---

return {
  cmd = { "atlas", "tool", "lsp", "--stdio" },
  filetypes = {
    "atlas-*",
  },
  root_markers = { "atlas.hcl" },
}
