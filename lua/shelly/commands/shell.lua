local buffers = require('shelly.buffers')
local utils = require('shelly.utils')

--- @param command string
local function create(command)
  vim.api.nvim_create_user_command(command, function(args)
    local cmd = vim.tbl_map(function(arg)
      return arg:gsub('%%', vim.fn.expand('%'))
    end, args.fargs)

    if #cmd > 0 then
      utils.run_shell_commands({ { cmd } }, function(jobs)
        local job = jobs[1]

        vim.schedule(function()
          local scratch_winid = buffers.render_scratch_buffer(
            vim.split(job.stderr .. job.stdout, '\n'),
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
  create = create,
}
