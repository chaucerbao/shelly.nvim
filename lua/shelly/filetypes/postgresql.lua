local utils = require('shelly.utils')

--- Executes PostgreSQL queries using psql.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  if #evaluated.lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No SQL to execute' } })
    end)
  end

  local command = { 'psql' }

  local connection_string
  for _, url in ipairs(evaluated.urls) do
    if url:match('^postgres[ql]*://') then
      connection_string = url
    end
  end

  if not connection_string then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No connection string provided' } })
    end)
  end

  table.insert(command, connection_string)
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, { stdin = evaluated.lines, shelly_args = evaluated.shelly_args }, callback)
end

return { execute = execute }
