local utils = require('shelly.utils')

local M = {}

--- Execute Redis commands using redis-cli
---@param callback function(result: {stdout: string[], stderr: string[]}) Callback with results
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

  -- Build redis-cli command
  local command = { 'redis-cli' }

  -- Look for connection string
  local connection_string = nil

  -- Check URLs for redis:// or rediss://, prioritize latest match
  for _, url in ipairs(evaluated.urls) do
    if url:match('^redis[s]*://') then
      connection_string = url
    end
  end

  -- Check dictionary for connection string keys
  if not connection_string then
    connection_string = evaluated.dictionary.url
      or evaluated.dictionary.connection_string
      or evaluated.dictionary.redis_url
  end

  -- If connection string found, use it
  if connection_string then
    table.insert(command, '-u')
    table.insert(command, connection_string)
  else
    -- Extract connection parameters from dictionary
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

  -- Add command line arguments if provided
  if #evaluated.command_args > 0 then
    for _, arg in ipairs(evaluated.command_args) do
      table.insert(command, arg)
    end
  end

  -- For multiple commands, execute them one by one
  if #code_lines == 1 then
    -- Single command - add directly
    local cmd_parts = vim.split(code_lines[1], '%s+')
    for _, part in ipairs(cmd_parts) do
      table.insert(command, part)
    end
    utils.execute_shell(command, callback)
  else
    -- Multiple commands - execute in batch mode
    local commands_str = table.concat(code_lines, '\n')

    -- Create a temporary command that pipes commands to redis-cli
    local pipe_command = { 'bash', '-c', "echo '" .. commands_str:gsub("'", "'\\''") .. "' | redis-cli" }

    -- Add connection params to the pipe command
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
