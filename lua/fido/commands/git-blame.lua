return {
  create = function(params)
    vim.api.nvim_create_user_command(params.command, function()
      local current_line = vim.fn.line('.')

      require('fido').fetch({
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
            table.insert(args, '"' .. vim.fn.bufname('#') .. '"')
          else
            table.insert(args, '--')
            table.insert(args, '"' .. vim.fn.expand('%') .. '"')
          end

          return 'git blame ' .. table.concat(args, ' '), nil
        end,
        process = function(lines, args)
          vim.defer_fn(function()
            args.window.child.focus()
            vim.cmd('silent normal ' .. current_line .. 'Gzz')
          end, 0)

          return lines
        end,
      })
    end, { nargs = '*' })
  end,
}
