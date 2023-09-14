-- Import
local regex = require('fido.regex')

-- Helpers
local function parse_http(line)
  local method, url, path = nil, nil, nil

  if string.find(line, regex.method_url) then
    method, url = string.match(line, regex.method_url)
  elseif string.find(line, regex.url) then
    url = string.match(line, regex.url)
  elseif string.find(line, regex.method_path) then
    method, path = string.match(line, regex.method_path)
  elseif string.find(line, regex.path) then
    path = string.match(line, regex.path)
  else
    return nil
  end

  return { method = method, url = url, path = path }
end

local function escape_quotes(line)
  return vim.trim(line):gsub('"', '\\"'):gsub("'", "'\\''")
end

return {
  setup = function() end,

  fetch = function()
    return require('fido').fetch({
      name = 'HTTP',
      vertical = true,
      parse_buffer = true,
      execute = function(buffer)
        local args = vim.list_extend({
          '--silent',
          '--show-error',
          '--location',
          '--include',
        }, buffer.flags)

        local method, url, path = 'GET', '', ''
        for _, line in pairs(buffer.header) do
          local http = parse_http(line)

          if http then
            method = string.upper(http.method or method)
            url = http.url or url
            path = http.path or path
          else
            -- Parse HTTP Headers
            if string.find(line, regex.key_colon_value) then
              local key, value = string.match(line, regex.key_colon_value)
              table.insert(args, '--header "' .. key .. ': ' .. vim.trim(value) .. '"')
            end
          end
        end

        local body = vim.tbl_filter(function(line)
          return not string.find(line, regex.empty_line)
        end, buffer.body)

        -- Parse HTTP schema from the body
        if #body > 0 then
          local http = parse_http(body[1])

          if http then
            method = string.upper(http.method or method)
            url = http.url or url
            path = http.path or path
          end
        end

        local query_params = ''
        if #body > 1 then
          local data = vim.list_slice(body, 2)

          local key_values = {}
          for _, line in pairs(data) do
            if string.find(line, regex.key_equals_value) then
              local key, value = string.match(line, regex.key_equals_value)
              table.insert(key_values, key .. '=' .. vim.trim(value))
            end
          end

          if #key_values > 0 then
            if method == 'POST' then
              table.insert(args, '--header "Content-Type: application/x-www-form-urlencoded"')
              for _, key_value in pairs(key_values) do
                table.insert(args, '--data-urlencode "' .. key_value .. '"')
              end
            else
              query_params = table.concat(key_values, '&')
            end
          else
            table.insert(args, '--header "Content-Type: application/json"')

            if method == 'GQL' then
              -- GraphQL
              method = 'POST'
              table.insert(
                args,
                '--data \'{"query": "' .. table.concat(vim.tbl_map(escape_quotes, data), ' ') .. '"}\''
              )
            else
              -- JSON
              table.insert(args, "--data '" .. table.concat(data, ' ') .. "'")
            end
          end
        end

        -- Method
        table.insert(args, '--request ' .. method)

        -- Full URL
        local full_url = url .. path
        table.insert(
          args,
          '"'
            .. full_url
            .. (#query_params > 0 and (string.find(full_url, '?') and '&' or '?') .. query_params or '')
            .. '"'
        )

        return 'curl ' .. table.concat(args, ' '), nil
      end,

      process = function(lines)
        for _, line in pairs(lines) do
          local lowercase_line = string.lower(line)

          if string.find(lowercase_line, '^content%-type:%s*application/json') then
            vim.bo.filetype = 'json'
          elseif string.find(lowercase_line, '^content%-type:%s*text/html') then
            vim.bo.filetype = 'html'
          elseif string.find(lowercase_line, '^content%-type:%s*text/css') then
            vim.bo.filetype = 'css'
          elseif string.find(lowercase_line, '^content%-type:%s*application/javascript') then
            vim.bo.filetype = 'javascript'
          end
        end

        return vim.tbl_map(function(line)
          return string.gsub(line, '%c+$', '')
        end, lines)
      end,
    })
  end,
}
