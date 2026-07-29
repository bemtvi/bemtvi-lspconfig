---@brief
---
--- https://github.com/termux/termux-language-server
---
--- Language server for various bash scripts such as Arch PKGBUILD, Gentoo ebuild, Termux build.sh, etc.

local util = require("nxvim-lspconfig.util")

return {
  cmd = { "termux-language-server" },
  root_dir = function(bufnr, on_dir)
    local patterns = {
      -- Termux
      "build.sh",
      "*.subpackage.sh",
      -- Arch/MSYS2
      "PKGBUILD",
      "makepkg.conf",
      "*.install",
      -- Gentoo
      "make.conf",
      "color.map",
      "*.ebuild",
      "*.eclass",
    }
    local fname = util.bufname(bufnr)
    util.root_pattern(patterns)(fname):next(function(match)
      if not match then
        return
      end
      -- A PKGBUILD-style tree is often a subdirectory of a bigger repo; prefer the repo.
      util.root_of_path(match, { ".git" }):next(function(git_root)
        on_dir(git_root or match)
      end)
    end)
  end,
}
