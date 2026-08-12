---@brief
---
--- https://github.com/zk-org/zk
---
--- A plain text note-taking assistant

---List notes
---@param client btv.lsp.Client
---@param bufnr integer
---@param opts table
---@param action fun(path: string, title: string)
local util = require("bemtvi-lspconfig.util")

local function zk_list(client, bufnr, opts, action)
  opts = btv.tbl.extend("keep", { select = { "path", "title" } }, opts or {})
  client:exec_cmd({
    title = "ZkList",
    command = "zk.list",
    arguments = { util.bufname(bufnr), opts },
  }, { bufnr = bufnr }, function(err, result)
    if err ~= nil then
      btv.echo({ { "zk.list error\n" }, { btv.inspect(err) } }, true, {})
      return
    end
    if result == nil then
      return
    end

    btv.ui.select(result, {
      format_item = function(item)
        return item.title
      end,
    }, function(item)
      if item ~= nil then
        action(util.joinpath(client.root_dir, item.path), item.title)
      end
    end)
  end)
end

return {
  cmd = { "zk", "lsp" },
  filetypes = { "markdown" },
  root_markers = { ".zk" },
  workspace_required = true,
  on_attach = function(client, bufnr)
    util.buf_command(bufnr, "LspZkIndex", function()
      client:exec_cmd({
        title = "ZkIndex",
        command = "zk.index",
        arguments = { util.bufname(bufnr) },
      }, { bufnr = bufnr }, function(err, result)
        if err ~= nil then
          btv.echo({ { "zk.index error\n" }, { btv.inspect(err) } }, true, {})
          return
        end
        if result ~= nil then
          btv.echo({ { btv.inspect(result) } }, false, {})
        end
      end)
    end, { desc = "ZkIndex" })

    util.buf_command(bufnr, "LspZkList", function()
      zk_list(client, bufnr, {}, function(path)
        btv.cmd("edit " .. btv.fname.escape(path))
      end)
    end, { desc = "ZkList" })

    util.buf_command(bufnr, "LspZkTagList", function()
      client:exec_cmd({
        title = "ZkTagList",
        command = "zk.tag.list",
        arguments = { util.bufname(bufnr) },
      }, { bufnr = bufnr }, function(err, result)
        if err ~= nil then
          btv.echo({ { "zk.tag.list error\n" }, { btv.inspect(err) } }, true, {})
          return
        end
        if result == nil then
          return
        end

        btv.ui.select(result, {
          format_item = function(item)
            return item.name
          end,
        }, function(item)
          if item ~= nil then
            zk_list(client, bufnr, { tags = { item.name } }, function(path)
              btv.cmd("edit " .. btv.fname.escape(path))
            end)
          end
        end)
      end)
    end, { desc = "ZkTagList" })

    util.buf_command(bufnr, "LspZkNew", function(args)
      local title = #args.fargs >= 1 and args.fargs[1] or ""
      local dir = #args.fargs >= 2 and args.fargs[2] or ""
      client:exec_cmd({
        title = "ZkNew",
        command = "zk.new",
        arguments = {
          util.bufname(bufnr),
          { title = title, dir = dir },
        },
      }, { bufnr = bufnr }, function(err, result)
        if err ~= nil then
          btv.echo({ { "zk.new error\n" }, { btv.inspect(err) } }, true, {})
          return
        end

        btv.cmd("edit " .. btv.fname.escape(result.path))
      end)
    end, { desc = "ZkNew [title] [dir]", nargs = "*" })
  end,
}
