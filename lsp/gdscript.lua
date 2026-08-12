---@brief
---
--- https://github.com/godotengine/godot
---
--- Language server for GDScript, used by Godot Engine.
---
--- Godot does not ship a language server you can spawn: the editor itself listens on a
--- TCP port (`6005` by default, `$GDScript_Port` to override) and the client connects
--- to it. bemtvi's LSP transport spawns a process and speaks to its stdio — there is no
--- TCP leg — so this config cannot start, and says so rather than pretending.
---
--- Closing this needs a socket transport in `bemtvi-lsp` alongside the stdio one.
--- (`btv.socket.connect` already exists for plugins; it is the LSP client that has no
--- way to use it.)

return {
  cmd = function()
    error(
      "gdscript: Godot's language server is reached over TCP (127.0.0.1:"
        .. (btv.env.get("GDScript_Port") or "6005")
        .. "), and bemtvi's LSP client speaks only to a spawned process's stdio"
    )
  end,
  filetypes = { "gdscript" },
  root_markers = { "project.godot", ".git" },
}
