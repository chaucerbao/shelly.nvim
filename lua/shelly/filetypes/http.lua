local buffers = require('shelly.buffers')
local utils = require('shelly.utils')

local function is_header(line)
  return line:match('^(%w)') ~= nil
end

--- @param global global
--- @param fence fence
local function evaluate(global, fence)
  local url_prefix = ''
  local args = {
    '--location', -- Follow redirects
    '--silent', -- Silent mode
    '--show-error', -- Show error even when -s is used

    -- Write the received headers to <filename>
    '--dump-header',
    '/dev/stderr',
  }
  local headers = {}
  local header_line_pattern = utils.create_key_value_line_pattern(':')
  local method_url_line_patterns = {
    utils.create_line_pattern('(%a+)%s+' .. utils.uri_pattern),
    utils.create_line_pattern('(%a+)%s+(/.*%S)'),
    utils.create_line_pattern(utils.uri_pattern),
    utils.create_line_pattern('(/.*%S)'),
  }

  -- Parse Global
  for _, line in ipairs(global.lines) do
    local url = line:match(utils.uri_line_pattern)
    local arg = line:match(utils.arg_line_pattern)
    local key, value = line:match(header_line_pattern)

    if url then
      url_prefix = url
    elseif arg then
      vim.list_extend(args, vim.split(arg, ' '))
    elseif key and value and is_header(key) then
      headers[key] = value
    end
  end

  -- Parse Fence
  local method, url, body = nil, nil, {}
  for _, line in ipairs(utils.remove_empty_lines(fence.lines)) do
    if #body == 0 then
      local http_method, http_url = nil, nil
      local arg = line:match(utils.arg_line_pattern)
      local key, value = line:match(header_line_pattern)

      for _, pattern in ipairs(method_url_line_patterns) do
        local x, y = line:match(pattern)

        if x and y then
          http_method, http_url = x, y
          break
        elseif x then
          http_url = x
          break
        end
      end

      if http_url then
        method = ((http_method and #http_method > 0) and http_method or 'GET'):upper()
        url = http_url:match(utils.uri_pattern) and http_url or (url_prefix .. http_url)
      elseif arg then
        vim.list_extend(args, vim.split(arg, ' '))
      elseif key and value and is_header(key) then
        headers[key] = value
      else
        table.insert(body, line)
      end
    else
      table.insert(body, line)
    end
  end

  local cmd = { 'curl' }
  vim.list_extend(cmd, args)

  for key, value in pairs(headers) do
    table.insert(cmd, '--header')
    table.insert(cmd, key .. ': ' .. value)
  end

  if #body > 0 then
    if method == 'GQL' then
      table.insert(cmd, '--json')
      table.insert(cmd, '{ "query": "' .. utils.escape_quotes(table.concat(body, ' ')) .. '" }')
    elseif body[1]:match('^[{%[]') then
      table.insert(cmd, '--json')
      table.insert(cmd, table.concat(body, ' '))
    else
      for _, line in ipairs(body) do
        table.insert(cmd, '--data-urlencode')
        table.insert(cmd, line)
      end
    end
  end

  if method == 'GET' then
    table.insert(cmd, '--get')
  else
    table.insert(cmd, '--request')
    table.insert(cmd, (method == 'GQL') and 'POST' or method)
  end

  table.insert(cmd, url)

  utils.run_shell_commands({ { cmd } }, function(jobs)
    local job = jobs[1]

    vim.schedule(function()
      local mime_to_filetype = {
        css = 'css',
        csv = 'csv',
        html = 'html',
        javascript = 'javascript',
        json = 'json',
        xml = 'xml',
      }

      -- Parse Response Headers
      local filetype = 'text'
      for _, line in ipairs(utils.remove_empty_lines(vim.split(job.stderr, '\n'))) do
        local key, value = line:match(header_line_pattern)

        if key and is_header(key) and key:lower() == 'content-type' then
          value = value:lower()

          for mime_type, related_filetype in pairs(mime_to_filetype) do
            if value:find(mime_type) then
              filetype = related_filetype
              break
            end
          end
        end
      end

      local scratch_winid = buffers.render_scratch_buffer(
        vim.split(vim.trim(job.stdout):len() > 0 and job.stdout or job.stderr, '\n'),
        { name = 'HTTP', filetype = filetype, size = 40, vertical = true }
      )

      if vim.fn.win_getid() == scratch_winid then
        vim.cmd.wincmd('p')
      end
    end)
  end)
end

return {
  evaluate = evaluate,
}
