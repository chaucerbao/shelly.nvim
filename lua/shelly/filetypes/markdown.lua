local utils = require('shelly.utils')

local M = {}

--- Execute Markdown code block by delegating to the appropriate runner.
---
--- Determines code block language and runs corresponding filetype runner.
--- @param callback fun(result: table) Callback with result table {stdout: string[], stderr: string[]}
function M.execute(callback)
  local selection = utils.parse_selection()
  local filetype = selection.filetype
  local filetype_map = {
    python = 'python',
    py = 'python',
    lua = 'lua',
    javascript = 'javascript',
    js = 'javascript',
    typescript = 'typescript',
    ts = 'typescript',
    sql = 'postgresql',
    postgresql = 'postgresql',
    psql = 'postgresql',
    redis = 'redis',
    bash = 'sh',
    sh = 'sh',
    shell = 'sh',
    http = 'http',
  }
  local runner_name = filetype_map[filetype] or filetype
  local success, runner = pcall(require, 'shelly.filetypes.' .. runner_name)
  if success and runner.execute then
    runner.execute(callback)
  else
    vim.schedule(function()
      callback({
        stdout = {},
        stderr = { 'No runner found for filetype: ' .. filetype },
      })
    end)
  end
end

return M
