-- Import
local regex = require('fido.regex')

return function()
  return require('fido').fetch({
    name = 'Redis',
    execute = function(params)
      local args = vim.list_extend({
        '--no-raw',
      }, params.flags)

      -- Parse the Connection String
      for _, line in pairs(params.header) do
        if string.find(line, regex.url_schema) then
          table.insert(args, '-u "' .. line .. '"')
        end
      end

      return 'redis-cli ' .. table.concat(args, ' '), params.body
    end,
  })
end
