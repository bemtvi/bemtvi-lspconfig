---@brief
---
--- GitLab Duo Language Server Configuration for Neovim
---
--- https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp
---
--- The GitLab LSP enables any editor or IDE to integrate with GitLab Duo
--- for AI-powered code suggestions via the Language Server Protocol.
---
--- Prerequisites:
--- - Node.js and npm installed
--- - GitLab account with Duo Pro license
--- - Internet connection for OAuth device flow
---
--- Setup:
--- 1. Run :LspGitLabDuoSignIn to start OAuth authentication
--- 2. Follow the browser prompts to authorize
--- 3. Enable inline completion in LspAttach event (see example below)
---
--- NOTE: the server's headline feature — `textDocument/inlineCompletion`, the greyed-out
--- suggestion accepted with a keypress — has no home in bemtvi yet. `btv.complete` is a
--- popup-menu engine; inline completion is a different surface (virtual text at the
--- cursor, its own accept/cycle keys), and bemtvi has no client for it. Sign-in, chat and
--- the feature-state reporting below all work; the inline suggestions are requested by
--- nothing. Closing this needs an inline-completion layer in the core.

-- Configuration
local util = require("bemtvi-lspconfig.util")

local config = {
  gitlab_url = "https://gitlab.com",
  -- This is a oauth application created from tachyons-gitlab account with `api` scope
  client_id = "00bb391f527d2e77b3467b0b6b900151cc6a28dcfb18fa1249871e43bc3e5832",
  scopes = "api",
  token_file = util.joinpath(btv.stdpath("data"), "gitlab_duo_oauth.json"),
}

-- An OAuth form POST. Upstream shells out to `curl` and `:wait()`s on it, blocking the
-- editor for a network round trip; `btv.http.fetch` is bemtvi's own HTTP, promise-shaped,
-- and works identically over a daemon or in the browser. Resolves `{ status, body }`
-- even on a transport failure (status 0), so every caller branches on the status
-- instead of wrapping the call.
local oauth_post = btv.async(function(url, data)
  local res = btv.await(btv.http
    .fetch(url, {
      method = "POST",
      headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
      body = data,
    })
    :catch(function(err)
      return { status = 0, body = tostring(err) }
    end))
  return { status = res.status, body = res.body or "" }
end)

-- Token management
local save_token = btv.async(function(token_data)
  token_data.saved_at = os.time()
  local ok = pcall(btv.await, btv.fs.write(config.token_file, btv.json.encode(token_data)))
  return ok
end)

local load_token = btv.async(function()
  local blob = btv.await(btv.fs.read_text(config.token_file):catch(function()
    return nil
  end))
  if type(blob) ~= "string" or blob == "" then
    return nil
  end
  local ok, decoded = pcall(btv.json.decode, blob)
  return ok and decoded or nil
end)

local function is_token_expired(token_data)
  if not token_data or not token_data.saved_at or not token_data.expires_in then
    return true
  end
  local token_age = os.time() - token_data.saved_at
  return token_age >= (token_data.expires_in - 60) -- 60 second buffer
end

local refresh_access_token = btv.async(function(refresh_token)
  btv.notify("Refreshing GitLab OAuth token...", btv.log.levels.INFO)

  local response = btv.await(
    oauth_post(
      config.gitlab_url .. "/oauth/token",
      string.format(
        "client_id=%s&refresh_token=%s&grant_type=refresh_token",
        config.client_id,
        refresh_token
      )
    )
  )

  if response.status ~= 200 then
    btv.notify(
      "Failed to refresh token: " .. (response.body or "Unknown error"),
      btv.log.levels.ERROR
    )
    return nil
  end

  local ok, body = pcall(btv.json.decode, response.body)
  if not ok or not body.access_token then
    btv.notify("Invalid refresh response", btv.log.levels.ERROR)
    return nil
  end

  btv.await(save_token(body))
  btv.notify("Token refreshed successfully", btv.log.levels.INFO)
  return body
end)

