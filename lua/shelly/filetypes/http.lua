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
    local http_method, request_url = line_text:match('^(%u+)%s+(%w[%w+.-]*://%S+)')
    if http_method and request_url then
      return string.upper(http_method), request_url, line_index
    end
  end
  for line_index, line_text in ipairs(lines) do
    local request_url = line_text:match('(%w[%w+.-]*://%S+)')
    if request_url then
      return 'GET', request_url, line_index
    end
  end
  return 'GET', '', 0
end

--- Executes HTTP requests using curl.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  if #evaluated.lines == 0 then
    return vim.schedule(function()
      callback({ stdout = {}, stderr = { 'No HTTP request to execute' } })
    end)
  end

  local method, url, start_idx = parse_method_url(evaluated.lines)

  local lines_after_method_url = vim.list_slice(evaluated.lines, start_idx + 1)
  evaluated.lines = {}
  evaluated = utils.evaluate(lines_after_method_url, { previous = evaluated, parse_text_lines = true })

  local body_lines = {}
  for line_index = start_idx + 1, #evaluated.lines do
    if evaluated.lines[line_index] and evaluated.lines[line_index]:match('%S') then
      body_lines[#body_lines + 1] = evaluated.lines[line_index]
    end
  end

  local command = { 'curl', '-i', '-s', '-L', '-X', (method == 'GQL' and 'POST' or method) }
  vim.list_extend(command, evaluated.command_args)

  if type(evaluated.dictionary) == 'table' then
    for key, value in pairs(evaluated.dictionary) do
      table.insert(command, '-H')
      table.insert(command, string.format('%s: %s', key, value))
    end
  end

  local function handle_result(result)
    local headers, body_output = {}, {}
    local current_headers, in_headers = {}, true
    for _, output_line in ipairs(result.stdout) do
      if in_headers then
        if output_line == '' then
          if #current_headers > 0 then
            headers[#headers + 1] = current_headers
            current_headers = {}
          end
          in_headers = false
        else
          current_headers[#current_headers + 1] = output_line
        end
      else
        if output_line:match('^HTTP/%d') then
          if #current_headers > 0 then
            headers[#headers + 1] = current_headers
          end
          current_headers = { output_line }
          in_headers = true
        else
          body_output[#body_output + 1] = output_line
        end
      end
    end
    if #current_headers > 0 then
      headers[#headers + 1] = current_headers
    end

    local content_type
    for _, header_line in ipairs(headers[#headers] or {}) do
      content_type = header_line:lower():match('^content%-type:%s*([^;]+)')
      if content_type then
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
    local filetype = filetype_map[content_type or '']

    local include_headers = false
    for _, arg in ipairs(evaluated.command_args) do
      if arg == '-i' or arg == '--include' then
        include_headers = true
        break
      end
    end

    local final_output = {}
    if include_headers then
      for _, header_block in ipairs(headers) do
        for _, header_line in ipairs(header_block) do
          final_output[#final_output + 1] = header_line
        end
        final_output[#final_output + 1] = ''
      end
      for _, body_line in ipairs(body_output) do
        final_output[#final_output + 1] = body_line
      end
    else
      for _, body_line in ipairs(body_output) do
        final_output[#final_output + 1] = body_line
      end
    end
    callback({ stdout = final_output, stderr = result.stderr, filetype = include_headers and 'http' or filetype })
  end

  if method == 'GQL' then
    table.insert(command, url)
    table.insert(command, '-H')
    table.insert(command, 'Content-Type: application/json')
    table.insert(command, '--data')
    table.insert(command, vim.json.encode({ query = table.concat(body_lines, '\n') }))
    return utils.execute_shell(command, { shelly_args = evaluated.shelly_args }, handle_result)
  end

  if (method == 'POST' or method == 'PUT') and #body_lines > 0 then
    if is_json(table.concat(body_lines, '\n')) then
      table.insert(command, url)
      table.insert(command, '-H')
      table.insert(command, 'Content-Type: application/json')
      table.insert(command, '--data')
      table.insert(command, table.concat(body_lines, '\n'))
    else
      table.insert(command, url)
      for _, body_line in ipairs(body_lines) do
        local key, value = body_line:match('^%s*([%w_%%%-]+)%s*=%s*(.+)$')
        if key and value then
          table.insert(command, '--data-urlencode')
          table.insert(command, string.format('%s=%s', key, value))
        end
      end
    end
    return utils.execute_shell(command, { shelly_args = evaluated.shelly_args }, handle_result)
  end

  if (method == 'GET' or method == 'DELETE') and #body_lines > 0 then
    local query_params = {}
    for _, body_line in ipairs(body_lines) do
      local key, value = body_line:match('^%s*([%w_%%%-]+)%s*=%s*(.+)$')
      if key and value then
        query_params[#query_params + 1] = key .. '=' .. value
      end
    end
    if #query_params > 0 then
      url = url .. (url:find('?', 1, true) and '&' or '?') .. table.concat(query_params, '&')
    end
  end

  table.insert(command, url)
  utils.execute_shell(command, { shelly_args = evaluated.shelly_args }, handle_result)
end

return { execute = execute }
