---@brief
---
--- Renamed to [vue_ls](#vue_ls)

return nx.tbl.extend("force", vim.lsp.config.vue_ls, {
  on_init = function(...)
    vim.deprecate("volar", "vue_ls", "3.0.0", "nvim-lspconfig", false)
    if vim.lsp.config.vue_ls.on_init then
      vim.lsp.config.vue_ls.on_init(...)
    end
  end,
})
