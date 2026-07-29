---@brief
---
--- https://github.com/thqby/vscode-autohotkey2-lsp
---
--- AutoHotkey v2.0 LSP implementation
---
--- NOTE: AutoHotkey is Windows-only.

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "autohotkey_lsp", "--stdio" },
  filetypes = { "autohotkey" },
  root_markers = { "package.json" },
  ---@diagnostic disable-next-line: missing-fields
  flags = { debounce_text_changes = 500 },
  --capabilities = capabilities,
  --on_attach = custom_attach,
  -- `InterpreterPath` needs the AutoHotkey interpreter's real location, which is a
  -- `$PATH` lookup — I/O, so it is resolved once per server here rather than at load.
  before_init = nx.async(function(_init_params, config)
    config.init_options = nx.tbl.deep_extend("force", config.init_options or {}, {
      InterpreterPath = nx.await(util.which(util.exe("autohotkey"))) or "",
    })
  end),
  init_options = {
    locale = "en-us",
    AutoLibInclude = "All",
    CommentTags = "^;;\\s*(?<tag>.+)",
    CompleteFunctionParens = false,
    SymbolFoldinFromOpenBrace = false,
    Diagnostics = {
      ClassStaticMemberCheck = true,
      ParamsCheck = true,
    },
    ActionWhenV1IsDetected = "Continue",
    FormatOptions = {
      array_style = "expand",
      break_chained_methods = false,
      ignore_comment = false,
      indent_string = "\t",
      max_preserve_newlines = 2,
      brace_style = "One True Brace",
      object_style = "none",
      preserve_newlines = true,
      space_after_double_colon = true,
      space_before_conditional = true,
      space_in_empty_paren = false,
      space_in_other = true,
      space_in_paren = false,
      wrap_line_length = 0,
    },
  },
}
