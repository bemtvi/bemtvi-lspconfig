---@brief
---
--- https://github.com/mhersson/mpls
---
--- Markdown Preview Language Server

local util = require("bemtvi-lspconfig.util")

return {
  cmd = {
    "mpls",
    "--theme",
    "dark",
    "--enable-emoji",
    "--enable-footnotes",
    "--no-auto",
  },
  root_markers = { ".marksman.toml", ".git" },
  filetypes = { "markdown" },
  on_attach = function(client, bufnr)
    btv.autocmd.create("BufEnter", {
      pattern = { "*.md" },
      group = btv.augroup.create("lspconfig.mpls.focus", { clear = true }),
      callback = function(ctx)
        ---@diagnostic disable-next-line:param-type-mismatch
        client:notify("mpls/editorDidChangeFocus", { uri = ctx.match })
      end,
      desc = "mpls: notify buffer focus changed",
    })
    util.buf_command(bufnr, "LspMplsOpenPreview", function()
      client:exec_cmd({
        title = "Preview markdown with mpls",
        command = "open-preview",
      })
    end, { desc = "Preview markdown with mpls" })
  end,
}
