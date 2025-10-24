local utils = require('shelly.utils')

local M = {}

--- Execute TypeScript code using tsx or ts-node.
---
--- Concatenates code lines and runs with tsx -e or ts-node -e.
--- @param callback fun(result: table) Callback with result table {stdout: string[], stderr: string[]}
function M.execute(callback)
  local prepared = utils.prepare_execution()
  if not prepared.has_code then
    vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
    return
  end
  local evaluated = prepared.evaluated
  local code_lines = prepared.code_lines
  local code = table.concat(code_lines, '\n')
  local command
  if vim.fn.executable('tsx') == 1 then
    command = { 'tsx', '-e', code }
  else
    command = { 'ts-node', '-e', code }
  end
  utils.append_args(command, evaluated.command_args)
  utils.execute_shell(command, callback)
end

return M
