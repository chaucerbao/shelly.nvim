local utils = require('shelly.utils')

--- Shelly Lua filetype runner: executes Lua code using CLI or Neovim's interpreter.

--- Executes Lua code using the Lua interpreter.
---@type FiletypeRunner
local function execute(evaluated, callback)
  if vim.tbl_isempty(evaluated.lines) then
    callback({ stdout = {}, stderr = { 'No code to execute' } })
    return
  end

  -- Check if CLI lua is available
  if vim.fn.executable('lua') == 1 then
    local command = { 'lua' }
    vim.list_extend(command, evaluated.command_args)
    utils.execute_shell(command, { stdin = evaluated.lines, shelly_args = evaluated.shelly_args }, callback)
    return
  end

  -- Fallback: Use Neovim's built-in Lua interpreter
  local code = table.concat(evaluated.lines, '\n')
  local output = {}
  local function capture_print(...)
    local args = { ... }
    for i = 1, #args do
      args[i] = tostring(args[i])
    end
    table.insert(output, table.concat(args, '\t'))
  end
  local original_print = print
  print = capture_print
  local ok, err = pcall(function()
    assert(load(code))()
  end)
  print = original_print
  if ok then
    callback({ stdout = output, stderr = {} })
  else
    callback({ stdout = {}, stderr = { tostring(err) } })
  end
end

return { execute = execute }
