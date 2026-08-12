-- `util.*` — the helper surface every bundled config is written against.
--
-- `configs_spec.lua` runs all 407 configs, but it runs them against whatever tree the
-- test happens to sit in: nothing there has a `node_modules`, a lockfile, or two
-- competing markers at different depths, so every probe takes its "found nothing"
-- path and the helpers' actual DECISIONS — which of two candidate roots wins, whether
-- the project's own binary is preferred over `$PATH` — are never made.
--
-- This suite builds the trees those decisions need and asserts the answer. It is the
-- half that would otherwise be checked only by a user with the right project layout:
-- picking the wrong root or the wrong binary doesn't fail, it silently analyzes the
-- wrong thing (a monorepo package linted by the root's config; a project checked by a
-- globally-installed server two majors newer than the one it pins).

local util = require("bemtvi-lspconfig.util")

-- ----- fixtures ---------------------------------------------------------------

local function mkdir(path)
  btv.await(btv.fs.mkdir(path, { recursive = true }))
  return path
end

local function write(path, text)
  mkdir(util.dirname(path))
  btv.await(btv.fs.write(path, text or ""))
  return path
end

-- A file the OS will actually run. `util.local_bin` goes through `btv.fs.which`, which
-- for an explicit path answers only when the file is executable — so a fixture written
-- 644 is a *negative* fixture, not a broken one, and both are used below.
local function write_exe(path, text)
  write(path, text or "#!/bin/sh\nexit 0\n")
  btv.await(btv.run({ cmd = { "chmod", "+x", path } }))
  return path
end

-- The tree the root-resolution tests share:
--
--   <root>/pkg.cabal                  a GLOB marker, only at the top
--   <root>/mix.exs                    the umbrella manifest
--   <root>/.git/                      the conventional fallback, at the top
--   <root>/sub/mix.exs                the sub-app manifest
--   <root>/sub/.git/                  a NEARER .git, to be beaten by priority
--   <root>/sub/deep/file.ts           where every probe starts
--
-- The two `.git` directories are the point: a helper that merely walks up and returns
-- the first hit finds `sub`, and every priority assertion below distinguishes that
-- from the tier-respecting answer.
local function project()
  local root = btv.test.tempdir()
  write(util.joinpath(root, "pkg.cabal"))
  write(util.joinpath(root, "mix.exs"))
  mkdir(util.joinpath(root, ".git"))
  write(util.joinpath(root, "sub", "mix.exs"))
  mkdir(util.joinpath(root, "sub", ".git"))
  local file = write(util.joinpath(root, "sub", "deep", "file.ts"))
  return root, file
end