local get_valid_token = btv.async(function()
  local token_data = btv.await(load_token())

  if not token_data then
    return { status = "no_token" }
  end

  if is_token_expired(token_data) then
    if token_data.refresh_token then
      local new_token_data = btv.await(refresh_access_token(token_data.refresh_token))
      if new_token_data then
        return { token = new_token_data.access_token, status = "refreshed" }
      end
      return { status = "refresh_failed" }
    end
    return { status = "expired" }
  end

  return { token = token_data.access_token, status = "valid" }
end)

-- OAuth Device Flow
local device_authorization = btv.async(function()
  local response = btv.await(
    oauth_post(
      config.gitlab_url .. "/oauth/authorize_device",
      string.format("client_id=%s&scope=%s", config.client_id, config.scopes)
    )
  )

  if response.status ~= 200 then
    btv.notify("Device authorization failed: " .. response.status, btv.log.levels.ERROR)
    return nil
  end

  local ok, data = pcall(btv.json.decode, response.body)
  if not ok then
    btv.notify("Failed to parse device authorization response", btv.log.levels.ERROR)
    return nil
  end

  return data
end)

local poll_for_token = btv.async(function(device_code, interval, client)
  local max_attempts = 60
  local attempts = 0

  local poll
  poll = btv.async(function()
    attempts = attempts + 1

    local response = btv.await(
      oauth_post(
        config.gitlab_url .. "/oauth/token",
        string.format(
          "client_id=%s&device_code=%s&grant_type=urn:ietf:params:oauth:grant-type:device_code",
          config.client_id,
          device_code
        )
      )
    )

    local ok, body = pcall(btv.json.decode, response.body)
    if not ok then
      btv.notify("Failed to parse token response", btv.log.levels.ERROR)
      return
    end

    if response.status == 200 and body.access_token then
      btv.await(save_token(body))
      btv.notify("GitLab Duo authentication successful!", btv.log.levels.INFO)

      client:notify("workspace/didChangeConfiguration", {
        settings = {
          token = body.access_token,
          baseUrl = config.gitlab_url,
        },
      })
      return
    end

    if body.error == "authorization_pending" then
      if attempts < max_attempts then
        btv.timer(poll, interval * 1000)
      else
        btv.notify("Authorization timed out", btv.log.levels.ERROR)
      end
    elseif body.error == "slow_down" then
      btv.timer(poll, (interval + 5) * 1000)
    elseif body.error == "access_denied" then
      btv.notify("Authorization denied", btv.log.levels.ERROR)
    elseif body.error == "expired_token" then
      btv.notify("Device code expired. Please run :LspGitLabDuoSignIn again", btv.log.levels.ERROR)
    else
      btv.notify("OAuth error: " .. (body.error or "unknown"), btv.log.levels.ERROR)
    end
  end)

  -- Only the first attempt is awaited; a pending authorization re-arms itself on a
  -- timer, so the command returns while the user is still in the browser.
  btv.await(poll())
end)

local sign_in = btv.async(function(client)
  btv.notify("Starting GitLab device authorization...", btv.log.levels.INFO)

  local auth_data = btv.await(device_authorization())
  if not auth_data then
    return
  end

  btv.ui.open(auth_data.verification_uri .. "?user_code=" .. auth_data.user_code)

  btv.await(poll_for_token(auth_data.device_code, auth_data.interval or 5, client))
end)

local sign_out = btv.async(function(client)
  local ok = pcall(btv.await, btv.fs.remove(config.token_file))
  if ok then
    btv.notify("Signed out. Token removed.", btv.log.levels.INFO)
    client:notify("workspace/didChangeConfiguration", {
      settings = { token = "" },
    })
  else
    btv.notify("Failed to remove token file", btv.log.levels.ERROR)
  end
end)

local show_status = btv.async(function()
  local token_data = btv.await(load_token())

  if not token_data then
    btv.notify("Not signed in. Run :LspGitLabDuoSignIn to authenticate.", btv.log.levels.INFO)
    return
  end

  local info = {
    "GitLab Duo Status:",
    "",
    "Instance: " .. config.gitlab_url,
    "Signed in: Yes",
    "Has refresh token: " .. (token_data.refresh_token and "Yes" or "No"),
  }

  if token_data.saved_at and token_data.expires_in then
    local time_left = token_data.expires_in - (os.time() - token_data.saved_at)
    if time_left > 0 then
      local hours = math.floor(time_left / 3600)
      local minutes = math.floor((time_left % 3600) / 60)
      table.insert(info, string.format("Token expires in: %dh %dm", hours, minutes))
    else
      table.insert(info, "Token status: EXPIRED")
    end
  end

  btv.notify(table.concat(info, "\n"), btv.log.levels.INFO)
end)

