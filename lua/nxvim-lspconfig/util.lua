-- nxvim-lspconfig — the helper surface every bundled server config is written
-- against.
--
-- This is the native replacement for upstream nvim-lspconfig's `lspconfig.util`,
-- and the reason the port is a rewrite rather than a shim: upstream's helpers are
-- built on `vim.fs.root`, `vim.fn.executable`, `vim.uv.fs_stat` and
-- `vim.system(…):wait()` — all of which BLOCK the editor. nxvim has no blocking
-- I/O at all, so every helper here that touches the filesystem or a subprocess
-- returns a PROMISE instead.
--
-- What that means for a config author: the two config fields that need I/O —
-- `cmd` (locate a binary) and `root_dir` (probe the project) — may be `nx.async`
-- functions returning a promise, and `nx.lsp` awaits them before it spawns.
--
-- ```lua
-- return {
--   cmd = util.node_cmd("typescript-language-server", { "--stdio" }),
--   filetypes = { "typescript" },
--   root_markers = { { "package-lock.json" }, { ".git" } },
-- }
-- ```
--
-- The pure path helpers are re-exported from `nx.utils` rather than reimplemented,
-- so there is exactly one copy of the path math in the editor (CLAUDE.md puts
-- broadly-useful utilities in public `nx.utils.*`).

local M = {}

-- ----- pure path math (re-exported from nx.utils) ----------------------------
-- Aliased, not wrapped: a config reads `util.joinpath(root, "bin", cmd)` without
-- having to know which namespace each helper lives in, and there is still one
-- implementation. `vim.fs.joinpath`/`dirname`/`basename`/`normalize`/`relpath` map
-- here one-for-one.

M.joinpath = nx.utils.joinpath
M.normalize = nx.utils.normalize
M.relpath = nx.utils.relpath
M.dirname = nx.utils.dirname
M.basename = nx.utils.basename
M.ancestors = nx.utils.ancestors

-- ----- buffers ---------------------------------------------------------------

-- `util.bufname(bufnr)` -> the buffer's full path, or `""` when it has no file.
-- The replacement for `vim.api.nvim_buf_get_name`, which every upstream `root_dir`
-- opens with.
function M.bufname(bufnr)
  return nx.buf.name(bufnr)
end

-- `util.buf_command(bufnr, name, fn[, opts])` -> define a buffer-local `:Name`.
-- The replacement for `vim.api.nvim_buf_create_user_command`, which the `on_attach`
-- of ~34 upstream configs uses to hang a server-specific command off the buffers
-- that server serves (`:LspClangdSwitchSourceHeader`, `:LspEslintFixAll`, …).
-- Buffer-local is the point: the command exists only where the server does.
function M.buf_command(bufnr, name, fn, opts)
  return nx.user_command.buf_create(bufnr, name, fn, opts)
end

-- ----- the filesystem, asynchronously ----------------------------------------

-- `util.root(bufnr, markers)` -> promise of the nearest ancestor directory of the
-- buffer's file holding one of `markers`, or nil.
--
-- The replacement for `vim.fs.root(bufnr, markers)`, with the same **priority
-- tier** semantics: a flat list is one tier of equals (nearest match wins), while
-- a list of lists is several tiers, each exhausted over the whole tree before the
-- next is tried anywhere. That is what makes a package inside a monorepo attach at
-- the monorepo root rather than at its own nested `.git`.
--
-- Most configs never need this: declaring `root_markers` on the config lets
-- `nx.lsp` do the search itself. Reach for it when the root depends on something
-- the declarative form can't say — "the lockfile root, unless a Deno config is
-- nearer".
function M.root(bufnr, markers)
  return nx.lsp.find_root(bufnr, markers)
end

-- `util.find_upward(from, names)` -> promise of the full path of the first entry
-- named in `names` found at or above the directory of `from`, or nil. The
-- replacement for `vim.fs.find(names, { path = from, upward = true })[1]`.
--
-- `root` answers "which directory is the project rooted at"; this answers "where
-- is that file" — a config that needs to *read* the manifest it found (a
-- `package.json`, a `deno.json`) wants the path, not the directory.
M.find_upward = nx.async(function(from, names)
  if type(names) == "string" then
    names = { names }
  end
  local root = nx.await(M.root_of_path(from, names))
  if not root then
    return nil
  end
  -- The marker that matched is whichever of `names` is actually there; re-read the
  -- one directory rather than plumbing the winner out of the search.
  local entries = nx.await(nx.fs.readdir(root):catch(function()
    return {}
  end))
  local present = {}
  for _, e in ipairs(entries) do
    present[e.name] = true
  end
  for _, name in ipairs(names) do
    if present[name] then
      return M.joinpath(root, name)
    end
  end
  return nil
end)

