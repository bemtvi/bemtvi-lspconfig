-- Generate doc/configs.md + doc/configs.txt — the per-server reference — from the
-- 407 files in lsp/.
--
--     nxvim --lua scripts/docgen.lua        # from the repo root
--     bash scripts/gen-configs.sh           # …or the wrapper, which finds the root
--
-- Ported from upstream nvim-lspconfig's `scripts/docgen.lua`, which ran under
-- `nvim -l` against `vim.fs` / `vim.inspect` / `vim.version`. This runs under nxvim
-- itself, against `nx.*` — the same rule the configs it documents follow.
--
-- Why it exists at all: each `lsp/<name>.lua` carries a `---@brief` block saying how
-- to install that server, what its settings mean, and what its config assumes.
-- Without this page that prose is reachable only by opening the source file, which
-- is not where anyone looks for "how do I install clangd".
--
-- ## Determinism
--
-- A config table is rendered by LOADING it, and a handful of configs read host facts
-- at load time (`nx.stdpath`, `nx.version`, `nx.env.get`, `~`). Left alone, the
-- generated page would carry the generating machine's home directory and version —
-- different on every developer's checkout, so the committed file could never be
-- checked for freshness, and `/home/<someone>` would ship in the docs. So those
-- facts are frozen to fixed placeholders for the duration of the load. Upstream hit
-- the same wall and stubbed `vim.fn.getpid` / `vim.version` the same way.
--
-- Table rendering is ours rather than `nx.inspect`, for two reasons: `nx.inspect`
-- prints a list as `{ 1 = "x" }`, which is not valid Lua on a page people copy from,
-- and it does not promise a key order — and an unstable key order is the same
-- freshness problem in a different coat.

local root = nx.cwd()
if not nx.await(nx.fs.exists(root .. "/lsp")) then
  error("docgen: run me from the repo root (no lsp/ under " .. root .. ")")
end
nx._add_rtp(root)

-- ----- deterministic host facts ----------------------------------------------

-- The placeholders that stand in for this machine while configs are loaded. Chosen
-- to look obviously like placeholders in the rendered page rather than like a path
-- someone should type.
local FAKE = {
  home = "/home/user",
  data = "/home/user/.local/share/nxvim",
  cache = "/home/user/.cache/nxvim",
  state = "/home/user/.local/state/nxvim",
  config = "/home/user/.config/nxvim",
  log = "/home/user/.local/state/nxvim",
  cwd = "/home/user/project",
  version = "nxvim 0.1.0",
  pid = 12345,
}

-- Swap the host facts for placeholders, returning a function that puts them back.
-- `nx.env.get` answers nil throughout: a config's *default* is what it does with no
-- environment set, and that is exactly what this page documents.
local function freeze_host()
  local real = {
    stdpath = nx.stdpath,
    version = nx.version,
    pid = nx.pid,
    cwd = nx.cwd,
    env_get = nx.env.get,
    expanduser = nx.utils.expanduser,
  }
  nx.stdpath = function(what)
    return FAKE[what] or (FAKE.data .. "/" .. tostring(what))
  end
  nx.version = function()
    return FAKE.version
  end
  nx.pid = function()
    return FAKE.pid
  end
  nx.cwd = function()
    return FAKE.cwd
  end
  nx.env.get = function()
    return nil
  end
  nx.utils.expanduser = function(p)
    if type(p) ~= "string" then
      return p
    end
    return (p:gsub("^~", FAKE.home))
  end
  return function()
    nx.stdpath, nx.version, nx.pid, nx.cwd = real.stdpath, real.version, real.pid, real.cwd
    nx.env.get, nx.utils.expanduser = real.env_get, real.expanduser
  end
end

-- ----- rendering a config value as valid, stable Lua ---------------------------

