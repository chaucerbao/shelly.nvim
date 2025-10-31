local utils = require('shelly.utils')

local M = {}

--- Table to cache scratch buffers per filetype
---@type table<string, integer>
local scratch_buffers = {}

--- Display execution results in a scratch buffer, creating or reusing per filetype.
---@param result FiletypeRunnerResult Execution results
---@param filetype string Filetype for runner-specific buffer
---@param opts table|nil Optional table: { vertical = boolean, size = number }
local function display_results(result, filetype, opts)
  -- Combine stdout and stderr efficiently
  local output = vim.list_extend(vim.deepcopy(result.stdout), {})
  if #result.stderr > 0 then
    if #output > 0 then
      table.insert(output, '')
    end
    vim.list_extend(output, result.stderr)
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
  if result.filetype then
    vim.api.nvim_buf_set_option(scratch_bufnr, 'filetype', result.filetype)
  end
  vim.api.nvim_buf_set_lines(scratch_bufnr, 0, -1, false, output)

  -- Find window showing the scratch buffer
  local scratch_winnr
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
        vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * size / 100))
      end
    else
      vim.cmd('split')
      if size then
        vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * size / 100))
      end
    end
    vim.api.nvim_win_set_buf(0, scratch_bufnr)
    scratch_winnr = vim.api.nvim_get_current_win()
  else
    vim.api.nvim_set_current_win(scratch_winnr)
  end

  -- Scroll to the top of the scratch buffer
  vim.api.nvim_win_set_cursor(scratch_winnr, { 1, 0 })
end

--- Execute the main entry point for Shelly.
--- Parses selection, determines filetype, loads appropriate runner, and executes code.
--- Displays results or error messages.
---@return nil
function M.execute_selection()
  local selection = utils.get_selection()
  local until_line = selection.selection_type == 'buffer' and selection.line_end or selection.line_start
  local context = utils.get_context({ until_line = until_line })
  local filetype = selection.filetype

  -- Concatenate context and selection lines efficiently
  local lines = vim.list_extend(vim.deepcopy(context.lines), selection.lines)

  local evaluated = utils.evaluate(lines, { on_text = 'collect' })
  local use_vertical = evaluated.shelly_args.vert or evaluated.shelly_args.vertical or false
  if evaluated.shelly_args.novert or evaluated.shelly_args.novertical then
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

  ---@type boolean, { execute: FiletypeRunner } | string
  local success, runner = pcall(require, 'shelly.filetypes.' .. runner_name)
  if not (success and type(runner) == 'table' and type(runner.execute) == 'function') then
    vim.notify('No runner found for filetype: ' .. filetype, vim.log.levels.ERROR)
    return
  end

  runner.execute(evaluated, function(result)
    local silent = evaluated.shelly_args.silent == true
    if evaluated.shelly_args.nosilent == true then
      silent = false
    end
    if silent then
      vim.notify('Runner finished executing (silent mode).', vim.log.levels.INFO)
      return
    end
    local original_win = vim.api.nvim_get_current_win()
    display_results(result, filetype, { vertical = use_vertical })
    local focus = evaluated.shelly_args.focus == true
    if evaluated.shelly_args.nofocus == true then
      focus = false
    end
    if not focus and vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
  end)
end

--- Execute an arbitrary shell command and display results in a scratch buffer
---@param command string Shell command to execute
---@param opts table|nil Optional table: { vertical = boolean }
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
