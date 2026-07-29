---@brief
---
--- https://github.com/swiftlang/sourcekit-lsp
---
--- Language server for Swift and C/C++/Objective-C.

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "sourcekit-lsp" },
  filetypes = { "swift", "objc", "objcpp", "c", "cpp" },
  root_dir = function(bufnr, on_dir)
    local filename = util.bufname(bufnr)
    -- Pattern order is priority: a build-server description beats an Xcode project,
    -- which beats a compilation database or a package manifest. `Package.swift` is
    -- deliberately near the end — a modularized app has one per module, and rooting at
    -- the nearest would attach the server inside a single module.
    util
      .root_pattern(
        "buildServer.json",
        ".bsp",
        "*.xcodeproj",
        "*.xcworkspace",
        "compile_commands.json",
        "Package.swift",
        ".git"
      )(filename)
      :next(on_dir)
  end,
  get_language_id = function(_, ftype)
    local t = { objc = "objective-c", objcpp = "objective-cpp" }
    return t[ftype] or ftype
  end,
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
    textDocument = {
      diagnostic = {
        dynamicRegistration = true,
        relatedDocumentSupport = true,
      },
    },
  },
}
