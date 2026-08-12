---@brief
--- https://codeberg.org/microcad/microcad/src/branch/main/crates/lsp
---
--- An LSP for the µcad model description language
---
--- Install with
--- ```sh
--- cargo install microcad-lsp
--- ```
--- bemtvi does not detect µcad filetype automatically, so you will need to add the following to your
---
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.µcad" }, function()
---   btv.bo.filetype = "microcad"
--- end)
--- ```

return {
  name = "microcad_lsp",
  cmd = { "microcad-lsp", "--stdio" },
  filetypes = { "microcad" },
  root_markers = { ".git" },
}
