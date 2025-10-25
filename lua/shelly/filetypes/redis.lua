local utils = require('shelly.utils')

--- Execute Redis commands using redis-cli.
local function execute(evaluated, callback)
  if #evaluated.processed_lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No Redis commands to execute' } })
    end)
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
  if #evaluated.processed_lines == 1 then
    for _, part in ipairs(vim.split(evaluated.processed_lines[1], '%s+')) do
      table.insert(command, part)
    end
    utils.execute_shell(command, callback)
  else
    local commands_str = table.concat(evaluated.processed_lines, '\n')
    local pipe_command = { 'bash', '-c', "echo '" .. commands_str:gsub("'", "'\\''") .. "' | redis-cli" }
    if connection_string then
      pipe_command[3] = pipe_command[3] .. " -u '" .. connection_string:gsub("'", "'\\''") .. "'"
    else
      if evaluated.dictionary.host then
        pipe_command[3] = pipe_command[3] .. ' -h ' .. evaluated.dictionary.host
      end
      if evaluated.dictionary.port then
        pipe_command[3] = pipe_command[3] .. ' -p ' .. evaluated.dictionary.port
      end
      if evaluated.dictionary.auth or evaluated.dictionary.password then
        pipe_command[3] = pipe_command[3]
          .. " -a '"
          .. (evaluated.dictionary.auth or evaluated.dictionary.password):gsub("'", "'\\''")
          .. "'"
      end
      if evaluated.dictionary.db then
        pipe_command[3] = pipe_command[3] .. ' -n ' .. evaluated.dictionary.db
      end
    end
    utils.execute_shell(pipe_command, callback)
  end
end

return { execute = execute }
