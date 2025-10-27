local utils = require('shelly.utils')

--- Checks if a string is valid JSON (object or array).
-- @param str string
-- @return boolean
local function is_json(str)
  str = str:match('^%s*(.-)%s*$')
  return (str:sub(1, 1) == '{' and str:sub(-1) == '}') or (str:sub(1, 1) == '[' and str:sub(-1) == ']')
end

--- Parses HTTP method and URL from lines.
-- @param lines string[]
-- @return string method, string url, integer idx
local function parse_method_url(lines)
  for line_index, line_text in ipairs(lines) do
    local http_method, request_url = line_text:match('^(%u+)%s+(%S+)')
    if http_method and request_url then
      return http_method, request_url, line_index
    end
  end
  for line_index, line_text in ipairs(lines) do
    local request_url = line_text:match('(https?://%S+)')
    if request_url then
      return 'GET', request_url, line_index
    end
  end
  return 'GET', '', 0
end

--- Executes HTTP requests using curl.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  if #evaluated.processed_lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No HTTP request to execute' } })
    end)
  end
  local code_lines = evaluated.processed_lines
  local method, url, idx = parse_method_url(code_lines)
  local body_lines = {}
  for line_index = idx + 1, #code_lines do
    if code_lines[line_index] and code_lines[line_index]:match('%S') then
      table.insert(body_lines, code_lines[line_index])
    end
  end
  local command = { 'curl', '-i', '-s', '-L', '-X', method }
  vim.list_extend(command, evaluated.command_args)
  local function handle_curl_result(result)
    local lines = result.stdout
    local header_blocks = {}
    local body_lines = {}
    local current_headers = {}
    local in_headers = true
    for i, line in ipairs(lines) do
      if in_headers then
        if line == '' then
          if #current_headers > 0 then
            table.insert(header_blocks, current_headers)
            current_headers = {}
          end
          in_headers = false
        else
          table.insert(current_headers, line)
        end
      else
        -- If we see another HTTP status line, start new headers (redirect)
        if line:match('^HTTP/%d') then
          if #current_headers > 0 then
            table.insert(header_blocks, current_headers)
          end
          current_headers = { line }
          in_headers = true
        else
          table.insert(body_lines, line)
        end
      end
    end
    if #current_headers > 0 then
      table.insert(header_blocks, current_headers)
    end
    -- Use last header block for content-type
    local last_headers = header_blocks[#header_blocks] or {}
    local content_type
    for _, h in ipairs(last_headers) do
      local lower_h = h:lower()
      local ct = lower_h:match('^content%-type:%s*([^;]+)')
      if ct then
        content_type = ct
        break
      end
    end
    local filetype_map = {
      ['application/json'] = 'json',
      ['text/html'] = 'html',
      ['application/xml'] = 'xml',
      ['text/xml'] = 'xml',
      ['text/plain'] = 'text',
      ['application/javascript'] = 'javascript',
      ['text/css'] = 'css',
      ['text/markdown'] = 'markdown',
    }
    local result_filetype = filetype_map[content_type or ''] or nil
    -- If -i or --include is present, prepend all headers to stdout
    local include_headers = false
    for _, arg in ipairs(evaluated.command_args) do
      if arg == '-i' or arg == '--include' then
        include_headers = true
        break
      end
    end
    local final_stdout = {}
    if include_headers then
      for _, block in ipairs(header_blocks) do
        for _, h in ipairs(block) do
          table.insert(final_stdout, h)
        end
        table.insert(final_stdout, '')
      end
      for _, b in ipairs(body_lines) do
        table.insert(final_stdout, b)
      end
    else
      for _, b in ipairs(body_lines) do
        table.insert(final_stdout, b)
      end
    end
    callback({ stdout = final_stdout, stderr = result.stderr, filetype = result_filetype })
  end
  if method == 'GQL' then
    table.insert(command, url)
    table.insert(command, '-H')
    table.insert(command, 'Content-Type: application/json')
    table.insert(command, '--data')
    table.insert(command, vim.json.encode({ query = table.concat(body_lines, '\n') }))
    utils.execute_shell(command, handle_curl_result)
    return
  end
  if (method == 'POST' or method == 'PUT') and #body_lines > 0 then
    local body = table.concat(body_lines, '\n')
    if is_json(body) then
      table.insert(command, url)
      table.insert(command, '-H')
      table.insert(command, 'Content-Type: application/json')
      table.insert(command, '--data')
      table.insert(command, body)
    else
      table.insert(command, url)
      for _, body_line in ipairs(body_lines) do
        local param_key, param_value = body_line:match('^%s*([%w_%%%-]+)%s*=%s*(.+)$')
        if param_key and param_value then
          table.insert(command, '--data-urlencode')
          table.insert(command, string.format('%s=%s', param_key, param_value))
        end
      end
    end
    utils.execute_shell(command, handle_curl_result)
    return
  end
  if (method == 'GET' or method == 'DELETE') and #body_lines > 0 then
    local query = {}
    for _, body_line in ipairs(body_lines) do
      local param_key, param_value = body_line:match('^%s*([%w_%%%-]+)%s*=%s*(.+)$')
      if param_key and param_value then
        table.insert(query, param_key .. '=' .. param_value)
      end
    end
    if #query > 0 then
      url = url .. (url:find('?', 1, true) and '&' or '?') .. table.concat(query, '&')
    end
  end
  table.insert(command, url)
  utils.execute_shell(command, handle_curl_result)
end

return { execute = execute }
