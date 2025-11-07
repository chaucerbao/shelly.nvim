local utils = require('shelly.utils')

--- Shelly JavaScript filetype runner: executes JavaScript code using Node.js.

--- Executes JavaScript code using Node.js.
---@type FiletypeRunner
local function execute(evaluated, callback)
  if vim.tbl_isempty(evaluated.lines) then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
  end
  local command = { 'node' }
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, { stdin = evaluated.lines, shelly_args = evaluated.shelly_args }, callback)
end

return { execute = execute }
