---@brief
---
--- https://llvm.github.io/clangir
---
--- The Language Server for the LLVM ClangIR language
---
--- `cir-lsp-server` can be installed at the llvm-project repository (https://github.com/llvm/llvm-project)

return {
  cmd = { "cir-lsp-server" },
  filetypes = { "cir" },
  root_markers = { ".git" },
}
