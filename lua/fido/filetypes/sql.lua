-- Import
local regex = require('fido.regex')

return {
  setup = function() end,

  fetch = function()
    return require('fido').fetch({
      name = 'SQL',
      parse_buffer = true,
      execute = function(buffer)
        local args = buffer.flags

        -- Parse the Connection String
        local command = ''
        for _, line in pairs(buffer.header) do
          if string.find(line, regex.url_schema) then
            local scheme, uri = string.match(line, regex.url_schema)

            if string.find(scheme, 'postgres') then
              command = 'psql'
              table.insert(args, '--dbname="' .. line .. '"')
            elseif string.find(scheme, 'sqlite') then
              command = 'sqlite3'
              table.insert(args, '"file:' .. uri .. '"')
            end
          end
        end

        return command .. ' ' .. table.concat(args, ' '), buffer.body
      end,
    })
  end,
}
