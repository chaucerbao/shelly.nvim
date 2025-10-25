local utils = require('shelly.utils')

local M = {}

--- Execute JavaScript code using Node.js.
---
--- Concatenates code lines and runs with node -e.
--- @param evaluated table Evaluated code and metadata
--- @param callback fun(result: table) Callback with result table {stdout: string[], stderr: string[]}
function M.execute(evaluated, callback)
  if not evaluated or not evaluated.processed_lines or #evaluated.processed_lines == 0 then
    vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
    return
  end
  local code = table.concat(evaluated.processed_lines, '\n')
  local command = { 'node', '-e', code }
  utils.append_args(command, evaluated.command_args)
  utils.execute_shell(command, callback)
end

return M
