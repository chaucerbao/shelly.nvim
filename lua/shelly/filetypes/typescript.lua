local utils = require("shelly.utils")

local M = {}

--- Execute TypeScript code using ts-node or tsx
---@param callback function(result: {stdout: string[], stderr: string[]}) Callback with results
function M.execute(callback)
  local prepared = utils.prepare_execution()

  if not prepared.has_code then
    vim.schedule(function()
      callback({stdout = {}, stderr = {"No code to execute"}})
    end)
    return
  end

  local evaluated = prepared.evaluated
  local code_lines = prepared.code_lines

  -- Build TypeScript command (try tsx first, fallback to ts-node)
  local code = table.concat(code_lines, "\n")

  -- Check if tsx is available
  local tsx_check = vim.fn.executable("tsx")
  local command

  if tsx_check == 1 then
    command = {"tsx", "-e", code}
  else
    -- Fallback to ts-node
    command = {"ts-node", "-e", code}
  end

  -- Add command line arguments if provided
  if #evaluated.command_args > 0 then
    for _, arg in ipairs(evaluated.command_args) do
      table.insert(command, arg)
    end
  end

  utils.execute_shell(command, callback)
end

return M
