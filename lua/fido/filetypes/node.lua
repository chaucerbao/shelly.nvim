return function()
  return require('fido').fetch({
    name = 'Node',
    vertical = true,
    execute = function(params)
      return 'node ' .. table.concat(params.flags, ' '), params.body
    end,
  })
end
