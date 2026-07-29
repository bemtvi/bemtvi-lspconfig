---@brief
---
--- https://github.com/dzhu/openscad-language-server
---
--- A Language Server Protocol server for OpenSCAD
---
--- You can build and install `openscad-language-server` binary with `cargo`:
--- ```sh
--- cargo install openscad-language-server
--- ```
---
--- Vim does not have built-in syntax for the `openscad` filetype currently.
---
--- This can be added via an autocmd:
---
--- ```lua
--- nx.on({ "BufReadPost", "BufNewFile" }, { pattern = "*.scad" }, function()
---   nx.bo.filetype = "openscad"
--- end)
--- ```
---
--- or by installing a filetype plugin such as https://github.com/sirtaj/vim-openscad

return {
  cmd = { "openscad-language-server" },
  filetypes = { "openscad" },
  root_markers = { ".git" },
}