-- `util.root_of_path(path, markers)` -> promise of the nearest ancestor of `path`
-- holding one of `markers`. The by-path sibling of `util.root` (which takes a
-- buffer), for a config walking up from a path it computed rather than from the
-- buffer's own file.
M.root_of_path = nx.async(function(path, markers)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  local tiers = type(markers[1]) == "table" and markers or { markers }
  for dir in M.ancestors(path) do
    local entries = nx.await(nx.fs.readdir(dir):catch(function()
      return {}
    end))
    local present = {}
    for _, e in ipairs(entries) do
      present[e.name] = true
    end
    for _, tier in ipairs(tiers) do
      for _, m in ipairs(tier) do
        if present[m] then
          return dir
        end
      end
    end
  end
  return nil
end)

-- `util.root_pattern(...)` -> `function(path) -> promise of the root`. The
-- replacement for upstream's `lspconfig.util.root_pattern`, which 33 configs use and
-- which is the one helper `util.root` can't stand in for: its markers are **globs**
-- (`*.cabal`, `*.ino`, `.gitlab*`), not exact filenames.
--
-- Matching runs through `nx.glob` — nxvim's own glob engine, compiled once per call
-- into a single set, so testing a directory's entries against ten patterns is one
-- pass. Markers may be passed varargs-style or as one list, matching upstream's two
-- calling conventions:
--
-- ```lua
-- root_dir = function(bufnr, on_dir)
--   util.root_pattern("*.cabal", "stack.yaml", ".git")(util.bufname(bufnr)):next(on_dir)
-- end,
-- ```
--
-- The returned function is async: upstream's was synchronous because it stat'd the
-- filesystem inline, which is exactly what nxvim does not do.
function M.root_pattern(...)
  local patterns = {}
  local first = select(1, ...)
  if type(first) == "table" and select("#", ...) == 1 then
    patterns = first
  else
    for i = 1, select("#", ...) do
      patterns[i] = (select(i, ...))
    end
  end
  return nx.async(function(path)
    if type(path) ~= "string" or path == "" then
      return nil
    end
    for dir in M.ancestors(path) do
      local entries = nx.await(nx.fs.readdir(dir):catch(function()
        return {}
      end))
      for _, e in ipairs(entries) do
        if nx.glob.any(patterns, e.name) then
          return dir
        end
      end
    end
    return nil
  end)
end

-- `util.exe(name)` -> `name` with the extension this platform's build of it carries.
-- On Windows a language server installed as `foo` is `foo.exe` (or, for a wrapper
-- script, `foo.bat`/`foo.cmd`); everywhere else the bare name is right. `ext`
-- defaults to `.exe`.
--
-- Prefer `util.which`, which searches `$PATH` and tells you what is actually there.
-- This is for the case upstream handles by hand: building a command name before any
-- lookup happens.
function M.exe(name, ext)
  if nx.utils.is_windows() then
    return name .. (ext or ".exe")
  end
  return name
end

-- `util.exists(path)` -> promise of a boolean. The replacement for
-- `vim.uv.fs_stat(path) ~= nil` / `vim.fn.filereadable(path) == 1`. Never rejects.
function M.exists(path)
  return nx.fs.exists(path)
end

-- `util.is_dir(path)` -> promise of a boolean: does `path` exist AND is it a
-- directory? A missing path (or any error) is false, not a rejection, so it reads
-- as a plain condition.
M.is_dir = nx.async(function(path)
  local st = nx.await(nx.fs.stat(path):catch(function()
    return nil
  end))
  return st ~= nil and st.type == "directory"
end)

-- `util.read_json(path)` -> promise of the file decoded from JSON, or nil when it
-- is missing or unparseable. Several configs branch on a manifest's contents (does
-- this `package.json` depend on vue? does this `deno.json` exist?), which upstream
-- does with a blocking read.
--
-- A malformed file resolves nil rather than raising: a config probing for optional
-- configuration should treat "unreadable" the same as "absent", and the file
-- belongs to the user's project, not to us.
M.read_json = nx.async(function(path)
  local text = nx.await(nx.fs.read_text(path):catch(function()
    return nil
  end))
  if type(text) ~= "string" or text == "" then
    return nil
  end
  local ok, decoded = pcall(nx.json.decode, text)
  return ok and decoded or nil
end)

