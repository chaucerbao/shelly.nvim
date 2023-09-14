return {
  setup = function()
    vim.api.nvim_create_autocmd({ 'FileType' }, {
      group = vim.api.nvim_create_augroup('NodeSyntax', {}),
      pattern = { 'node' },
      callback = function()
        vim.defer_fn(function()
          vim.bo.syntax = 'typescript'
        end, 0)
      end,
    })
  end,

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
