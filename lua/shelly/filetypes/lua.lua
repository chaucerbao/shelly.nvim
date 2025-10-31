local utils = require('shelly.utils')

--- Executes Lua code using the Lua interpreter.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  if #evaluated.lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No code to execute' } })
    end)
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
    vim.schedule(function()
      callback({ stdout = output, stderr = {} })
    end)
  else
    vim.schedule(function()
      callback({ stdout = {}, stderr = { tostring(err) } })
    end)
  end
end

return { execute = execute }
