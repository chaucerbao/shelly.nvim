local utils = require('shelly.utils')

--- Executes Python code using python3.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  if #evaluated.processed_lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
  end
  local command = { 'python3' }
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, { stdin = evaluated.processed_lines }, callback)
end

return { execute = execute }
