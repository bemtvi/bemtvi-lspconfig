---@brief
---
--- https://www.npmjs.com/package/@github/copilot-language-server
---
--- The Copilot Language Server enables any editor or IDE
--- to integrate with GitHub Copilot via
--- [the language server protocol](https://microsoft.github.io/language-server-protocol/).
---
--- **[GitHub Copilot](https://github.com/features/copilot)**
--- is an AI pair programmer tool that helps you write code faster and smarter.
---
--- **Sign up for [GitHub Copilot Free](https://github.com/settings/copilot)!**
---
--- Please see [terms of use for GitHub Copilot](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features#github-copilot)
---
--- You need to enable `:help lsp-inline-completion` to receive suggestions. For example, you can enable it in the LspAttach event:
---
--- NOTE: the server's headline feature — `textDocument/inlineCompletion`, the greyed-out
--- suggestion accepted with a keypress — has no home in bemtvi yet. `btv.complete` is a
--- popup-menu engine; inline completion is a different surface (virtual text at the
--- cursor, its own accept/cycle keys), and bemtvi has no client for it. The server
--- starts, `:LspCopilotSignIn` works, and the panel/chat commands work; the inline
--- suggestions are requested by nothing. Closing this needs an inline-completion layer
--- in the core, which is a feature rather than a config.

---@param bufnr integer,
---@param client btv.lsp.Client
local util = require("bemtvi-lspconfig.util")

local function sign_in(bufnr, client)
  client:request(
    ---@diagnostic disable-next-line: param-type-mismatch
    "signIn",
    btv.json.empty_object(),
    function(err, result)
      if err then
        btv.notify(err.message, btv.log.levels.ERROR)
        return
      end
      if result.command then
        local code = result.userCode
        local command = result.command
        btv.reg.set("+", code)
        btv.reg.set("*", code)
        btv.ui
          .confirm(
            "Copied your one-time code to clipboard.\n"
              .. "Open the browser to complete the sign-in process?"
          )
          :next(function(yes)
            if not yes then
              return
            end
            client:exec_cmd(command, { bufnr = bufnr }, function(cmd_err, cmd_result)
              if cmd_err then
                btv.notify(cmd_err.message, btv.log.levels.ERROR)
                return
              end
              if cmd_result.status == "OK" then
                btv.notify("Signed in as " .. cmd_result.user .. ".")
              end
            end)
          end)
      end

      if result.status == "PromptUserDeviceFlow" then
        btv.notify(
          "Enter your one-time code " .. result.userCode .. " in " .. result.verificationUri
        )
      elseif result.status == "AlreadySignedIn" then
        btv.notify("Already signed in as " .. result.user .. ".")
      end
    end
  )
end

---@param client btv.lsp.Client
local function sign_out(_, client)
  client:request(
    ---@diagnostic disable-next-line: param-type-mismatch
    "signOut",
    btv.json.empty_object(),
    function(err, result)
      if err then
        btv.notify(err.message, btv.log.levels.ERROR)
        return
      end
      if result.status == "NotSignedIn" then
        btv.notify("Not signed in.")
      end
    end
  )
end

return {
  cmd = {
    "copilot-language-server",
    "--stdio",
  },
  root_markers = { ".git" },
  init_options = {
    editorInfo = {
      name = "bemtvi",
      version = btv.version(),
    },
    editorPluginInfo = {
      name = "bemtvi",
      version = btv.version(),
    },
  },
  settings = {
    telemetry = {
      telemetryLevel = "all",
    },
  },
  on_attach = function(client, bufnr)
    util.buf_command(bufnr, "LspCopilotSignIn", function()
      sign_in(bufnr, client)
    end, { desc = "Sign in Copilot with GitHub" })
    util.buf_command(bufnr, "LspCopilotSignOut", function()
      sign_out(bufnr, client)
    end, { desc = "Sign out Copilot with GitHub" })
  end,
}
