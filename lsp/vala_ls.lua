---@brief
---
--- https://github.com/vala-lang/vala-language-server

local meson_matcher = function(path)
  local pattern = "meson.build"
  local f = vim.fn.glob(table.concat({ path, pattern }, "/"))
  if f == "" then
    return nil
  end
  for line in io.lines(f) do
    -- skip meson comments
    if not line:match("^%s*#.*") then
      local str = line:gsub("%s+", "")
      if str ~= "" then
        if str:match("^project%(") then
          return path
        else
          break
        end
      end
    end
  end
end

return {
  cmd = { "vala-language-server" },
  filetypes = { "vala", "genie" },
  root_dir = function(bufnr, on_dir)
    local fname = util.bufname(bufnr)
    local root = vim.iter(util.ancestors(fname)):find(meson_matcher)
    on_dir(root or util.dirname(vim.fs.find(".git", { path = fname, upward = true })[1]))
  end,
}
