---@brief
--- https://biomejs.dev
---
--- Toolchain of the web. [Successor of Rome](https://biomejs.dev/blog/annoucing-biome).
---
--- ```sh
--- npm install [-g] @biomejs/biome
--- ```
---
--- ### Monorepo support
---
--- `biome` supports monorepos by default. It will automatically find the `biome.json` corresponding to the package you are working on, as described in the [documentation](https://biomejs.dev/guides/big-projects/#monorepo). This works without the need of spawning multiple instances of `biome`, saving memory.

local util = require("nxvim-lspconfig.util")

return {
  cmd = util.node_cmd("biome", { "lsp-proxy" }),
  filetypes = {
    "astro",
    "css",
    "graphql",
    "html",
    "javascript",
    "javascriptreact",
    "json",
    "jsonc",
    "svelte",
    "typescript",
    "typescriptreact",
    "vue",
  },
  workspace_required = true,
  root_dir = util.root_dir(function(bufnr, on_dir)
    -- The project root is where the LSP can be started from
    -- As stated in the documentation above, this LSP supports monorepos and simple projects.
    -- We select then from the project root, which is identified by the presence of a package
    -- manager lock file.
    local root_markers = {
      "package-lock.json",
      "yarn.lock",
      "pnpm-lock.yaml",
      "bun.lockb",
      "bun.lock",
      "deno.lock",
    }
    -- Set a lower priority to avoid spawning multiple servers on monorepos
    local biome_config_files = { "biome.json", "biome.jsonc" }
    -- Give the root markers equal priority by wrapping them in a table
    root_markers = { root_markers, biome_config_files, { ".git" } }

    -- We fallback to the current working directory if no project root is found
    local project_root = nx.await(util.root(bufnr, root_markers)) or util.cwd()

    -- We know that the buffer is using Biome if it has a config file
    -- in its directory tree.
    local filename = util.bufname(bufnr)
    biome_config_files = nx.await(util.insert_package_json(biome_config_files, "biomejs", filename))
    local is_buffer_using_biome = nx.await(util.find_upward(filename, biome_config_files, {
      stop = util.dirname(project_root),
    }))
    if not is_buffer_using_biome then
      return
    end

    on_dir(project_root)
  end),
}
