local utils = require('shelly.utils')

--- Shelly Redis filetype runner: executes Redis commands using redis-cli.

--- Executes Redis commands using redis-cli.
---@type FiletypeRunner
local function execute(evaluated, callback)
  if vim.tbl_isempty(evaluated.lines) then
    callback({ stdout = {}, stderr = { 'No Redis commands to execute' } })
    return
  end

  local command = { 'redis-cli' }
  local connection_string = nil
  for _, url in ipairs(evaluated.urls) do
    if url:match('^redis[s]*://') then
      connection_string = url
    end
  end
  if not connection_string then
    connection_string = evaluated.dictionary.url
      or evaluated.dictionary.connection_string
      or evaluated.dictionary.redis_url
  end
  if connection_string then
    table.insert(command, '-u')
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
    if evaluated.dictionary.auth or evaluated.dictionary.password then
      table.insert(command, '-a')
      table.insert(command, evaluated.dictionary.auth or evaluated.dictionary.password)
    end
    if evaluated.dictionary.db then
      table.insert(command, '-n')
      table.insert(command, evaluated.dictionary.db)
    end
  end
  vim.list_extend(command, evaluated.command_args)
  if #evaluated.lines == 1 then
    for _, part in ipairs(vim.split(evaluated.lines[1], '%s+')) do
      table.insert(command, part)
    end
    utils.execute_shell(command, { shelly_args = evaluated.shelly_args }, callback)
  else
    utils.execute_shell(command, { stdin = evaluated.lines, shelly_args = evaluated.shelly_args }, callback)
  end
end

return { execute = execute }
