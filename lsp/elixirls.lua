---@brief
---
--- https://github.com/elixir-lsp/elixir-ls
---
--- `elixir-ls` can be installed by following the instructions [here](https://github.com/elixir-lsp/elixir-ls#building-and-running).
---
--- 1. Download the zip from https://github.com/elixir-lsp/elixir-ls/releases/latest/
--- 2. Unzip it and make it executable.
---    ```bash
---    unzip elixir-ls.zip -d /path/to/elixir-ls
---    # Unix
---    chmod +x /path/to/elixir-ls/language_server.sh
---    ```
---
--- **By default, elixir-ls doesn't have a `cmd` set.** This is because nvim-lspconfig does not make assumptions about
--- your path. You must add the following to your init.vim or init.lua to set `cmd` to the absolute path ($HOME and
--- ~ are not expanded) of your unzipped elixir-ls.
---
--- ```lua
--- nx.lsp.config('elixirls', {
---     -- Unix
---     cmd = { "/path/to/elixir-ls/language_server.sh" };
---     -- Windows
---     cmd = { "/path/to/elixir-ls/language_server.bat" };
---     ...
--- })
--- ```
---
--- 'root_dir' is chosen like this: if two or more directories containing `mix.exs` were found when searching
--- directories upward, the second one (higher up) is chosen, with the assumption that it is the root of an umbrella
--- app. Otherwise the directory containing the single mix.exs that was found is chosen.

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "elixir-ls" },
  filetypes = { "elixir", "eelixir", "heex", "surface" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    --- Elixir workspaces may have multiple `mix.exs` files, for an "umbrella" layout or monorepo.
    --- So we specify `limit=2` and treat the highest one (if any) as the root of an umbrella app.
    util.find_upward_all(fname, { "mix.exs" }, { limit = 2 }):next(function(matches)
      local child_or_root_path, maybe_umbrella_path = matches[1], matches[2]
      local mix = maybe_umbrella_path or child_or_root_path
      -- An elixir buffer outside any mix project has no root at all; upstream errors
      -- here (`dirname(nil)`), which loses the buffer rather than just the server.
      if mix then
        on_dir(util.dirname(mix))
      end
    end)
  end,
}
