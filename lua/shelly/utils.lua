local M = {}

--- Remove common code comment prefixes from a line.
---
--- Supports //, #, --, ;, /*, */ and /** */.
--- @param line string Line to clean
--- @return string Cleaned line
local function remove_comment_prefix(line)
  -- Remove common line comment prefixes: //, #, --, ;
  local cleaned = line:gsub('^%s*//', ''):gsub('^%s*#', ''):gsub('^%s*%-%-', ''):gsub('^%s*;', '')
  -- Remove block comment markers: /* */ /** */
  cleaned = cleaned:gsub('^%s*/%*+%s*', ''):gsub('%s*%*+/%s*$', '')
  return cleaned
end

--- Check if a line is within a markdown code block.
---
--- Searches for code block fences and language identifier.
--- @param lines string[] List of all buffer lines
--- @param line_num integer Current line number (1-indexed)
--- @return boolean is_in_block True if in code block
--- @return string|nil language Language identifier if present
--- @return integer|nil start_line Starting line of code block
--- @return integer|nil end_line Ending line of code block
local function get_markdown_code_block(lines, line_num)
  local start_line, lang = nil, nil

  -- Search backwards for opening fence
  for i = line_num, 1, -1 do
    local line = lines[i]
    if line:match('^```') then
      local match = line:match('^```(%S*)')
      if match then
        start_line = i
        lang = match ~= '' and match or nil
        break
      end
    end
  end

  if not start_line then
    return false, nil, nil, nil
  end

  -- Search forwards for closing fence
  for i = line_num + 1, #lines do
    if lines[i]:match('^```%s*$') then
      return true, lang, start_line, i
    end
  end

  return false, nil, nil, nil
end

--- Parse the current selection and determine lines and filetype.
---
--- Priority: visual selection > markdown code block > entire buffer.
--- @return table Table with 'lines' (string[]) and 'filetype' (string)
function M.parse_selection()
  local mode = vim.fn.mode()
  local lines = {}
  local filetype = vim.bo.filetype

  -- Priority 1: Visual selection
  if mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is <C-v>
    local start_pos = vim.fn.getpos('v')
    local end_pos = vim.fn.getpos('.')
    local start_line = math.min(start_pos[2], end_pos[2])
    local end_line = math.max(start_pos[2], end_pos[2])

    if mode == '\22' then -- Block-wise visual
      local start_col = math.min(start_pos[3], end_pos[3])
      local end_col = math.max(start_pos[3], end_pos[3])
      for i = start_line, end_line do
        local line = vim.fn.getline(i)
        table.insert(lines, line:sub(start_col, end_col))
      end
    else
      lines = vim.fn.getline(start_line, end_line)
      if type(lines) == 'string' then
        lines = { lines }
      end
    end

    return {
      lines = lines,
      filetype = filetype,
      line_start = start_line,
      line_end = end_line,
    }
  end

  -- Priority 2: Markdown code block surrounding current line
  local bufnr = vim.api.nvim_get_current_buf()
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor_line = vim.fn.line('.')

  local in_block, lang, start_line, end_line = get_markdown_code_block(all_lines, cursor_line)
  if in_block and start_line and end_line then
    for i = start_line + 1, end_line - 1 do
      table.insert(lines, all_lines[i])
    end
    if lang then
      filetype = lang
    end
    return {
      lines = lines,
      filetype = filetype,
      line_start = start_line + 1,
      line_end = end_line - 1,
    }
  end

  -- Priority 3: Entire buffer
  return {
    lines = all_lines,
    filetype = filetype,
    line_start = 1,
    line_end = #all_lines,
  }
end

--- Parse context from markdown code blocks with 'context' or 'ctx' identifier.
---
--- Returns a table with 'lines' (string[]) from context blocks up to current code block.
--- @return table Table with 'lines' (string[])
function M.parse_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor_line = vim.fn.line('.')
  local context_lines = {}

  local i = 1
  while i <= #all_lines do
    local line = all_lines[i]

    -- Check for context code block
    local lang = line:match('^```(%S+)')
    if lang and (lang == 'context' or lang == 'ctx') then
      -- Found a context block, extract its contents
      i = i + 1
      while i <= #all_lines and not all_lines[i]:match('^```%s*$') do
        local content = remove_comment_prefix(all_lines[i])
        -- Skip empty lines in context
        if not content:match('^%s*$') then
          table.insert(context_lines, content)
        end
        i = i + 1
      end

      -- Stop if we've reached the current code block
      if i >= cursor_line then
        break
      end
    end

    i = i + 1
  end

  return { lines = context_lines }
end

