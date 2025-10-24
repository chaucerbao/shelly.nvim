local utils = require('shelly.utils')

local M = {}

--- Display results in a scratch buffer
---@param result {stdout: string[], stderr: string[]} Execution results
---@param use_vertical boolean Whether to use vertical split
--- Display results in a scratch buffer window.
---
--- Combines stdout and stderr, creates or reuses a scratch buffer, and displays output.
---
--- @param result table Table with 'stdout' and 'stderr' string arrays
--- @param use_vertical boolean Whether to use vertical split for display
local function display_results(result, use_vertical)
  -- Combine stdout and stderr
  local output = {}

  if #result.stdout > 0 then
    table.insert(output, '=== Output ===')
    for _, line in ipairs(result.stdout) do
      table.insert(output, line)
    end
  end

  if #result.stderr > 0 then
    if #output > 0 then
      table.insert(output, '')
    end
    table.insert(output, '=== Errors ===')
    for _, line in ipairs(result.stderr) do
      table.insert(output, line)
    end
  end

  if #output == 0 then
    table.insert(output, '(no output)')
  end

  -- Create or reuse scratch buffer
  local scratch_bufnr = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].filetype == 'shelly-output' then
      scratch_bufnr = bufnr
      break
    end
  end

  if not scratch_bufnr or not vim.api.nvim_buf_is_valid(scratch_bufnr) then
    scratch_bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[scratch_bufnr].filetype = 'shelly-output'
    vim.bo[scratch_bufnr].buftype = 'nofile'
    vim.bo[scratch_bufnr].bufhidden = 'hide'
    vim.bo[scratch_bufnr].swapfile = false
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(scratch_bufnr, 0, -1, false, output)
  vim.bo[scratch_bufnr].modifiable = false

  -- Find window showing the scratch buffer
  local scratch_winnr = nil
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winnr) == scratch_bufnr then
      scratch_winnr = winnr
      break
    end
  end

  -- Open in split if not already visible
  if not scratch_winnr then
    if use_vertical then
      vim.cmd('vsplit')
    else
      vim.cmd('split')
    end
    vim.api.nvim_win_set_buf(0, scratch_bufnr)
  else
    -- Focus the existing window
    vim.api.nvim_set_current_win(scratch_winnr)
  end
end

--- Execute the main entry point for Shelly.
---
--- Parses selection, determines filetype, loads appropriate runner, and executes code.
--- Displays results or error messages.
--- @return nil
function M.execute()
  -- Parse selection to get filetype
  local selection = utils.parse_selection()
  local filetype = selection.filetype

  -- Also evaluate the selection to check for shelly_args
  local evaluated = utils.evaluate(selection.lines)
  local use_vertical = false

  -- Check for vertical split preference
  if evaluated.shelly_args.vert or evaluated.shelly_args.vertical then
    use_vertical = true
  elseif evaluated.shelly_args.novert or evaluated.shelly_args.novertical then
    use_vertical = false
  end

  -- Map common filetypes to runner names
  local filetype_map = {
    python = 'python',
    lua = 'lua',
    javascript = 'javascript',
    typescript = 'typescript',
    sh = 'sh',
    bash = 'sh',
    sql = 'postgresql',
    postgresql = 'postgresql',
    redis = 'redis',
    markdown = 'markdown',
  }

  local runner_name = filetype_map[filetype] or filetype

  -- Try to load the appropriate runner
  local success, runner = pcall(require, 'shelly.filetypes.' .. runner_name)

  if not success or not runner.execute then
    vim.notify('No runner found for filetype: ' .. filetype, vim.log.levels.ERROR)
    return
  end

  --- Execute the runner, handling silent mode
  runner.execute(function(result)
    local silent = false
    if evaluated.shelly_args.silent == true then
      silent = true
    elseif evaluated.shelly_args.nosilent == true then
      silent = false
    end
    if silent then
      vim.notify('Runner finished executing (silent mode).', vim.log.levels.INFO)
      return
    end
    display_results(result, use_vertical)
  end)
end

return M
