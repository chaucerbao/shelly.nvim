local utils = require('shelly.utils')

--- Execute Lua code using the Lua interpreter.
local function execute(evaluated, callback)
  if #evaluated.processed_lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
  end
  local command = { 'lua', '-e', table.concat(evaluated.processed_lines, '\n') }
  utils.append_args(command, evaluated.command_args)
  utils.execute_shell(command, callback)
end

return { execute = execute }
