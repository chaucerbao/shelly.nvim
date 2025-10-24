local utils = require('shelly.utils')

local M = {}

function M.execute(callback)
  local prepared = utils.prepare_execution()
  if not prepared.has_code then
    vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No Redis commands to execute' } })
    end)
    return
  end
  local evaluated = prepared.evaluated
  local code_lines = prepared.code_lines
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
  utils.append_args(command, evaluated.command_args)
  if #code_lines == 1 then
    local cmd_parts = vim.split(code_lines[1], '%s+')
    for _, part in ipairs(cmd_parts) do
      table.insert(command, part)
    end
    utils.execute_shell(command, callback)
  else
    local commands_str = table.concat(code_lines, '\n')
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

return M
