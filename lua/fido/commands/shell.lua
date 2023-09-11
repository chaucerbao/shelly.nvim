return {
  create = function(params)
    vim.api.nvim_create_user_command(params.command, function(args)
      require('fido').fetch({
        name = 'Shell',
        vertical = args.bang,
        execute = function()
          return args.args:gsub('%%', vim.fn.expand('%')), nil
        end,
      })
    end, { nargs = '*', bang = true })
  end,
}
