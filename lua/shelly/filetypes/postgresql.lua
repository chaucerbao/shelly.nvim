local utils = require('shelly.utils')

local M = {}

--- Execute PostgreSQL queries using psql.
---
--- Builds connection string and runs SQL code.
--- @param callback fun(result: table) Callback with result table {stdout: string[], stderr: string[]}
function M.execute(callback)
  local prepared = utils.prepare_execution()
  if not prepared.has_code then
    vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No SQL to execute' } })
    end)
    return
  end
  local evaluated = prepared.evaluated
  local code_lines = prepared.code_lines
  local sql = table.concat(code_lines, '\n')
  local command = { 'psql' }
  local connection_string = nil
  for _, url in ipairs(evaluated.urls) do
    if url:match('^postgres[ql]*://') then
      connection_string = url
    end
  end
  if not connection_string then
    connection_string = evaluated.dictionary.url
      or evaluated.dictionary.connection_string
      or evaluated.dictionary.database_url
      or evaluated.dictionary.dsn
  end
  if connection_string then
    table.insert(command, connection_string)
  else
    if evaluated.dictionary.host then
      table.insert(command, '-h')
      table.insert(command, evaluated.dictionary.host)
    end
    if evaluated.dictionary.port then
      table.insert(command, '-p')
      table.insert(command, evaluated.dictionary.port)
    end
    if evaluated.dictionary.username or evaluated.dictionary.user then
      table.insert(command, '-U')
      table.insert(command, evaluated.dictionary.username or evaluated.dictionary.user)
    end
    if evaluated.dictionary.database or evaluated.dictionary.dbname then
      table.insert(command, '-d')
      table.insert(command, evaluated.dictionary.database or evaluated.dictionary.dbname)
    end
  end
  utils.append_args(command, evaluated.command_args)
  table.insert(command, '-c')
  table.insert(command, sql)
  utils.execute_shell(command, callback)
end

return M
