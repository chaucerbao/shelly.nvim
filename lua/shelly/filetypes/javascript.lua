local utils = require('shelly.utils')

--- Executes JavaScript code using Node.js.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  if #evaluated.processed_lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
  end
  local command = { 'node' }
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, { stdin = evaluated.processed_lines }, callback)
end

return { execute = execute }
