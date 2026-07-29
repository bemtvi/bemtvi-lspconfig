---@brief
---
--- https://github.com/Akzestia/cqlls
---
--- Install via cargo:
--- ```sh
--- cargo install cqlls
--- ```

return {
  cmd = { "cqlls" },
  filetypes = { "cql", "cqlang" },
  root_markers = { ".cqlls", ".git" },
  settings = {},
}
