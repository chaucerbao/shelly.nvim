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
  utils.execute_shell(command, { stdin = evaluated.lines, shelly_args = evaluated.shelly_args }, function(result)
    result.stdout = vim.tbl_map(utils.strip_backspace_codes, result.stdout)
    result.stderr = vim.tbl_map(utils.strip_backspace_codes, result.stderr)
    callback(result)
  end)
end

return { execute = execute }
