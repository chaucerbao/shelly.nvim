local utils = require('shelly.utils')
--- Execute Python code using python3.
local function execute(evaluated, callback)
  if #evaluated.processed_lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
  end
  local command = { 'python3', '-c', table.concat(evaluated.processed_lines, '\n') }
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, callback)
end

return { execute = execute }