-- ----- programs, asynchronously ----------------------------------------------

-- `util.which(name)` -> promise of the absolute path of executable `name`, or nil.
-- The replacement for the blocking `vim.fn.executable()` / `vim.fn.exepath()`.
function M.which(name)
  return nx.fs.which(name)
end

-- `util.local_bin(root, name)` -> promise of `<root>/node_modules/.bin/<name>` when
-- that exists and is executable, else nil.
--
-- The single most repeated shape in nvim-lspconfig: a JavaScript-ecosystem server
-- should run the project's own pinned copy when there is one, so that the version
-- matches the project's config, and fall back to a global install otherwise.
function M.local_bin(root, name)
  if type(root) ~= "string" or root == "" then
    return nx.promise.resolve(nil)
  end
  return M.which(M.joinpath(root, "node_modules/.bin", name))
end

-- `util.node_cmd(name[, args])` -> a `cmd` builder that prefers the project-local
-- `node_modules/.bin/<name>` and falls back to `<name>` on `$PATH`, appending
-- `args` (default `{ "--stdio" }`, which is what every one of these servers takes).
--
-- This collapses the ~24 near-identical upstream `cmd = function(dispatchers,
-- config) … end` builders into one line per config. It is an `nx.async` function,
-- so it returns a promise of the argv and `nx.lsp` awaits it — the lookup is I/O,
-- and upstream's `vim.fn.executable()` version blocks the editor to do it.
--
-- ```lua
-- cmd = util.node_cmd("vscode-eslint-language-server"),
-- cmd = util.node_cmd("vls", { "--stdio", "--clientProcessId", "0" }),
-- ```
function M.node_cmd(name, args)
  args = args or { "--stdio" }
  return nx.async(function(_dispatchers, config)
    local program = nx.await(M.local_bin((config or {}).root_dir, name)) or name
    local argv = { program }
    for _, a in ipairs(args) do
      argv[#argv + 1] = a
    end
    return argv
  end)
end

-- `util.system(cmd[, opts])` -> promise of `{ code, stdout, stderr }`. The
-- replacement for `vim.system(cmd, opts):wait()`, which blocks, and for
-- `vim.fn.system` / `vim.fn.systemlist`, which block harder.
--
-- Resolves (never rejects) even for a non-zero exit or a missing binary
-- (`code = -1`), so a config branches on `code` rather than wrapping the call.
-- `opts.cwd` and `opts.env` pass through.
function M.system(cmd, opts)
  opts = opts or {}
  return nx.run({ cmd = cmd, cwd = opts.cwd, env = opts.env, stdin = opts.stdin })
end

-- `util.output(cmd[, opts])` -> promise of the command's trimmed stdout, or nil if
-- it failed. The common shape behind a tool query (`go env GOROOT`, `rustc --print
-- sysroot`) where a failure means "fall back", not "report an error".
M.output = nx.async(function(cmd, opts)
  local r = nx.await(M.system(cmd, opts))
  if r.code ~= 0 then
    return nil
  end
  local out = (r.stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return out ~= "" and out or nil
end)

-- ----- URIs -------------------------------------------------------------------

-- `util.uri_from_path(path)` -> a `file://` URI. The replacement for
-- `vim.uri_from_fname` / `vim.uri_from_bufnr`, for a config handing a document
-- reference to a server (`workspace/executeCommand` arguments, mostly).
--
-- Percent-encodes everything outside the unreserved set, `/` excepted — a path with
-- a space or a `#` in it is otherwise a malformed URI the server silently misreads.
function M.uri_from_path(path)
  local encoded = M.normalize(path):gsub("[^%w%-%.%_%~/]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return "file://" .. encoded
end

-- `util.uri_from_buf(bufnr)` -> the buffer's `file://` URI (`""` when it has no
-- file, which is what a server should be told rather than a bogus `file://`).
function M.uri_from_buf(bufnr)
  local name = M.bufname(bufnr)
  return name == "" and "" or M.uri_from_path(name)
end

-- `util.uri_to_path(uri)` -> the filesystem path a `file://` URI names, or nil for
-- any other scheme. The replacement for `vim.uri_to_fname`.
function M.uri_to_path(uri)
  if type(uri) ~= "string" then
    return nil
  end
  local path = uri:match("^file://(.*)$")
  if not path then
    return nil
  end
  return (path:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

return M
