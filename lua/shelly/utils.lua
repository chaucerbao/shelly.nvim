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

--- Get the current visual selection as lines, with start and end line numbers.
--- @return table { lines: string[], line_start: integer, line_end: integer }
local function get_visual_selection()
  local register_backup = {
    content = vim.fn.getreg('"'),
    type = vim.fn.getregtype('"'),
  }

  local start_pos = vim.fn.getpos('v')
  local end_pos = vim.fn.getpos('.')
  local line_start = math.min(start_pos[2], end_pos[2])
  local line_end = math.max(start_pos[2], end_pos[2])

  vim.cmd('normal! y')
  local selection_text = vim.fn.getreg('"')

  vim.fn.setreg('"', register_backup.content, register_backup.type)
  vim.cmd('normal! gv')

  local lines = vim.split(selection_text, '\n')
  if #lines == 0 or (lines[1] == '' and #lines == 1) then
    vim.notify('No visual selection found', vim.log.levels.WARN)
  end
  return {
    lines = lines,
    line_start = line_start,
    line_end = line_end,
  }
end

--- Parse the current selection and determine lines and filetype.
---
--- Priority: visual selection > markdown code block > entire buffer.
--- @return table Table with 'lines' (string[]) and 'filetype' (string)
function M.parse_selection()
  local mode = vim.fn.mode()
  local selected_lines = {}
  local filetype = vim.bo.filetype

  -- Priority 1: Visual selection
  if mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is <C-v>
    local selection = get_visual_selection()
    local start_line = selection.line_start
    local end_line = selection.line_end

    -- Check for markdown code block language identifier
    local bufnr = vim.api.nvim_get_current_buf()
    local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local in_block, lang = get_markdown_code_block(all_lines, start_line)
    if in_block and lang then
      filetype = lang
    end

    return {
      lines = selection.lines,
      filetype = filetype,
      line_start = start_line,
      line_end = end_line,
    }
  end

  -- Priority 2: Markdown code block surrounding current line
  local bufnr = vim.api.nvim_get_current_buf()
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor_line = vim.fn.line('.')

  local in_block, lang, block_start_line, block_end_line = get_markdown_code_block(all_lines, cursor_line)
  if in_block and block_start_line and block_end_line then
    for i = block_start_line + 1, block_end_line - 1 do
      table.insert(selected_lines, remove_comment_prefix(all_lines[i]))
    end
    if lang then
      filetype = lang
    end
    return {
      lines = selected_lines,
      filetype = filetype,
      line_start = block_start_line + 1,
      line_end = block_end_line - 1,
    }
  end

  -- Priority 3: Entire buffer
  for _, line in ipairs(all_lines) do
    table.insert(selected_lines, remove_comment_prefix(line))
  end
  return {
    lines = selected_lines,
    filetype = filetype,
    line_start = 1,
    line_end = #all_lines,
  }
end


--- Parse context code blocks from buffer lines.
---
--- Extracts lines from markdown code blocks with language 'context' or 'ctx'.
--- Skips empty lines and removes comment prefixes.
--- @param opts table? Optional table with until_line (integer)
--- @return table { lines: string[] }
function M.parse_context(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local until_line = opts.until_line or #all_lines
  local context_lines = {}
  local in_block = false

  for i = 1, math.min(#all_lines, until_line) do
    local line = all_lines[i]
    if not in_block then
      local lang = line:match('^```(%S+)')
      if lang and (lang == 'context' or lang == 'ctx') then
        in_block = true
      end
    else
      if line:match('^```%s*$') then
        in_block = false
      else
        local content = remove_comment_prefix(line)
        if content:match('%S') then
          table.insert(context_lines, content)
        end
      end
    end
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
