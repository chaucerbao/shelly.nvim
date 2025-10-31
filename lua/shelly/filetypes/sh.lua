local utils = require('shelly.utils')

--- Executes shell commands using bash.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  if #evaluated.lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No shell commands to execute' } })
    end)
  end
  local command = { 'bash' }
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, { stdin = evaluated.lines, shelly_args = evaluated.shelly_args }, callback)
end

return { execute = execute }
