-- bemtvi-lspconfig — the `:Lsp*` control commands.
--
-- Sourced automatically when the plugin is on the runtimepath. Only the commands
-- bemtvi does NOT already have live here:
--
--   * `:LspInfo` is a **native** ex-command (crates/bemtvi-server/src/excmd.rs) that
--     opens a scratch listing of every server, its root, its capabilities, and the
--     log path. Redefining it in Lua would shadow something better, so we don't.
--   * `:LspDefinition` / `:LspReferences` / `:LspHover` / `:LspFormat` /
--     `:LspRename` / `:LspCodeAction` / `:LspDiagnostics` are likewise native.
--
-- What upstream nvim-lspconfig's `plugin/lspconfig.lua` adds on top — start, stop,
-- restart, and open-the-log — is what this file provides, on `btv.lsp`.
--
-- Note on completion: bemtvi's user commands take `complete = "file" | "dir"` only,
-- so these take a server name as a plain argument with no tab-completion of names.
-- `:Lsp` in the command line still lists them with their `usage` and `desc`.

local lspconfig = require("bemtvi-lspconfig")

-- The config names to act on: the explicit argument, or — with none — every
-- server currently RUNNING (for stop/restart) or every configured server matching
-- this buffer's filetype (for start). Returns a list, possibly empty.
local function running_names()
  local seen, names = {}, {}
  for _, client in ipairs(btv.lsp.clients()) do
    if not seen[client.name] then
      seen[client.name] = true
      names[#names + 1] = client.name
    end
  end
  table.sort(names)
  return names
end

-- Split a command's argument line into names (whitespace-separated, so
-- `:LspStop gopls ruff` works like upstream's).
local function arg_names(args)
  local names = {}
  for word in tostring(args or ""):gmatch("%S+") do
    names[#names + 1] = word
  end
  return names
end

-- `:LspStart [name …]` — enable and launch the named servers. With no argument,
-- every bundled server whose `filetypes` include this buffer's filetype, which is
-- the "just start whatever serves this file" spelling.
btv.command("LspStart", function(o)
  local names = arg_names(o.args)
  if #names == 0 then
    names = lspconfig.for_filetype(btv.bo.filetype)
    if #names == 0 then
      btv.notify(
        "LspStart: no bundled server declares filetype '" .. tostring(btv.bo.filetype) .. "'",
        btv.log.levels.WARN
      )
      return
    end
  end
  lspconfig.enable(names)
  btv.notify("LspStart: enabled " .. table.concat(names, ", "))
end, {
  desc = "Enable and launch a language server",
  usage = "[server …]",
})

-- `:LspStop [name …]` — shut the named servers down now. With no argument, every
-- server currently running.
--
-- This DISABLES as well as stops (`btv.lsp.stop{ disable = true }`): stopping alone
-- would leave the config enabled, so the very next matching buffer would silently
-- start back up what you just asked to stop. `:LspStart` turns it on again.
btv.command("LspStop", function(o)
  local names = arg_names(o.args)
  if #names == 0 then
    names = running_names()
    if #names == 0 then
      btv.notify("LspStop: no language server is running", btv.log.levels.WARN)
      return
    end
  end
  for _, name in ipairs(names) do
    btv.lsp.stop(name, { disable = true }):next(function(n)
      -- Report per server: asking to stop something that isn't running is a
      -- mistake worth seeing, not a silent success.
      if n > 0 then
        btv.notify("LspStop: stopped " .. name)
      else
        btv.notify("LspStop: '" .. name .. "' was not running", btv.log.levels.WARN)
      end
    end)
  end
end, {
  desc = "Stop and disable the given language server(s)",
  usage = "[server …]",
})

-- `:LspRestart [name …]` — respawn the named servers from the config in force NOW
-- (the point being to pick up a `btv.lsp.config` change made since they started).
-- With no argument, every server currently running.
btv.command("LspRestart", function(o)
  local names = arg_names(o.args)
  if #names == 0 then
    names = running_names()
    if #names == 0 then
      btv.notify("LspRestart: no language server is running", btv.log.levels.WARN)
      return
    end
  end
  for _, name in ipairs(names) do
    btv.lsp.restart(name)
  end
  btv.notify("LspRestart: restarted " .. table.concat(names, ", "))
end, {
  desc = "Restart the given language server(s) with the current config",
  usage = "[server …]",
})

-- `:LspLog` — open bemtvi's LSP log in a new tab.
--
-- The path matches the engine's own resolution (crates/bemtvi-lsp/src/log.rs):
-- `$BEMTVI_LSP_LOG_FILE`, else `$XDG_STATE_HOME/bemtvi/lsp.log`, else
-- `~/.local/state/bemtvi/lsp.log`. Logging is off below WARN by default —
-- `$BEMTVI_LSP_LOG_LEVEL=debug` is what makes it interesting — so a missing or empty
-- file is reported as such rather than opening a confusing empty buffer.
btv.command("LspLog", function()
  local path = btv.env.get("BEMTVI_LSP_LOG_FILE")
  if not path or path == "" then
    local state = btv.env.get("XDG_STATE_HOME")
    if state and state ~= "" then
      path = btv.utils.joinpath(state, "bemtvi", "lsp.log")
    else
      path = btv.utils.expanduser("~/.local/state/bemtvi/lsp.log")
    end
  end
  btv.fs.exists(path):next(function(there)
    if not there then
      btv.notify(
        "LspLog: no log at " .. path .. " (set $BEMTVI_LSP_LOG_LEVEL=debug to produce one)",
        btv.log.levels.WARN
      )
      return
    end
    btv.cmd("tabnew " .. path)
  end)
end, { desc = "Open the bemtvi LSP log" })
