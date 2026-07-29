---@brief
--- https://github.com/Davidyz/VectorCode
---
--- A Language Server Protocol implementation for VectorCode, a code repository indexing tool.

return {
  cmd = { "vectorcode-server" },
  -- Upstream spells this `root_dir = vim.fs.root(0, …)`, which runs the search once at
  -- *load* time against whatever buffer happened to be current and then freezes that
  -- answer for the session. Declared as markers it is re-resolved per buffer, which is
  -- what it meant to say.
  root_markers = { ".vectorcode", ".git" },
  settings = {},
}
