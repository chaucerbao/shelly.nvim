-- Import
local regex = require('fido.regex')

return {
  setup = function() end,

  fetch = function()
    return require('fido').fetch({
      name = 'PostgreSQL',
      parse_buffer = true,
      execute = function(buffer)
        local args = buffer.flags

        -- Parse the Connection String
        for _, line in pairs(buffer.header) do
          if string.find(line, regex.url_schema) then
            table.insert(args, '--dbname="' .. line .. '"')
          end
        end

        return 'psql ' .. table.concat(args, ' '), buffer.body
      end,
    })
  end,
}
