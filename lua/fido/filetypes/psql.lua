-- Import
local regex = require('fido.regex')

return function()
  return require('fido').fetch({
    name = 'PostgreSQL',
    execute = function(params)
      local args = params.flags

      -- Parse the Connection String
      for _, line in pairs(params.header) do
        if string.find(line, regex.url_schema) then
          table.insert(args, '--dbname="' .. line .. '"')
        end
      end

      return 'psql ' .. table.concat(args, ' '), params.body
    end,
  })
end
