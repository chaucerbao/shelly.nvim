local utils = require('shelly.utils')

local M = {}

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
  local command = { 'node', '-e', code }
  utils.append_args(command, evaluated.command_args)
  utils.execute_shell(command, callback)
end

return M
