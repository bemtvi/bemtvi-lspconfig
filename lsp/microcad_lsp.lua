---@brief
--- https://codeberg.org/microcad/microcad/src/branch/main/crates/lsp
---
--- An LSP for the µcad model description language
---
--- Install with
--- ```sh
--- cargo install microcad-lsp
--- ```
--- nxvim does not detect µcad filetype automatically, so you will need to add the following to your
---
--- ```lua
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.µcad" }, function()
---   nx.bo.filetype = "microcad"
--- end)
--- ```

return {
  name = "microcad_lsp",
  cmd = { "microcad-lsp", "--stdio" },
  filetypes = { "microcad" },
  root_markers = { ".git" },
}
