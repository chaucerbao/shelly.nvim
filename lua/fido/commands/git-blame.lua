-- Imports
local fido = require('fido')

-- Helpers
function reblame()
  fido.fetch({
    name = 'GitBlame',
    vertical = true,
    execute = function()
      local args = {
        '-c',
        '--date=short',
      }

      table.insert(args, '--')
      table.insert(args, vim.fn.expand('%'))

      return 'git blame ' .. table.concat(args, ' '), nil
    end,
    process = function(lines, window)
      if vim.fn.empty(vim.fn.mapcheck(params.reblame_mapping, 'n')) then
        vim.keymap.set('n', params.reblame_mapping, function()
          vim.cmd('normal 0')

          local revision = vim.fn.expand('<cword>')

          local args = {
            '-c',
            '--date=short',
          }

          table.insert(args, revision .. '^1')
          table.insert(args, '--')
          table.insert(args, vim.fn.bufname(window.parent.bufnr))

          local cmd = 'git blame ' .. table.concat(args, ' ')
          local response_lines = vim.fn.systemlist(cmd)

          local line = vim.fn.line('.')
          window.child.replace_buffer(response_lines)
          vim.cmd('normal ' .. line .. 'ggzz')

          print(cmd)
        end, { buffer = window.child.bufnr })
      end
    end,
  })
end

return function(params)
  vim.api.nvim_create_user_command(params.command, function()
    fido.fetch({
      name = 'GitBlame',
      vertical = true,
      execute = function()
        local args = {
          '-c',
          '--date=short',
        }

        if vim.fn.expand('%') == '[GitBlame]' then
          vim.cmd('normal 0')

          local revision = vim.fn.expand('<cword>')

          table.insert(args, revision .. '^1')
          table.insert(args, '--')
          table.insert(args, vim.fn.bufname('#'))
        else
          table.insert(args, '--')
          table.insert(args, vim.fn.expand('%'))
        end

        return 'git blame ' .. table.concat(args, ' '), nil
      end,
    })
  end, { nargs = '*' })
end
