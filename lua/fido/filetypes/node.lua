return {
  setup = function() end,

  fetch = function()
    return require('fido').fetch({
      name = 'Node',
      vertical = true,
      parse_buffer = true,
      execute = function(buffer)
        return 'node ' .. table.concat(buffer.flags, ' '), buffer.body
      end,
    })
  end,
}
