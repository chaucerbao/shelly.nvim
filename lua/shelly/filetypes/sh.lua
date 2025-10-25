local utils = require('shelly.utils')

--- Execute shell commands using bash.
local function execute(evaluated, callback)
  if #evaluated.processed_lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No shell commands to execute' } })
    end)
  end
  local command = { 'bash', '-c', table.concat(evaluated.processed_lines, '\n') }
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, callback)
end

return { execute = execute }