local KEYWORDS = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["false"] = true,
  ["for"] = true,
  ["function"] = true,
  ["goto"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["nil"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["true"] = true,
  ["until"] = true,
  ["while"] = true,
}

-- `k` written the way it would be written in a table constructor: bare when it is a
-- plain identifier, bracketed otherwise (`["rust-analyzer"]`, which is most of the
-- settings keys in this repo).
local function render_key(k)
  if type(k) == "string" and k:match("^[%a_][%w_]*$") and not KEYWORDS[k] then
    return k
  end
  return "[" .. string.format("%q", tostring(k)) .. "]"
end

-- Is `t` a pure list (1..n, no other keys)? Lists render on one line where short,
-- which is what almost every `cmd` and `filetypes` is.
local function is_list(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n == #t
end

local render_value

-- The parts with their leading indentation removed, for the one-line form.
local function undent_all(parts)
  local out = {}
  for i, p in ipairs(parts) do
    out[i] = (p:gsub("^%s+", ""))
  end
  return out
end

-- Sorted keys, so two runs of this script produce byte-identical output. Lua's
-- `pairs` order is unspecified and does move between runs.
local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then
      return tostring(a) < tostring(b)
    end
    return type(a) < type(b)
  end)
  return keys
end

-- `v` as a Lua literal, indented by `depth` levels. Functions never reach here —
-- they are documented by source location instead (see `render_default`).
render_value = function(v, depth)
  local pad = string.rep("  ", depth)
  local t = type(v)
  if t == "string" then
    return string.format("%q", v)
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  elseif t == "function" then
    return "<function>"
  elseif t ~= "table" then
    return tostring(v)
  end
  -- The two JSON values Lua cannot express as themselves. Rendered under the names
  -- a config would actually write, since `{}` here would be a lie in both cases.
  if v == nx.json.null then
    return "nx.json.null"
  end
  if next(v) == nil then
    return "nx.json.empty_object()"
  end
  local parts = {}
  if is_list(v) then
    for _, item in ipairs(v) do
      parts[#parts + 1] = pad .. "  " .. render_value(item, depth + 1)
    end
  else
    for _, k in ipairs(sorted_keys(v)) do
      parts[#parts + 1] = pad .. "  " .. render_key(k) .. " = " .. render_value(v[k], depth + 1)
    end
  end
  local one_line = "{ " .. table.concat(undent_all(parts), ", ") .. " }"
  if #one_line <= 66 and not one_line:find("\n") then
    return one_line
  end
  return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. pad .. "}"
end

-- ----- the `---@brief` block ---------------------------------------------------

-- The doc comment at the top of a config file, with the `---` prefixes stripped.
-- Everything after the last `---` line is code, and is dropped.
local function extract_brief(text)
  local doc = text:match("%-%-%-@brief\n(.-)\n[^%-]")
  if not doc then
    return ""
  end
  local lines = {}
  for line in (doc .. "\n"):gmatch("(.-)\n") do
    if line:match("^%-%-%-?$") then
      lines[#lines + 1] = ""
    else
      local stripped = line:match("^%-%-%-? ?(.*)$")
      if not stripped then
        break
      end
      lines[#lines + 1] = stripped
    end
  end
  -- Trim leading/trailing blank lines.
  while lines[1] == "" do
    table.remove(lines, 1)
  end
  while lines[#lines] == "" do
    table.remove(lines)
  end
  return table.concat(lines, "\n")
end

-- A markdown ```lua fence becomes a vimdoc `>lua` … `<` region, with the body
-- indented two columns the way `:help` writes code.
local function fences_to_vimdoc(doc)
  return (
    doc:gsub("```(%w*)\n(.-)```", function(lang, code)
      local body = code:gsub("\n$", ""):gsub("[^\n]+", "  %0")
      return ">" .. lang .. "\n" .. body .. "\n<"
    end)
  )
end

-- ----- one server's section ----------------------------------------------------

-- The 1-based line in `text` where `key` is assigned, for a value this page cannot
-- print (a function). Falls back to the `return` line — a reader who lands there
-- still finds the table the key belongs to.
local function key_line(text, key)
  local n = 0
  local return_line = 1
  for line in (text .. "\n"):gmatch("(.-)\n") do
    n = n + 1
    if line:match("^%s*" .. key .. "%s*=") then
      return n
    end
    if return_line == 1 and line:match("^return") then
      return_line = n
    end
  end
  return return_line
end

-- The "Default config" list for one server: every key it actually sets, in a stable
-- order, with functions pointed at rather than printed.
local function render_default(cfg, name, text, markdown)
  local out = {}
  for _, k in ipairs(sorted_keys(cfg)) do
    local v = cfg[k]
    if type(v) == "function" then
      local line = key_line(text, k)
      if markdown then
        out[#out + 1] = ("- `%s`: [../lsp/%s.lua:%d](../lsp/%s.lua#L%d)"):format(
          k,
          name,
          line,
          name,
          line
        )
      else
        out[#out + 1] = ('- %s (use "gF" to view): ../lsp/%s.lua:%d'):format(k, name, line)
      end
    elseif markdown then
      out[#out + 1] = ("- `%s`:\n  ```lua\n%s\n  ```"):format(
        k,
        (render_value(v, 0):gsub("[^\n]+", "  %0"))
      )
    else
      out[#out + 1] = ("- %s: >lua\n%s\n<"):format(k, (render_value(v, 0):gsub("[^\n]+", "  %0")))
    end
  end
  if #out == 0 then
    return markdown and "_(nothing set by default.)_" or "(nothing set by default.)"
  end
  return table.concat(out, "\n")
end

local function section(name, cfg, err, text, markdown)
  local brief = extract_brief(text)
  if not markdown then
    brief = fences_to_vimdoc(brief)
  end
  local body
  if err then
    -- A config that refuses to load says why, in place of its defaults — the
    -- fail-loud convention, carried onto the page rather than hidden by it.
    body = ("This config could not be loaded:\n\n%s"):format(tostring(err))
  else
    body = "Default config:\n" .. render_default(cfg, name, text, markdown)
  end
  if markdown then
    return table.concat({
      "## " .. name,
      "",
      brief ~= "" and (brief .. "\n") or "",
      "Enable it:",
      "",
      "```lua",
      ("nx.lsp.enable(%q)"):format(name),
      "```",
      "",
      body,
      "",
      "---",
      "",
    }, "\n")
  end
  -- The right-flushed tag is what makes `:help lspconfig-clangd` land here. Upstream
  -- tagged only the page as a whole and left `gO` to find the rest; a tag per server
  -- is the thing a reader actually wants to type.
  local tag = ("*lspconfig-%s*"):format(name)
  return table.concat({
    string.rep("-", 78),
    ("%s%s%s"):format(name, string.rep(" ", math.max(1, 78 - #name - #tag)), tag),
    "",
    brief ~= "" and (brief .. "\n") or "",
    "Enable it: >lua",
    ("  nx.lsp.enable(%q)"):format(name),
    "<",
    "",
    body,
    "",
  }, "\n")
end

-- ----- drive --------------------------------------------------------------------

local entries = nx.await(nx.fs.readdir(root .. "/lsp"))
local names = {}
for _, e in ipairs(entries) do
  local n = e.name:match("^(.*)%.lua$")
  if n then
    names[#names + 1] = n
  end
end
table.sort(names)

local unfreeze = freeze_host()
local md, txt = {}, {}
local toc = {}
for _, name in ipairs(names) do
  local path = root .. "/lsp/" .. name .. ".lua"
  local text = nx.await(nx.fs.read_text(path))
  local chunk, load_err = loadfile(path)
  local cfg, err
  if chunk then
    local ok, res = pcall(chunk)
    if ok and type(res) == "table" then
      cfg = res
    else
      err = res
    end
  else
    err = load_err
  end
  md[#md + 1] = section(name, cfg or {}, err, text, true)
  txt[#txt + 1] = section(name, cfg or {}, err, text, false)
  toc[#toc + 1] = ("- [%s](#%s)"):format(name, name)
end
unfreeze()

local MD_HEADER = [[
<!-- GENERATED by scripts/docgen.lua from the files in lsp/. Do not edit by hand;
     edit the `---@brief` block in the config itself and regenerate. -->

# Server configs

Every language server this plugin ships a config for, with its install notes and the
defaults it sets. Read it in the editor with `:help lspconfig-all`, or jump straight
to one server with `:help lspconfig-<name>` (e.g. `:help lspconfig-clangd`).

Enable any of them with `nx.lsp.enable("<name>")`; override with `nx.lsp.config`. See
[nxvim-lspconfig.md](./nxvim-lspconfig.md) for the plugin itself.

]]

local TXT_HEADER = [[
*configs.txt*                    Every language server config nxvim-lspconfig ships

                                                                *lspconfig-all*

Every language server this plugin ships a config for, with its install notes and
the defaults it sets. Jump to one with `:help lspconfig-<name>`, e.g.
>
    :help lspconfig-clangd
<
Enable any of them with `nx.lsp.enable("<name>")`; override with `nx.lsp.config`.
See |nxvim-lspconfig| for the plugin itself.

                                      Type |gO| to see the table of contents.

]]

local TXT_FOOTER = [[

==============================================================================
vim:tw=78:ts=8:ft=help:norl:
]]

-- Strip trailing whitespace. Converting a fenced block leaves it on the blank lines
-- inside the fence, and a help file with trailing blanks trips every linter that
-- looks at one.
local function clean(s)
  return (s:gsub("[ \t]+\n", "\n"))
end

nx.await(
  nx.fs.write(
    root .. "/doc/configs.md",
    clean(MD_HEADER .. table.concat(toc, "\n") .. "\n\n" .. table.concat(md, "\n"))
  )
)
nx.await(
  nx.fs.write(
    root .. "/doc/configs.txt",
    clean(TXT_HEADER .. table.concat(txt, "\n") .. TXT_FOOTER)
  )
)

print(("docgen: wrote doc/configs.md + doc/configs.txt for %d servers"):format(#names))
