local utils = require('shelly.utils')

local M = {}

--- Execute shell commands using bash.
---
--- Concatenates code lines and runs with bash -c.
--- @param evaluated table Evaluated code and metadata
--- @param callback fun(result: table) Callback with result table {stdout: string[], stderr: string[]}
function M.execute(evaluated, callback)
  if not evaluated or not evaluated.processed_lines or #evaluated.processed_lines == 0 then
    vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No shell commands to execute' } })
    end)
    return
  end
  local code = table.concat(evaluated.processed_lines, '\n')
  local command = { 'bash', '-c', code }
  utils.append_args(command, evaluated.command_args)
  utils.execute_shell(command, callback)
end

return M
