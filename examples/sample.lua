-- sample.lua: a Lua buffer for lua_ls. The line numbers in init.lua's steps
-- point into this file.

local M = {}

local count = #btv.buf.lines(0, 0, -1, false)

-- Step 3: `undefined_global` is defined nowhere, so lua_ls flags it.
local function greet(name, times)
  return undefined_global .. name:rep(times)
end

-- Steps 4-6: `greet` is used here; K, <C-]>, grn and inlay hints all work on it.
function M.run()
  return greet("world", count)
end

return M
