local utils = require('shelly.utils')

--- Shelly Python filetype runner: executes Python code using python3.

--- Executes Python code using python3.
---@type FiletypeRunner
local function execute(evaluated, callback)
  if vim.tbl_isempty(evaluated.lines) then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
  end
  local command = { 'python3' }
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, { stdin = evaluated.lines, shelly_args = evaluated.shelly_args }, callback)
end

return { execute = execute }
