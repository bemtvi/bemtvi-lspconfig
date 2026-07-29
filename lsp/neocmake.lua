---@brief
---
--- https://github.com/neocmakelsp/neocmakelsp
---
--- CMake LSP Implementation
---
--- `neocmakelsp` only offers completions when the client advertises snippet support.
--- nxvim expands snippet completions natively (`nx.snippet`), but does not advertise
--- `snippetSupport` in its base capabilities, so ask for it in this server's config.
--- `capabilities` is deep-merged OVER nxvim's base set, so this adds to it rather
--- than replacing it:
---
--- ```lua
--- nx.lsp.config("neocmake", {
---   capabilities = {
---     textDocument = { completion = { completionItem = { snippetSupport = true } } },
---   },
--- })
--- ```

return {
  cmd = { "neocmakelsp", "stdio" },
  filetypes = { "cmake" },
  root_markers = { ".neocmake.toml", ".git", "build", "cmake" },
}
