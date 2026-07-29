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

-- `util.cwd()` -> the editor's effective working directory, absolute and with no
-- trailing separator. The replacement for `vim.fn.getcwd()` / `vim.uv.cwd()`, which
-- a dozen configs use as the fallback root ("no marker found — attach where the user
-- is working"). Over a daemon this is the *daemon's* cwd, which is the one relative
-- paths actually resolve against.
function M.cwd()
  return nx.cwd()
end

-- `util.home()` -> the user's home directory. The replacement for
-- `vim.uv.os_homedir()`, which a few servers use as the root for a file that belongs
-- to no project (an `.R` script, a `.nix` expression edited in isolation).
function M.home()
  return nx.utils.expanduser("~")
end

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

-- The candidate directories an upward search visits, nearest first, paired with a
-- memoized listing of each. `path` may name a file or a directory — upstream's
-- `vim.fs.root` / `vim.fs.find` take either, and configs pass both (a buffer's file; a
-- directory another probe just found). A directory is a candidate for holding its own
-- markers, so it leads the list; `ancestors` starts at the *parent*, which for a
-- directory would skip it. Listing a file simply comes back empty, so the two need not
-- be told apart, and no extra stat is spent doing so.
--
-- The listing is read once per directory and reused, so a multi-tier search re-walks
-- cached entries rather than re-reading the tree: N listings for any number of tiers,
-- not N per tier. (`nx.lsp.find_root` does the same thing engine-side.)
local function scan_upward(path)
  local dirs = { path }
  for dir in M.ancestors(path) do
    dirs[#dirs + 1] = dir
  end
  local cache = {}
  local entries_of = nx.async(function(dir)
    local hit = cache[dir]
    if not hit then
      hit = nx.await(nx.fs.readdir(dir):catch(function()
        return {}
      end))
      cache[dir] = hit
    end
    return hit
  end)
  return dirs, entries_of
end

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

-- `util.root_dir(fn)` -> a `root_dir` whose body may `nx.await`.
--
-- `fn(bufnr, on_dir)` runs as an async body: await as much I/O as the decision needs,
-- then call `on_dir(dir)` — or **return without calling it** to DECLINE the buffer
-- outright, which is how a config says "this file belongs to a different server"
-- (ts_ls stepping aside for a Deno tree, biome for a project not configured to use it).
--
-- Declining and "found no root" are different answers, and that is the whole reason
-- this wrapper exists rather than just returning the directory from an `nx.async`:
-- `nx.lsp` reads a promise resolving nil as the latter and starts the server rootless.
-- Returning nothing from here says nothing at all. Reach for the plain
-- `nx.async(function(bufnr) … return dir end)` shape when a config never declines.
--
-- A body that errors is reported against the config rather than surfacing as an
-- unhandled rejection with no name attached to it.
function M.root_dir(fn)
  local body = nx.async(fn)
  return function(bufnr, on_dir)
    body(bufnr, on_dir):catch(function(err)
      nx.notify("nxvim-lspconfig: root_dir failed: " .. tostring(err), nx.log.levels.ERROR)
    end)
  end
end

-- `util.find_upward(from, names[, opts])` -> promise of the full path of the first entry
-- named in `names` found at or above the directory of `from`, or nil. The
-- replacement for `vim.fs.find(names, { path = from, upward = true })[1]`.
--
-- `root` answers "which directory is the project rooted at"; this answers "where
-- is that file" — a config that needs to *read* the manifest it found (a
-- `package.json`, a `deno.json`) wants the path, not the directory.
M.find_upward = nx.async(function(from, names, opts)
  opts = opts or {}
  return nx.await(M.find_upward_all(from, names, { limit = 1, stop = opts.stop }))[1]
end)

-- `util.find_upward_all(from, names[, opts])` -> promise of EVERY path named in
-- `names` at or above the directory of `from`, nearest first. The replacement for
-- `vim.fs.find(names, { upward = true, … })`. `opts.limit` caps the result (default:
-- all); `opts.stop` names a directory the walk stops *before* reaching, which is how a
-- config asks "is this file's own project using me?" without the answer leaking in
-- from an unrelated project higher up the tree.
--
-- The plural matters for the layouts where the *outermost* match is the answer: an
-- Elixir umbrella app has a `mix.exs` per sub-app and one at the umbrella root, and the
-- server must attach at the umbrella. Asking for two and preferring the second is how
-- upstream expresses that.
M.find_upward_all = nx.async(function(from, names, opts)
  if type(names) == "string" then
    names = { names }
  end
  opts = opts or {}
  local found = {}
  local dirs, entries_of = scan_upward(from)
  for _, dir in ipairs(dirs) do
    if opts.stop and dir == opts.stop then
      return found
    end
    local present = {}
    for _, e in ipairs(nx.await(entries_of(dir))) do
      present[e.name] = true
    end
    for _, name in ipairs(names) do
      if present[name] then
        found[#found + 1] = M.joinpath(dir, name)
        if opts.limit and #found >= opts.limit then
          return found
        end
      end
    end
  end
  return found
end)

-- `util.root_of_path(path, markers)` -> promise of the nearest ancestor of `path`
-- holding one of `markers`. The by-path sibling of `util.root` (which takes a
-- buffer), for a config walking up from a path it computed rather than from the
-- buffer's own file.
M.root_of_path = nx.async(function(path, markers)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  if type(markers) == "string" then
    markers = { markers }
  end
  local tiers = type(markers[1]) == "table" and markers or { markers }
  local dirs, entries_of = scan_upward(path)
  for _, tier in ipairs(tiers) do
    for _, dir in ipairs(dirs) do
      local present = {}
      for _, e in ipairs(nx.await(entries_of(dir))) do
        present[e.name] = true
      end
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
-- Matching runs through `nx.glob` — nxvim's own glob engine, which caches each
-- pattern's compiled form, so a walk that tests hundreds of directory entries compiles
-- nothing after the first. Markers may be passed varargs-style or as one list,
-- matching upstream's two calling conventions:
--
-- ```lua
-- root_dir = function(bufnr, on_dir)
--   util.root_pattern("*.cabal", "stack.yaml", ".git")(util.bufname(bufnr)):next(on_dir)
-- end,
-- ```
--
-- **Pattern order is priority**, exactly as upstream: each pattern is searched over
-- the whole tree before the next is tried anywhere, so a `*.cabal` six directories up
-- beats a `.git` one directory up. That is what makes the conventional trailing
-- `".git"` a *fallback* rather than a competitor — read the argument list as
-- `util.root` reads priority tiers, one tier per pattern.
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
    local dirs, entries_of = scan_upward(path)
    for _, pattern in ipairs(patterns) do
      for _, dir in ipairs(dirs) do
        for _, e in ipairs(nx.await(entries_of(dir))) do
          if nx.glob.match(pattern, e.name) then
            return dir
          end
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

-- Does `text` mention every / any of `patterns`? Patterns are Lua patterns, matched
-- line-wise the way upstream matches them (`line:find(s)`), because that is what the
-- configs pass: `"vite%-plus"`, `"tailwind"`, `"lint:"`.
local function text_mentions(text, patterns, mode)
  if mode == "all" then
    for _, p in ipairs(patterns) do
      if not text:find(p) then
        return false
      end
    end
    return #patterns > 0
  end
  for _, p in ipairs(patterns) do
    if text:find(p) then
      return true
    end
  end
  return false
end

-- `util.root_markers_with_field(root_files, new_names, field, fname[, match_mode])`
-- -> promise of `root_files` with each of `new_names` appended **when the nearest
-- such file above `fname` actually mentions `field`**.
--
-- The shape behind "attach at the package that declares me": a `package.json` only
-- roots a tailwindcss server if it depends on tailwindcss, otherwise every JS project
-- in the tree would look like a tailwind project. `field` is one Lua pattern or a
-- list; `match_mode` is `"any"` (default) or `"all"` — every pattern must appear.
--
-- Async, and a rewrite rather than a rename: upstream reads the manifest with a
-- blocking `io.open`, inside a `root_dir` that runs on every buffer open.
M.root_markers_with_field = nx.async(function(root_files, new_names, field, fname, match_mode)
  local fields = type(field) == "string" and { field } or field
  for _, name in ipairs(new_names) do
    local found = nx.await(M.find_upward(fname, { name }))
    if found then
      local text = nx.await(nx.fs.read_text(found):catch(function()
        return nil
      end))
      if type(text) == "string" and text_mentions(text, fields, match_mode) then
        root_files[#root_files + 1] = name
      end
    end
  end
  return root_files
end)

-- `util.insert_package_json(root_files, field, fname)` -> promise of `root_files`
-- with `package.json` / `package.json5` appended when the nearest one declares
-- `field`. The `root_markers_with_field` special case ~10 JavaScript-ecosystem
-- configs use verbatim.
function M.insert_package_json(root_files, field, fname)
  return M.root_markers_with_field(root_files, { "package.json", "package.json5" }, field, fname)
end

-- `util.get_typescript_server_path(root_dir)` -> promise of the `typescript/lib`
-- directory of the nearest `node_modules` above `root_dir` that actually contains
-- TypeScript, or `""` when there is none.
--
-- The servers built on the TypeScript language service (astro, mdx_analyzer, volar and
-- friends) load `tsserverlibrary.js` themselves and need to be told where it is, so
-- that a project is analyzed by the TypeScript version it pins rather than by whatever
-- the server bundles. `""` — not nil — is the "use your own" answer those servers
-- expect, which is why it isn't a rejection.
--
-- The search skips a `node_modules` without TypeScript in it, so a nested package that
-- has its own dependencies but not TS resolves to the workspace's copy.
M.get_typescript_server_path = nx.async(function(root_dir)
  if type(root_dir) ~= "string" or root_dir == "" then
    return ""
  end
  for dir in M.ancestors(M.joinpath(root_dir, "_")) do
    local typescript_path = M.joinpath(dir, "node_modules/typescript")
    if nx.await(M.is_dir(typescript_path)) then
      return M.joinpath(typescript_path, "lib")
    end
  end
  return ""
end)

-- `util.tabsize([bufnr])` -> the width one indent level is rendered at in `bufnr`
-- (default: the current buffer). The replacement for
-- `vim.lsp.util.get_effective_tabstop`, with the same rule: `'shiftwidth'`, or
-- `'tabstop'` when `'shiftwidth'` is 0 (which is what a 0 there MEANS — "follow
-- tabstop").
--
-- A server that formats or emits indented completions has to be told this, or its
-- output is indented to its own default and every edit it makes fights the file.
function M.tabsize(bufnr)
  local bo = nx.bo[bufnr or 0]
  local sw = bo.shiftwidth
  if sw and sw > 0 then
    return sw
  end
  return bo.tabstop
end

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