return {
  cmd = {
    "npx",
    "--@gitlab-org:registry=https://gitlab.com/api/v4/packages/npm/",
    "@gitlab-org/gitlab-lsp",
    "--stdio",
  },
  root_markers = { ".git" },
  filetypes = {
    "ruby",
    "go",
    "javascript",
    "typescript",
    "typescriptreact",
    "javascriptreact",
    "rust",
    "lua",
    "python",
    "java",
    "cpp",
    "c",
    "php",
    "cs",
    "kotlin",
    "swift",
    "scala",
    "vue",
    "svelte",
    "html",
    "css",
    "scss",
    "json",
    "yaml",
  },
  init_options = {
    editorInfo = {
      name = "bemtvi",
      version = btv.version(),
    },
    editorPluginInfo = {
      name = "bemtvi LSP",
      version = btv.version(),
    },
    ide = {
      name = "bemtvi",
      version = btv.version(),
      vendor = "bemtvi",
    },
    extension = {
      name = "bemtvi LSP Client",
      version = btv.version(),
    },
  },
  settings = {
    baseUrl = config.gitlab_url,
    logLevel = "info",
    codeCompletion = {
      enableSecretRedaction = true,
    },
    telemetry = {
      enabled = false,
    },
    featureFlags = {
      streamCodeGenerations = false,
    },
  },
  on_init = btv.async(function(client)
    -- Handle token validation errors
    client.handlers["$/gitlab/token/check"] = function(_, result)
      if result and result.reason then
        btv.notify(
          string.format("GitLab Duo: %s - %s", result.reason, result.message or ""),
          btv.log.levels.ERROR
        )

        -- Try to refresh if possible
        btv.async(function()
          local token_data = btv.await(load_token())
          if not (token_data and token_data.refresh_token) then
            return btv.notify("Run :LspGitLabDuoSignIn to authenticate", btv.log.levels.WARN)
          end
          local new_token_data = btv.await(refresh_access_token(token_data.refresh_token))
          if new_token_data then
            client:notify("workspace/didChangeConfiguration", {
              settings = { token = new_token_data.access_token, baseUrl = config.gitlab_url },
            })
          else
            btv.notify("Run :LspGitLabDuoSignIn to re-authenticate", btv.log.levels.WARN)
          end
        end)()
      end
    end

    -- Handle feature state changes
    client.handlers["$/gitlab/featureStateChange"] = function(_, result)
      if result and result.state == "disabled" and result.checks then
        for _, check in ipairs(result.checks) do
          btv.notify(string.format("GitLab Duo: %s", check.message or check.id), btv.log.levels.WARN)
        end
      end
    end

    -- Check authentication status
    local auth = btv.await(get_valid_token())
    local token, status = auth.token, auth.status

    if token then
      client:notify("workspace/didChangeConfiguration", {
        settings = {
          token = token,
          baseUrl = config.gitlab_url,
        },
      })
    end

    if not token then
      btv.notify(
        "GitLab Duo: Not authenticated. Run :LspGitLabDuoSignIn to sign in.",
        btv.log.levels.WARN
      )
    elseif status == "refreshed" then
      btv.notify("GitLab Duo: Token refreshed automatically", btv.log.levels.INFO)
    end
  end),
  on_attach = function(client, bufnr)
    util.buf_command(bufnr, "LspGitLabDuoSignIn", function()
      sign_in(client)
    end, { desc = "Sign in to GitLab Duo with OAuth" })

    util.buf_command(bufnr, "LspGitLabDuoSignOut", function()
      sign_out(client)
    end, { desc = "Sign out from GitLab Duo" })

    util.buf_command(bufnr, "LspGitLabDuoStatus", function()
      show_status()
    end, { desc = "Show GitLab Duo authentication status" })
  end,
}
