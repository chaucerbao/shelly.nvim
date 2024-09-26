local config = require('shelly.config')
local utils = require('shelly.utils')

local syntax_alias = {
  js = 'javascript',
}

--- Gets all fences in the buffer
--- @return range[]
local function get_fences()
  local fences = {}
  local current_fence = nil

  local buffer_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(buffer_lines) do
    local fence_start = line:match('^%s*```(%a+)%s*$')
    local fence_end = line:match('^%s*```%s*$')

    if fence_start and not current_fence and i < #buffer_lines then
      local syntax = fence_start:lower()

      current_fence = { syntax = syntax_alias[syntax] or syntax, range = { i + 1 } }
    elseif fence_end and current_fence then
      table.insert(current_fence.range, i - 1)
      table.insert(fences, current_fence)
      current_fence = nil
    end
  end

  return fences
end

--- Gets the fence on the current line
--- @return fence | nil
local function get_current_fence()
  local current_line = vim.fn.line('.')
  local current_region = vim.fn.mode():match('^[Vv]') and { vim.fn.line('v'), current_line }

  if current_region then
    table.sort(current_region)
  end

  for _, fence in ipairs(get_fences()) do
    if fence.syntax ~= 'global' and current_line >= fence.range[1] - 1 and current_line <= fence.range[2] + 1 then
      local range_start, range_end =
        (current_region and math.max(fence.range[1], current_region[1]) or fence.range[1]),
        current_region and math.min(fence.range[2], current_region[2]) or fence.range[2]

      return vim.tbl_extend('force', fence, {
        range = { range_start, range_end },
        lines = vim.api.nvim_buf_get_lines(0, range_start - 1, range_end, false),
      })
    end
  end
end

--- Replaces variables with their values
--- @param variables { [string]: string }
--- @param lines string[]
--- @return string[]
local function expand_variables(variables, lines)
  return vim.tbl_map(function(line)
    for key, value in pairs(variables) do
      line = line:gsub(key, value)
    end

    return line
  end, lines)
end

--- Gets all `global` fences up to the `max_line`
--- @param max_line number | nil
--- @return global
local function get_global(max_line)
  -- Lines
  local global_lines = {}
  for _, fence in ipairs(get_fences()) do
    if max_line and fence.range[1] > max_line then
      break
    end

    if fence.syntax == 'global' then
      for _, line in ipairs(vim.api.nvim_buf_get_lines(0, fence.range[1] - 1, fence.range[2], false)) do
        table.insert(global_lines, line)
      end
    end
  end
  global_lines = utils.remove_empty_lines(global_lines)

  -- Variables
  local variables = {}
  local non_variable_lines = {}
  local variable_line_pattern = utils.create_key_value_line_pattern('=')
  for _, line in ipairs(global_lines) do
    local key, value = line:match(variable_line_pattern)

    if key and value then
      for k, v in pairs(variables) do
        value = value:gsub(k, v)
      end

      variables[key] = value
    else
      table.insert(non_variable_lines, line)
    end
  end

  return { lines = expand_variables(variables, non_variable_lines), variables = variables }
end

--- Gets the global and current fence
--- @return global | nil
--- @return fence | nil
local function parse_buffer()
  local selected_fence = get_current_fence()
  if not selected_fence then
    print('No selection')
    return
  end

  local global = get_global(selected_fence.range[1])

  return global,
    vim.tbl_extend('force', selected_fence, { lines = expand_variables(global.variables, selected_fence.lines) })
end

--- @param lines string[]
--- @param options { name: string, filetype: string | nil, size: number | nil, vertical: boolean }
--- @return number
local function render_scratch_buffer(lines, options)
  local name = vim.fn.escape('[' .. options.name .. ']', '[]')
  local scratch_winid = vim.fn.bufwinid(name)

  if scratch_winid < 0 then
    local size = options.size
        and math.floor((options.vertical and vim.fn.winwidth(0) or vim.fn.winheight(0)) / 100 * options.size)
      or ''

    vim.cmd(size .. (options.vertical and 'vnew' or 'new') .. ' ' .. name)
    scratch_winid = vim.fn.win_getid()

    local scratch_bufnr = vim.fn.winbufnr(scratch_winid)

    vim.bo[scratch_bufnr].bufhidden = 'hide'
    vim.bo[scratch_bufnr].swapfile = false
    vim.bo[scratch_bufnr].buflisted = false

    -- Allow LSP to attach
    vim.schedule(function()
      vim.bo[vim.fn.winbufnr(scratch_winid)].buftype = 'nofile'
    end)

    local current_config = config.get()
    if current_config.mappings and current_config.mappings.close then
      vim.keymap.set(
        { 'n' },
        current_config.mappings.close,
        ':' .. scratch_bufnr .. 'bdelete<CR>',
        { silent = true, buffer = scratch_bufnr }
      )
    end
  end

  local scratch_bufnr = vim.fn.winbufnr(scratch_winid)

  if options.filetype then
    vim.bo[scratch_bufnr].filetype = options.filetype
  end

  vim.api.nvim_buf_set_lines(scratch_bufnr, 0, -1, false, lines)
  vim.fn.win_execute(scratch_winid, 'normal! gg0')

  return scratch_winid
end

return {
  parse_buffer = parse_buffer,
  render_scratch_buffer = render_scratch_buffer,
}
