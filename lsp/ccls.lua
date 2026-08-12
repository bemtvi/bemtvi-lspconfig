---@brief
---
--- https://github.com/MaskRay/ccls/wiki
---
--- ccls relies on a [JSON compilation database](https://clang.llvm.org/docs/JSONCompilationDatabase.html) specified
--- as compile_commands.json or, for simpler projects, a .ccls.
--- For details on how to automatically generate one using CMake look [here](https://cmake.org/cmake/help/latest/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html). Alternatively, you can use [Bear](https://github.com/rizsotto/Bear).
---
--- Customization options are passed to ccls at initialization time via init_options, a list of available options can be found [here](https://github.com/MaskRay/ccls/wiki/Customization#initialization-options). For example:
---
--- ```lua
--- btv.lsp.config("ccls", {
---   init_options = {
---     compilationDatabaseDirectory = "build";
---     index = {
---       threads = 0;
---     };
---     clang = {
---       excludeArgs = { "-frounding-math"} ;
---     };
---   }
--- })
--- ```

local util = require("bemtvi-lspconfig.util")

local function switch_source_header(client, bufnr)
  local method_name = "textDocument/switchSourceHeader"
  local params = btv.lsp.text_document_params(bufnr)
  client:request(method_name, params, function(err, result)
    if err then
      error(tostring(err))
    end
    if not result then
      btv.notify("corresponding file cannot be determined")
      return
    end
    -- The native open: reuses the buffer already holding that file and honors
    -- 'switchbuf', rather than opening a second buffer for the same header.
    btv.lsp.show_document({ uri = result })
  end, bufnr)
end

return {
  cmd = { "ccls" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  root_markers = { "compile_commands.json", ".ccls", ".git" },
  offset_encoding = "utf-32",
  -- ccls does not support sending a null root directory
  workspace_required = true,
  on_attach = function(client, bufnr)
    util.buf_command(bufnr, "LspCclsSwitchSourceHeader", function()
      switch_source_header(client, bufnr)
    end, { desc = "Switch between source/header" })
  end,
}
