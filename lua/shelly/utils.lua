local M = {}

-- Markdown code block patterns
local CODE_BLOCK_START_PATTERN = '^%s*```%s*([%w%-_]+)%s*$'
local CODE_BLOCK_END_PATTERN = '^%s*```%s*$'

--- Removes code comment prefixes and suffixes from a line.
---
--- @param line string Line to clean
--- @return string Cleaned line

--- Check if a line is a command line argument.
--- @param line string
--- @return boolean
local function is_command_line_argument(line)
  return line:match('^%-%w$') or line:match('^%-%-[%w%-]+$') or line:match('^%-%-[%w%-]+=[^%s]+$')
end

local function remove_from_comment(line)
  -- Trim leading/trailing whitespace
  line = line:match('^%s*(.-)%s*$') or line
  -- If line looks like a command argument, do not strip comment prefix
  if is_command_line_argument(line) then
    return line
  end
  -- Remove common comment prefixes
  line = line:gsub('^#%s*', '')
  line = line:gsub('^//%s*', '')
  line = line:gsub('^--%s*', '')
  line = line:gsub('^/%*%s*', '')
  line = line:gsub('^<!--%s*', '')
  -- Remove common comment suffixes
  line = line:gsub('%s*%*/$', '')
  line = line:gsub('%s*-->$', '')
  return line
end

--- Check if a line is within a markdown code block.
---
--- Searches for code block fences and language identifier.
--- @param lines string[] List of all buffer lines
--- @param line_num integer Current line number (1-indexed)
--- @return boolean is_in_block True if in code block
--- @return string|nil language Language identifier if present
--- @return integer|nil line_start Starting line of code block
--- @return integer|nil line_end Ending line of code block
local function get_markdown_code_block(lines, line_num)
  local line_start, language
  for i = line_num, 1, -1 do
    local match = lines[i]:match(CODE_BLOCK_START_PATTERN)
    if match then
      line_start, language = i, match
      break
    end
    if i ~= line_num and lines[i]:match(CODE_BLOCK_END_PATTERN) then
      return false
    end
  end
  if not line_start then
    return false
  end
  for i = line_start + 1, #lines do
    if lines[i]:match(CODE_BLOCK_START_PATTERN) then
      return false
    end
    if lines[i]:match(CODE_BLOCK_END_PATTERN) then
      return line_num >= line_start and line_num <= i and true, language, line_start, i or false
    end
  end
  return false
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
function M.get_selection()
  local mode = vim.fn.mode()
  local selected_lines = {}
  local filetype = vim.bo.filetype

  -- Priority 1: Visual selection
  if mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is <C-v>
    local selection = get_visual_selection()
    local line_start = selection.line_start
    local line_end = selection.line_end

    -- Check for markdown code block language identifier
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local in_block, language = get_markdown_code_block(lines, line_start)
    if in_block and language then
      filetype = language
    end

    return {
      lines = selection.lines,
      filetype = filetype,
      line_start = line_start,
      line_end = line_end,
    }
  end

  -- Priority 2: Markdown code block surrounding current line
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor_line = vim.fn.line('.')

  local in_block, language, line_start, line_end = get_markdown_code_block(lines, cursor_line)
  if in_block and line_start and line_end then
    for i = line_start + 1, line_end - 1 do
      table.insert(selected_lines, lines[i])
    end
    if language then
      filetype = language
    end
    return {
      lines = selected_lines,
      filetype = filetype,
      line_start = line_start + 1,
      line_end = line_end - 1,
    }
  end

  -- Priority 3: Entire buffer
  for _, line in ipairs(lines) do
    table.insert(selected_lines, line)
  end
  return {
    lines = selected_lines,
    filetype = filetype,
    line_start = 1,
    line_end = #lines,
  }
end

--- Parse context code blocks from buffer lines.
---
--- Extracts lines from markdown code blocks with language 'context' or 'ctx'.
--- Skips empty lines and removes comment prefixes.
--- @param opts table? Optional table with until_line (integer)
--- @return table { lines: string[] }
function M.get_context(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local until_line = opts.until_line or #lines
  local context_lines = {}
  local in_block = false

  for i = 1, math.min(#lines, until_line) do
    local line = lines[i]
    if not in_block then
      local language = line:match(CODE_BLOCK_START_PATTERN)
      if language and (language == 'context' or language == 'ctx') then
        in_block = true
      end
    else
      if line:match(CODE_BLOCK_END_PATTERN) then
        in_block = false
      else
        if line:match('%S') then
          table.insert(context_lines, line)
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
--- @return Evaluated
function M.evaluate(lines)
  local shelly_args = {}
  local shelly_substitutions = {}
  local dictionary = {}
  local command_args = {}
  local urls = {}
  local processed_lines = {}

  for _, line in ipairs(lines) do
    -- Skip empty lines
    if line:match('^%s*$') then
      goto continue
    end

    -- Check for @@shelly_args
    local arg_match = line:match('^%s*@@(%S+)')
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
    local var_key, var_value = line:match('^%s*(%S+)%s*=%s*(.+)%s*$')
    if var_key and var_value and not line:match('^%-%-') and not line:match('^%-[^-]') then
      shelly_substitutions[var_key] = var_value
      goto continue
    end

    -- Check for dictionary entries (key: value)
    local dict_key, dict_value = line:match('^%s*(%S+)%s*:%s*(.+)%s*$')
    if dict_key and dict_value then
      dictionary[dict_key] = dict_value
      goto continue
    end

    -- Check for command line arguments
    if is_command_line_argument(line) then
      table.insert(command_args, line:match('^%s*(.-)%s*$'))
      goto continue
    end

    -- Check for URLs
    if line:match('^https?://') or line:match('^ftp://') then
      table.insert(urls, line:match('^%s*(.-)%s*$'))
      goto continue
    end

    -- Apply substitutions
    local processed = line
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

--- Execute a shell command asynchronously.
---
--- Uses vim.system (Neovim 0.10+) or jobstart (older versions).
--- @param command string[] Command as list of arguments
--- @param callback fun(result: table) Callback with result table {stdout: string[], stderr: string[]}
function M.execute_shell(command, callback)
  local function split_into_lines(text)
    if not text or text == '' then
      return {}
    end
    local lines = vim.split(text, '\n')
    if lines[#lines] == '' then
      table.remove(lines, #lines)
    end
    return lines
  end

  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      callback({
        stdout = split_into_lines(result.stdout),
        stderr = split_into_lines(result.stderr),
      })
    end)
  end)
end

return M
