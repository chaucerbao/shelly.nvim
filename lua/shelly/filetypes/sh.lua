local utils = require('shelly.utils')

local M = {}

--- Execute shell script using bash
---@param callback function(result: {stdout: string[], stderr: string[]}) Callback with results
function M.execute(callback)
  local prepared = utils.prepare_execution()

  if not prepared.has_code then
    vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No shell commands to execute' } })
    end)
    return
  end

  local evaluated = prepared.evaluated
  local code_lines = prepared.code_lines

  -- Build bash command
  local code = table.concat(code_lines, '\n')
  local command = { 'bash', '-c', code }

  -- Add command line arguments if provided
  if #evaluated.command_args > 0 then
    for _, arg in ipairs(evaluated.command_args) do
      table.insert(command, arg)
    end
  end

  utils.execute_shell(command, callback)
end

return M
