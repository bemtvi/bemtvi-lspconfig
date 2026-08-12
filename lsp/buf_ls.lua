--- @brief
--- https://github.com/bufbuild/buf
---
--- buf lsp included in the cli itself
---
--- buf lsp is a Protobuf language server compatible with Buf modules and workspaces
---
--- buf lsp also supports Buf configuration files. The `buf-config` filetype is not
--- detected automatically; register it manually (see below) or override the filetypes:
---
--- ```lua
--- btv.on({ "BufReadPost", "BufNewFile" }, { pattern = { "buf.yaml", "buf.gen.yaml", "buf.policy.yaml", "buf.lock" } }, function()
---   btv.bo.filetype = "buf-config"
--- end)
--- ```
---
--- Buf config files are YAML. bemtvi has no filetype-to-grammar alias, so they are not
--- highlighted under the `buf-config` filetype; `:setf yaml` in such a buffer gives
--- YAML highlighting for that session.

return {
  cmd = { "buf", "lsp", "serve", "--log-format=text" },
  filetypes = { "proto", "buf-config" },
  root_markers = { "buf.yaml", ".git" },
  reuse_client = function(client, config)
    -- `buf lsp serve` is meant to be used with multiple workspaces.
    return client.name == config.name
  end,
}
