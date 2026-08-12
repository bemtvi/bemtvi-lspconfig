---@brief
---
--- https://github.com/ocaml/ocaml-lsp
---
--- `ocaml-lsp` can be installed as described in [installation guide](https://github.com/ocaml/ocaml-lsp#installation).
---
--- To install the lsp server in a particular opam switch:
--- ```sh
--- opam install ocaml-lsp-server
--- ```

-- https://github.com/ocaml/ocaml-lsp/blob/master/ocaml-lsp-server/docs/ocamllsp/switchImplIntf-spec.md
local util = require("bemtvi-lspconfig.util")

local function switch_impl_intf(bufnr, client)
  local method_name = "ocamllsp/switchImplIntf"
  ---@diagnostic disable-next-line:param-type-mismatch
  if not client or not client:supports_method(method_name) then
    return btv.notify(
      ("method %s is not supported by any servers active on the current buffer"):format(method_name)
    )
  end
  -- `ocamllsp/switchImplIntf` takes just the document's URI. Upstream reached it
  -- through a whole range-params builder and threw the range away; the URI is what
  -- the method is about, so ask for it directly.
  local uri = util.uri_from_buf(bufnr)
  if uri == "" then
    return btv.notify("could not get URI for current buffer")
  end
  local params = { uri }
  ---@diagnostic disable-next-line:param-type-mismatch
  client:request(method_name, params, function(err, result)
    if err then
      error(tostring(err))
    end
    if not result or #result == 0 then
      btv.notify("corresponding file cannot be determined")
    elseif #result == 1 then
      btv.lsp.show_document({ uri = result[1] })
    else
      btv.ui.select(result, {
        prompt = "Select an implementation/interface:",
        format_item = util.uri_to_path,
      }, function(choice)
        if choice then
          btv.lsp.show_document({ uri = choice })
        end
      end)
    end
  end, bufnr)
end

local language_id_of = {
  menhir = "ocaml.menhir",
  ocaml = "ocaml",
  ocamlinterface = "ocaml.interface",
  ocamllex = "ocaml.ocamllex",
  reason = "reason",
  dune = "dune",
}

local language_id_of_ext = {
  mll = language_id_of.ocamllex,
  mly = language_id_of.menhir,
  mli = language_id_of.ocamlinterface,
}

local get_language_id = function(bufnr, ftype)
  if ftype == "ocaml" then
    -- `.mli` / `.mll` / `.mly` all arrive as filetype `ocaml`, and the server needs
    -- them told apart — so the extension, not the filetype, decides the languageId.
    local ext = btv.fname.modify(util.bufname(bufnr), ":e")
    return language_id_of_ext[ext] or language_id_of.ocaml
  else
    return language_id_of[ftype]
  end
end

local root_markers1 = { "dune-project", "dune-workspace" }
local root_markers2 = { "*.opam", "opam", "esy.json", "package.json" }
local root_markers3 = { ".git" }

return {
  cmd = { "ocamllsp" },
  filetypes = { "ocaml", "menhir", "ocamlinterface", "ocamllex", "reason", "dune" },
  root_markers = { root_markers1, root_markers2, root_markers3 },
  get_language_id = get_language_id,
  on_attach = function(client, bufnr)
    util.buf_command(bufnr, "LspOcamllspSwitchImplIntf", function()
      switch_impl_intf(bufnr, client)
    end, { desc = "Switch between implementation/interface" })
  end,
}
