---@brief
---
--- https://github.com/stardog-union/stardog-language-servers/tree/master/packages/turtle-language-server
---
--- `turtle-language-server` can be installed via `npm`:
--- ```sh
--- npm i -g turtle-language-server
--- ```

local util = require("nxvim-lspconfig.util")

local BIN = "turtle-language-server"

return {
  -- The server is a node script, so it is run through `node` rather than executed. A
  -- copy under `$NVM_BIN` is the active nvm-managed node's own, and takes precedence
  -- over whatever `$PATH` resolves to — running one node's script under another node is
  -- how this breaks. Upstream scans `$PATH` by hand at load time; `which` is the same
  -- search, asynchronously, once the server is actually starting.
  cmd = nx.async(function()
    local nvm_bin = nx.env.get("NVM_BIN")
    local path = nvm_bin and util.joinpath(nvm_bin, BIN) or nil
    if path and not nx.await(util.exists(path)) then
      path = nil
    end
    path = path or nx.await(util.which(BIN))
    if not path then
      error("turtle_ls: " .. BIN .. " not found on $PATH (npm i -g " .. BIN .. ")")
    end
    return { "node", path, "--stdio" }
  end),
  filetypes = { "turtle", "ttl" },
  root_markers = { ".git" },
}
