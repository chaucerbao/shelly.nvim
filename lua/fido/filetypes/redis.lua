-- Import
local regex = require('fido.regex')

return function()
  return require('fido').fetch({
    name = 'Redis',
    parse_buffer = true,
    execute = function(buffer)
      local args = vim.list_extend({
        '--no-raw',
      }, buffer.flags)

      -- Parse the Connection String
      for _, line in pairs(buffer.header) do
        if string.find(line, regex.url_schema) then
          table.insert(args, '-u "' .. line .. '"')
        end
      end

      return 'redis-cli ' .. table.concat(args, ' '), buffer.body
    end,
  })
end
