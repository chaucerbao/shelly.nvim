local buffers = require('shelly.buffers')

--- @param command string
local function create_shell(command)
  vim.api.nvim_create_user_command(command, function(args)
    if #args.fargs > 0 then
      vim.system(args.fargs, { text = true, timeout = 5 * 1000 }, function(job)
        vim.schedule(function()
          local scratch_winid = buffers.render_scratch_buffer(
            vim.split((job.code == 0) and job.stdout or job.stderr, '\n'),
            { name = 'Shell', filetype = 'text', size = 40, vertical = args.bang }
          )

          if vim.fn.win_getid() == scratch_winid then
            vim.cmd.wincmd('p')
          end
        end)
      end)
    else
      print('No shell command')
    end
  end, { nargs = '*', bang = true })
end

return {
  create_shell = create_shell,
}