btv.test.describe("bemtvi-lspconfig: util", function()
  -- ----- cmd resolution -------------------------------------------------------

  btv.test.it("node_cmd runs the project's own copy when it has one", function()
    local root = btv.test.tempdir()
    local bin = write_exe(util.joinpath(root, "node_modules/.bin/tsserver"))

    local argv = btv.await(util.node_cmd("tsserver")({}, { root_dir = root }))

    btv.test.expect(argv).to_equal({ bin, "--stdio" })
  end)

  btv.test.it("node_cmd falls back to $PATH when the local copy is not executable", function()
    -- A `node_modules/.bin` entry that exists but isn't runnable (a stale checkout, a
    -- dependency installed without its bin links). Spawning it would fail; the bare
    -- name at least reaches a global install.
    local root = btv.test.tempdir()
    write(util.joinpath(root, "node_modules/.bin/tsserver"), "not executable\n")

    local argv = btv.await(util.node_cmd("tsserver")({}, { root_dir = root }))

    btv.test.expect(argv).to_equal({ "tsserver", "--stdio" })
  end)

  btv.test.it("node_cmd falls back when the buffer has no root at all", function()
    -- A single file opened outside any project: `btv.lsp` passes a config whose
    -- `root_dir` is nil, and the builder must still produce an argv rather than error.
    local argv = btv.await(util.node_cmd("vls", { "--stdio", "--clientProcessId", "0" })({}, {}))

    btv.test.expect(argv).to_equal({ "vls", "--stdio", "--clientProcessId", "0" })
  end)

  btv.test.it("local_bin answers nil rather than a path that isn't there", function()
    local root = btv.test.tempdir()
    btv.test.expect(btv.await(util.local_bin(root, "tsserver"))).to_be_nil()
    btv.test.expect(btv.await(util.local_bin(nil, "tsserver"))).to_be_nil()
  end)

  -- ----- root resolution ------------------------------------------------------

  btv.test.it("root_pattern exhausts each pattern before trying the next", function()
    local root, file = project()

    -- `pkg.cabal` is two directories further up than `sub/.git`, and still wins:
    -- argument order is priority, so the trailing `.git` is a fallback, not a
    -- competitor. This is what attaches a package inside a monorepo at the monorepo.
    btv.test.expect(btv.await(util.root_pattern("*.cabal", ".git")(file))).to_be(root)
  end)

  btv.test.it("...and with the order reversed, the nearer .git wins", function()
    local root, file = project()

    -- The same tree, the same two markers: only the priority changed. Without the
    -- tier behavior both orders would answer `sub`, so this is the assertion that
    -- makes the one above mean something.
    btv.test
      .expect(btv.await(util.root_pattern(".git", "*.cabal")(file)))
      .to_be(util.joinpath(root, "sub"))
  end)

  btv.test.it("root_pattern matches globs, and takes one list as well as varargs", function()
    local root, file = project()

    -- `*.cabal` is a pattern, not a filename — the reason `root_pattern` exists
    -- alongside the declarative `root_markers`, which are exact names.
    btv.test.expect(btv.await(util.root_pattern({ "*.cabal" })(file))).to_be(root)
    btv.test.expect(btv.await(util.root_pattern("*.nothing-here")(file))).to_be_nil()
  end)

  btv.test.it("root_pattern starts at the directory itself, not its parent", function()
    local root = project()
    -- Handed a directory rather than a file: the directory is a candidate for holding
    -- its own markers, so a `.git` in it roots there instead of one level up.
    btv.test
      .expect(btv.await(util.root_pattern(".git")(util.joinpath(root, "sub"))))
      .to_be(util.joinpath(root, "sub"))
  end)

  btv.test.it("root_of_path exhausts each tier over the whole tree", function()
    local root, file = project()

    -- The list-of-lists form of the same rule, this time with exact names.
    btv.test.expect(btv.await(util.root_of_path(file, { { "pkg.cabal" }, { ".git" } }))).to_be(root)
    btv.test
      .expect(btv.await(util.root_of_path(file, { ".git", "pkg.cabal" })))
      .to_be(util.joinpath(root, "sub"))
    btv.test.expect(btv.await(util.root_of_path(file, { "no-such-marker" }))).to_be_nil()
  end)

  -- ----- upward file search ---------------------------------------------------

  btv.test.it("find_upward returns the nearest match, find_upward_all all of them", function()
    local root, file = project()

    -- An Elixir umbrella: a `mix.exs` per sub-app and one at the umbrella root. The
    -- nearest is the sub-app; the config that must attach at the umbrella asks for
    -- both and takes the last.
    btv.test
      .expect(btv.await(util.find_upward(file, { "mix.exs" })))
      .to_be(util.joinpath(root, "sub", "mix.exs"))

    local all = btv.await(util.find_upward_all(file, "mix.exs"))
    btv.test.expect(all).to_equal({
      util.joinpath(root, "sub", "mix.exs"),
      util.joinpath(root, "mix.exs"),
    })
  end)

  btv.test.it("find_upward_all honors limit and stops before the directory named", function()
    local root, file = project()

    btv.test.expect(#btv.await(util.find_upward_all(file, "mix.exs", { limit = 1 }))).to_be(1)

    -- `stop` is how a config asks "is THIS project using me?" without an unrelated
    -- project higher up answering for it: the walk never reaches the root's manifest.
    local bounded = btv.await(util.find_upward_all(file, "mix.exs", { stop = root }))
    btv.test.expect(bounded).to_equal({ util.joinpath(root, "sub", "mix.exs") })
  end)

  -- ----- manifests ------------------------------------------------------------

  btv.test.it("insert_package_json adds package.json only when it declares the field", function()
    local root = btv.test.tempdir()
    local file = write(util.joinpath(root, "src", "app.css"))
    write(
      util.joinpath(root, "package.json"),
      '{ "devDependencies": { "tailwindcss": "^3.4.0" } }\n'
    )

    -- Without the mention every JavaScript project in the tree would look like a
    -- tailwind project and the server would root at the wrong package.
    btv.test.expect(btv.await(util.insert_package_json({ ".git" }, "tailwindcss", file))).to_equal({
      ".git",
      "package.json",
    })
    btv.test.expect(btv.await(util.insert_package_json({ ".git" }, "vite%-plus", file))).to_equal({
      ".git",
    })
  end)

  btv.test.it("root_markers_with_field can require every pattern", function()
    local root = btv.test.tempdir()
    local file = write(util.joinpath(root, "src", "app.js"))
    write(util.joinpath(root, "package.json"), '{ "scripts": { "lint:js": "eslint ." } }\n')

    local names = { "package.json" }
    btv.test
      .expect(btv.await(util.root_markers_with_field({}, names, { "lint:", "eslint" }, file, "all")))
      .to_equal({ "package.json" })
    btv.test
      .expect(btv.await(util.root_markers_with_field({}, names, { "lint:", "stylelint" }, file, "all")))
      .to_equal({})
  end)

  btv.test.it("read_json decodes, and treats an unreadable file as absent", function()
    local root = btv.test.tempdir()
    local good = write(util.joinpath(root, "deno.json"), '{ "lint": true }\n')
    local bad = write(util.joinpath(root, "broken.json"), "{ not json\n")

    btv.test.expect(btv.await(util.read_json(good)).lint).to_be(true)
    -- Malformed and missing answer the same way: the file belongs to the user's
    -- project, and a config probing for optional configuration should just move on.
    btv.test.expect(btv.await(util.read_json(bad))).to_be_nil()
    btv.test.expect(btv.await(util.read_json(util.joinpath(root, "absent.json")))).to_be_nil()
  end)

  btv.test.it("get_typescript_server_path skips a node_modules without TypeScript", function()
    local root = btv.test.tempdir()
    -- The workspace pins TypeScript; the nested package has its own dependencies but
    -- not TS. The nested one must not shadow the copy that actually exists.
    mkdir(util.joinpath(root, "node_modules/typescript/lib"))
    mkdir(util.joinpath(root, "packages/app/node_modules/other"))

    btv.test
      .expect(btv.await(util.get_typescript_server_path(util.joinpath(root, "packages/app"))))
      .to_be(util.joinpath(root, "node_modules/typescript/lib"))

    -- `""`, not nil: the servers that take this path read it as "use your own copy".
    btv.test.expect(btv.await(util.get_typescript_server_path(""))).to_be("")
  end)

  btv.test.it("is_dir tells a directory from a file, and never rejects", function()
    local root = btv.test.tempdir()
    local file = write(util.joinpath(root, "file.txt"))

    btv.test.expect(btv.await(util.is_dir(root))).to_be(true)
    btv.test.expect(btv.await(util.is_dir(file))).to_be(false)
    btv.test.expect(btv.await(util.is_dir(util.joinpath(root, "absent")))).to_be(false)
  end)

  -- ----- subprocesses ---------------------------------------------------------

  btv.test.it("output trims stdout, and answers nil when the command fails", function()
    -- The shape behind `go env GOROOT` / `rustc --print sysroot`: a failure means
    -- "fall back to the default", not "report an error".
    btv.test
      .expect(btv.await(util.output({ "sh", "-c", "printf '  /usr/local/go \\n'" })))
      .to_be("/usr/local/go")
    btv.test.expect(btv.await(util.output({ "sh", "-c", "exit 3" }))).to_be_nil()
    btv.test.expect(btv.await(util.output({ "bemtvi-no-such-program-xyzzy" }))).to_be_nil()
  end)

  btv.test.it("system resolves a non-zero exit rather than rejecting", function()
    local r = btv.await(util.system({ "sh", "-c", "printf oops >&2; exit 2" }))
    btv.test.expect(r.code).to_be(2)
    btv.test.expect(r.stderr).to_match("oops")
  end)

  -- ----- root_dir wrapper -----------------------------------------------------

  btv.test.it("root_dir passes the answer to on_dir, and declining calls nothing", function(t)
    local file = select(2, project())
    t:cmd("edit " .. file)
    local bufnr = btv.buf.current()

    local answered
    util.root_dir(function(buf, on_dir)
      on_dir(btv.await(util.root_pattern("*.cabal")(util.bufname(buf))))
    end)(bufnr, function(dir)
      answered = dir
    end)
    t:wait_for(function()
      return answered ~= nil
    end)
    btv.test.expect(answered).to_match("[^/]$")

    -- Declining — returning without calling back — is a DIFFERENT answer from "found
    -- no root": it means another server owns this buffer, and `btv.lsp` must not start
    -- this one rootless.
    local called = false
    util.root_dir(function() end)(bufnr, function()
      called = true
    end)
    t:sleep(50)
    btv.test.expect(called).to_be(false)
  end)

  -- ----- URIs -----------------------------------------------------------------

  btv.test.it("uri_from_path percent-encodes, and uri_to_path round-trips it", function()
    local path = "/tmp/my project/a#b.tex"
    local uri = util.uri_from_path(path)

    -- A space or a `#` left raw makes a URI the server silently misreads — `#b.tex`
    -- becomes a fragment and the document it opens is a different file.
    btv.test.expect(uri).to_be("file:///tmp/my%20project/a%23b.tex")
    btv.test.expect(util.uri_to_path(uri)).to_be(path)
  end)

  btv.test.it("uri_to_path declines a scheme that isn't a file", function()
    -- `deno:` / `jdt:` virtual documents have no path at all; answering one would
    -- send the server an edit against a file that does not exist.
    btv.test.expect(util.uri_to_path("deno:/asset/lib.deno.d.ts")).to_be_nil()
    btv.test.expect(util.uri_to_path(nil)).to_be_nil()
  end)

  -- ----- buffer facts ---------------------------------------------------------

  btv.test.it("tabsize follows tabstop when shiftwidth is 0", function(t)
    t:cmd("set shiftwidth=3 tabstop=8")
    btv.test.expect(util.tabsize()).to_be(3)

    -- A 0 `'shiftwidth'` MEANS "follow tabstop", so reporting 0 to a formatting
    -- server would have it indent everything to column zero.
    t:cmd("set shiftwidth=0")
    btv.test.expect(util.tabsize()).to_be(8)
  end)
end)
