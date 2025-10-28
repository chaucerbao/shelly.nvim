local utils = require('shelly.utils')

--- Executes PostgreSQL queries using psql.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  if #evaluated.processed_lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No SQL to execute' } })
    end)
  end
  local command = { 'psql' }
  local sql = table.concat(evaluated.processed_lines, '\n')
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
  vim.list_extend(command, evaluated.command_args)
  utils.execute_shell(command, { stdin = evaluated.processed_lines }, callback)
end

return { execute = execute }
