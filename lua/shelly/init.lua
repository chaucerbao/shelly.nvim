local utils = require('shelly.utils')

local M = {}

--- Table to cache scratch buffers per filetype
---@type table<string, integer>
local scratch_buffers = {}

---@param result FiletypeRunnerResult Execution results
---@param filetype string Filetype for runner-specific buffer
---@param opts table|nil Optional table: { vertical = boolean, size = number }
local function display_results(result, filetype, opts)
  -- Combine stdout and stderr
  local output = {}

  if #result.stdout > 0 then
    for _, line in ipairs(result.stdout) do
      table.insert(output, line)
    end
  end

  if #result.stderr > 0 then
    if #output > 0 then
      table.insert(output, '')
    end
    for _, line in ipairs(result.stderr) do
      table.insert(output, line)
    end
  end

  if #output == 0 then
    table.insert(output, '(no output)')
  end

  -- Create or reuse scratch buffer for this filetype
  local scratch_bufnr = scratch_buffers[filetype]
  if not scratch_bufnr or not vim.api.nvim_buf_is_valid(scratch_bufnr) then
    scratch_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(scratch_bufnr, 'shelly://' .. filetype .. '-results')
    scratch_buffers[filetype] = scratch_bufnr
  end
  -- Set buffer filetype only if result.filetype is not nil
  if result.filetype ~= nil then
    vim.bo[scratch_bufnr].filetype = result.filetype
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(scratch_bufnr, 0, -1, false, output)

  -- Find window showing the scratch buffer
  local scratch_winnr = nil
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winnr) == scratch_bufnr then
      scratch_winnr = winnr
      break
    end
  end

  -- Open in split if not already visible
  local vertical = opts and opts.vertical or false
  local size = opts and type(opts.size) == 'number' and opts.size or nil
  if not scratch_winnr then
    if vertical then
      vim.cmd('vsplit')
      if size then
        local total_cols = vim.o.columns
        local win_width = math.floor(total_cols * size / 100)
        vim.api.nvim_win_set_width(0, win_width)
      end
    else
      vim.cmd('split')
      if size then
        local total_lines = vim.o.lines
        local win_height = math.floor(total_lines * size / 100)
        vim.api.nvim_win_set_height(0, win_height)
      end
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
function M.execute_selection()
  local selection = utils.get_selection()
  local until_line = selection.line_start
  if selection.selection_type == 'buffer' then
    until_line = selection.line_end
  end
  local context = utils.get_context({ until_line = until_line })
  local filetype = selection.filetype

  -- Concatenate context and selection lines
  local lines = {}
  for _, line in ipairs(context.lines) do
    table.insert(lines, line)
  end
  for _, line in ipairs(selection.lines) do
    table.insert(lines, line)
  end

  -- Evaluate the combined lines
  local evaluated = utils.evaluate(lines)
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
    typescript = 'javascript',
    sh = 'sh',
    bash = 'sh',
    sql = 'postgresql',
    postgresql = 'postgresql',
    redis = 'redis',
    markdown = 'markdown',
  }

  local runner_name = filetype_map[filetype] or filetype

  -- Try to load the appropriate runner
  ---@type boolean, { execute: FiletypeRunner } | string
  local success, runner = pcall(require, 'shelly.filetypes.' .. runner_name)

  if not (success and type(runner) == 'table' and type(runner.execute) == 'function') then
    vim.notify('No runner found for filetype: ' .. filetype, vim.log.levels.ERROR)
    return
  end

  --- Execute the runner, handling silent mode
  runner.execute(evaluated, function(result)
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

    local original_win = vim.api.nvim_get_current_win()
    display_results(result, filetype, { vertical = use_vertical })

    local focus = false
    if evaluated.shelly_args.focus == true then
      focus = true
    elseif evaluated.shelly_args.nofocus == true then
      focus = false
    end
    if not focus then
      -- Move cursor back to original window
      if vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
      end
      return
    end
  end)
end

--- Execute an arbitrary shell command and display results in a scratch buffer
--- @param command string Shell command to execute
--- @param opts table|nil Optional table: { vertical = boolean }
function M.execute_shell(command, opts)
  opts = opts or {}
  local use_vertical = opts.vertical or false

  if type(command) ~= 'string' or command == '' then
    vim.notify('No shell command provided.', vim.log.levels.ERROR)
    return
  end

  local success, runner = pcall(require, 'shelly.filetypes.sh')
  if not (success and type(runner) == 'table' and type(runner.execute) == 'function') then
    vim.notify('No shell runner found.', vim.log.levels.ERROR)
    return
  end

  local evaluated = utils.evaluate({ command })
  runner.execute(evaluated, function(result)
    display_results(result, 'shell', { vertical = use_vertical })
  end)
end

return M