--- Evaluate lines to extract Shelly syntax: args, substitutions, dictionaries, command args, URLs.
---
--- Removes comment prefixes, parses special lines, applies substitutions.
--- @param lines string[] Lines to evaluate
--- @return table Table with shelly_args, shelly_substitutions, dictionary, command_args, urls, processed_lines
function M.evaluate(lines)
  local shelly_args = {}
  local shelly_substitutions = {}
  local dictionary = {}
  local command_args = {}
  local urls = {}
  local processed_lines = {}

  for _, line in ipairs(lines) do
    -- Remove comment prefixes
    local cleaned = remove_comment_prefix(line)

    -- Skip empty lines
    if cleaned:match('^%s*$') then
      goto continue
    end

    -- Check for @@shelly_args
    local arg_match = cleaned:match('^%s*@@(%S+)')
    if arg_match then
      local key, value = arg_match:match('^([^=]+)=(.+)$')
      if key and value then
        shelly_args[key] = value:match('^%s*(.-)%s*$') -- trim
      elseif arg_match:match('^no') then
        shelly_args[arg_match] = false
      else
        shelly_args[arg_match] = true
      end
      goto continue
    end

    -- Check for substitutions (key = value)
    local var_key, var_value = cleaned:match('^%s*(%S+)%s*=%s*(.+)%s*$')
    if var_key and var_value and not cleaned:match('^%-%-') and not cleaned:match('^%-[^-]') then
      shelly_substitutions[var_key] = var_value
      goto continue
    end

    -- Check for dictionary entries (key: value)
    local dict_key, dict_value = cleaned:match('^%s*(%S+)%s*:%s*(.+)%s*$')
    if dict_key and dict_value then
      dictionary[dict_key] = dict_value
      goto continue
    end

    -- Check for command line arguments
    if cleaned:match('^%-%-[%w-]+$') or cleaned:match('^%-[%w]$') then
      table.insert(command_args, cleaned:match('^%s*(.-)%s*$'))
      goto continue
    end

    -- Check for URLs
    if cleaned:match('^https?://') or cleaned:match('^ftp://') then
      table.insert(urls, cleaned:match('^%s*(.-)%s*$'))
      goto continue
    end

    -- Apply substitutions
    local processed = cleaned
    for var_key, var_value in pairs(shelly_substitutions) do
      processed = processed:gsub(var_key, var_value)
    end

    table.insert(processed_lines, processed)

    ::continue::
  end

  return {
    shelly_args = shelly_args,
    shelly_substitutions = shelly_substitutions,
    dictionary = dictionary,
    command_args = command_args,
    urls = urls,
    processed_lines = processed_lines,
  }
end

--- Prepare code for execution by combining context, selection, and evaluation.
---
--- @return table Table with evaluated (see M.evaluate), code_lines (string[]), has_code (boolean)
function M.prepare_execution()
  local selection = M.parse_selection()
  local context = M.parse_context()

  -- Combine context and selection
  local all_lines = {}
  for _, line in ipairs(context) do
    table.insert(all_lines, line)
  end
  for _, line in ipairs(selection.lines) do
    table.insert(all_lines, line)
  end

  -- Evaluate to extract special syntax
  local evaluated = M.evaluate(all_lines)

  -- Preserve all lines including empty ones, but check if there's any actual code
  local code_lines = evaluated.processed_lines
  local has_code = false
  for _, line in ipairs(code_lines) do
    if not line:match('^%s*$') then
      has_code = true
      break
    end
  end

  return {
    evaluated = evaluated,
    code_lines = code_lines,
    has_code = has_code,
  }
end

--- Execute a shell command asynchronously.
---
--- Uses vim.system (Neovim 0.10+) or jobstart (older versions).
--- @param command string[] Command as list of arguments
--- @param callback fun(result: table) Callback with result table {stdout: string[], stderr: string[]}
function M.execute_shell(command, callback)
  local stdout_lines = {}
  local stderr_lines = {}

  -- Use vim.system for Neovim 0.10+
  if vim.system then
    vim.system(command, { text = true }, function(obj)
      if obj.stdout then
        for line in obj.stdout:gmatch('[^\r\n]+') do
          table.insert(stdout_lines, line)
        end
      end
      if obj.stderr then
        for line in obj.stderr:gmatch('[^\r\n]+') do
          table.insert(stderr_lines, line)
        end
      end
      vim.schedule(function()
        callback({ stdout = stdout_lines, stderr = stderr_lines })
      end)
    end)
  else
    -- Fallback to jobstart for older Neovim versions
    local job_id = vim.fn.jobstart(command, {
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= '' then
              table.insert(stdout_lines, line)
            end
          end
        end
      end,
      on_stderr = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= '' then
              table.insert(stderr_lines, line)
            end
          end
        end
      end,
      on_exit = function()
        vim.schedule(function()
          callback({ stdout = stdout_lines, stderr = stderr_lines })
        end)
      end,
    })

    if job_id == 0 then
      vim.schedule(function()
        callback({ stdout = {}, stderr = { 'Invalid command' } })
      end)
    elseif job_id == -1 then
      vim.schedule(function()
        callback({ stdout = {}, stderr = { 'Command not executable' } })
      end)
    end
  end
end

--- Append command-line arguments to a command table.
---
--- @param command string[] Command table to append to
--- @param args string[] Arguments to append
function M.append_args(command, args)
  if args and #args > 0 then
    for i = 1, #args do
      command[#command + 1] = args[i]
    end
  end
end

--- Build a command table from base command and arguments.
---
--- @param base_cmd string[] Base command table
--- @param args string[] Arguments to append
--- @return string[] Combined command table
function M.build_command(base_cmd, args)
  local cmd = {}
  for i = 1, #base_cmd do
    cmd[i] = base_cmd[i]
  end
  M.append_args(cmd, args)
  return cmd
end

return M
