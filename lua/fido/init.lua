-- Import
local filetypes = require('fido.filetypes')
local regex = require('fido.regex')

local setup_params = {}

-- Helpers
local function trim_lines(lines)
  local start_index, end_index = nil, nil

  for i, line in ipairs(lines) do
    if not string.find(line, regex.empty_line) then
      if start_index == nil then
        start_index = i
      end

      end_index = i
    end
  end

  if start_index == nil and end_index == nil then
    return {}
  end

  return vim.list_slice(lines, start_index, end_index)
end

local function create_window_reference(winid)
  return {
    winid = winid,
    bufnr = vim.fn.winbufnr(winid),
    focus = function()
      vim.fn.win_gotoid(winid)
    end,
  }
end

local function create_window_pair(params)
  local name = vim.fn.escape('[' .. params.name .. ']', '[]')

  local parent_winid = vim.fn.bufwinid('%')
  local child_winid = vim.fn.bufwinid(name)

  if child_winid < 0 then
    if params.vertical then
      local winwidth = vim.fn.winwidth(0)
      vim.cmd('vnew ' .. name)
      vim.cmd('vertical resize ' .. math.floor(winwidth / 100 * (params.size or 40)))
    else
      local winheight = vim.fn.winheight(0)
      vim.cmd('new ' .. name)
      vim.cmd('resize ' .. math.floor(winheight / 100 * (params.size or 25)))
    end

    -- Convert to a scratch buffer
    vim.bo.bufhidden = 'wipe'
    vim.bo.buflisted = false
    vim.bo.buftype = 'nofile'
    vim.bo.swapfile = false

    child_winid = vim.fn.win_getid()
  end

  local window = {
    parent = create_window_reference(parent_winid),
    child = create_window_reference(child_winid),
  }

  if setup_params.close_mapping and vim.fn.mapcheck(setup_params.close_mapping, 'n') == '' then
    for _, window_reference in pairs(window) do
      vim.keymap.set('n', setup_params.close_mapping, function()
        vim.cmd(window.child.bufnr .. 'bdelete')
        window.parent.focus()
        vim.keymap.del('n', setup_params.close_mapping, { buffer = window.parent.bufnr })
      end, { buffer = window_reference.bufnr })
    end
  end

  return window
end

local function apply_variables(header, body)
  local variables = {}
  local flags = {}

  local filtered_header = {}
  for _, line in pairs(header) do
    if string.find(line, regex.flag) then
      -- Parse flags
      table.insert(flags, vim.trim(line))
    else
      -- Parse variables
      local key, value = string.match(line, regex.key_equals_value)

      if key then
        variables[key] = value
      else
        -- Keep lines that are not variable declarations
        table.insert(filtered_header, line)
      end
    end
  end

  local function expand_variables(lines)
    return vim.tbl_map(function(line)
      local translated_line = line

      for key, value in pairs(variables) do
        translated_line = string.gsub(translated_line, key, value)
      end

      return translated_line
    end, lines)
  end

  return {
    header = expand_variables(filtered_header),
    body = expand_variables(body),
    flags = flags,
  }
end

local render
render = function(_lines, params, _window)
  local window = _window or create_window_pair(params)
  local lines = trim_lines(_lines)

  window.child.focus()

  -- Replace scratch buffer contents
  vim.bo.readonly = false
  vim.cmd('silent normal gg"_dG')
  vim.api.nvim_buf_set_lines(
    0,
    0,
    -1,
    false,
    params.process and params.process(lines, { window = window, render = render }) or lines
  )
  vim.bo.readonly = true

  -- Go to the top
  vim.cmd('normal gg')
end

local function parse_buffer()
  local lines = vim.fn.getline(1, '$')
  local cursor_index = vim.fn.line('.')

  -- Parse the `header` section
  local header_separator_index = -1
  for index, line in pairs(lines) do
    if string.find(line, regex.header_separator) then
      header_separator_index = index
    end
  end

  -- Parse the `body` section
  local body_separator_indexes = {}
  table.insert(body_separator_indexes, header_separator_index)
  for index, line in pairs(lines) do
    if string.find(line, regex.body_separator) then
      table.insert(body_separator_indexes, index)
    end
  end

  -- Move the `cursor_index` out of the `header` section
  if cursor_index <= header_separator_index then
    cursor_index = header_separator_index + 1
  end

  local min_index = 1
  local max_index = #lines
  for _, separator_index in pairs(body_separator_indexes) do
    -- If the `cursor_index` is on a separator, move it to the next section
    if cursor_index == separator_index and cursor_index < #lines then
      cursor_index = cursor_index + 1
    end

    -- Find the section that the `cursor_index` is in
    if separator_index < cursor_index and separator_index > 1 then
      min_index = separator_index + 1
    end
    if separator_index > cursor_index and separator_index < max_index then
      max_index = separator_index - 1
    end
  end

  return apply_variables(
    vim.tbl_map(
      vim.trim,
      vim.tbl_filter(
        -- Remove lines that are empty or commented out
        function(line)
          return not (string.find(line, regex.empty_line) or string.find(line, regex.comment))
        end,
        header_separator_index > 1 and vim.fn.getline(1, header_separator_index - 1) or {}
      )
    ),
    vim.fn.getline(min_index, max_index)
  )
end

return {
  setup = function(params)
    setup_params = params
    filetypes.setup()
  end,

  fetch = function(params)
    local starting_winid = vim.fn.win_getid()

    local cmd, stdin = params.execute(params.parse_buffer and parse_buffer() or nil)
    local window = create_window_pair(params)

    local output = {}
    local function render_output(job_id, data, event)
      local lines = trim_lines(data)

      if #lines > 0 then
        vim.list_extend(output, lines)
      end

      render(output, params, window)
    end

    local job_id = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = render_output,
      on_stderr = render_output,
      on_exit = function()
        if params.focus == 'parent' then
          window.parent.focus()
        elseif params.focus == 'child' then
          window.child.focus()
        else
          vim.fn.win_gotoid(starting_winid)
        end

        print(cmd)
      end,
    })

    if stdin then
      vim.fn.chansend(job_id, stdin)
      vim.fn.chanclose(job_id, 'stdin')
    end

    return {
      job_id = job_id,
      stop = function()
        return vim.fn.jobstop(job_id)
      end,
    }
  end,

  fetch_by_filetype = function()
    if vim.bo.filetype == 'http' then
      filetypes.http.fetch()
    elseif vim.bo.filetype == 'node' then
      filetypes.node.fetch()
    elseif vim.bo.filetype == 'redis' then
      filetypes.redis.fetch()
    elseif vim.bo.filetype == 'sql' then
      filetypes.sql.fetch()
    end
  end,
}
