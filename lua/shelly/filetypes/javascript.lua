local buffers = require('shelly.buffers')
local utils = require('shelly.utils')

--- @param scope scope
--- @param fence fence
local function evaluate(scope, fence)
  local args = {}

  -- Parse Scope
  for _, line in ipairs(scope.lines) do
    local arg = line:match(utils.arg_line_pattern)

    if arg then
      vim.list_extend(args, vim.split(arg, ' '))
    end
  end

  -- Parse Fence
  local body = {}
  for _, line in ipairs(fence.lines) do
    if #body == 0 then
      local arg = line:match(utils.arg_line_pattern)

      if arg then
        vim.list_extend(args, vim.split(arg, ' '))
      elseif #vim.trim(line) > 0 then
        table.insert(body, line)
      end
    else
      table.insert(body, line)
    end
  end

  local cmd = { 'node' }
  vim.list_extend(cmd, args)

  utils.run_shell_commands({ { cmd, { stdin = body } } }, function(jobs)
    local job = jobs[1]

    vim.schedule(function()
      local scratch_winid = buffers.render_scratch_buffer(
        vim.split((vim.trim(job.stderr):len() > 0 and (job.stderr .. '\n') or '') .. job.stdout, '\n'),
        { name = 'JavaScript', filetype = 'text', size = 40, vertical = true }
      )

      if vim.fn.win_getid() == scratch_winid then
        vim.cmd.wincmd('p')
      end
    end)
  end)
end

return {
  evaluate = evaluate,
}
