local M = {}

local CODE_BLOCK_START_PATTERN = '^%s*```%s*([%w%-_]+)%s*$'
local CODE_BLOCK_END_PATTERN = '^%s*```%s*$'

M.DEFAULT_EVALUATED =
  { shelly_args = {}, shelly_substitutions = {}, dictionary = {}, command_args = {}, urls = {}, lines = {} }

--- Checks if a line is a command line argument (e.g. -x, --flag, --flag=value).
--- @param line string Line to check
--- @return boolean True if line is a command line argument
local function is_command_line_argument(line)
  return line:match('^%-%w$') or line:match('^%-%-[%w%-]+$') or line:match('^%-%-[%w%-]+=[^%s]+$')
end

--- Removes common comment prefixes and suffixes from a line.
--- Does not strip if line is a command line argument.
--- @param line string Line to clean
--- @return string Cleaned line
local function uncomment(line)
  line = vim.trim(line)
  if is_command_line_argument(line) then
    return line
  end
  line = line
    :gsub('^#%s*', '')
    :gsub('^//%s*', '')
    :gsub('^%-%-%s*', '')
    :gsub('^/%*%s*', '')
    :gsub('^<%-%-%s*', '')
    :gsub('%s*%*/$', '')
    :gsub('%s*%-%->$', '')
  return line
end

--- Strip backspace formatting codes (e.g., for bold/underline) from a string.
-- Removes all "X^HX" and "_^HX" style overstrike sequences.
-- @param line string: Input string
-- @return string: Cleaned string
function M.strip_backspace_codes(line)
  -- Remove all "char<backspace>char" (bold) and "_<backspace>char" (underline) patterns
  -- Backspace is ASCII 8
  return line:gsub('.\8', '')
end

--- Determines if a line is inside a markdown code block, and returns block info.
--- @param lines string[] All buffer lines
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

--- Gets the current visual selection as lines, with start/end line numbers.
--- @return table { lines: string[], line_start: integer, line_end: integer }
local function get_visual_selection()
  local reg_content, reg_type = vim.fn.getreg('"'), vim.fn.getregtype('"')
  local start_pos, end_pos = vim.fn.getpos('v'), vim.fn.getpos('.')
  local line_start = math.min(start_pos[2], end_pos[2])
  local line_end = math.max(start_pos[2], end_pos[2])
  vim.cmd('normal! y')
  local selection_text = vim.fn.getreg('"')
  vim.fn.setreg('"', reg_content, reg_type)
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

--- Gets the current selection and determines lines and filetype.
--- Priority: visual selection > markdown code block > entire buffer.
--- @return { lines: string[], filetype: string, line_start: integer, line_end: integer, selection_type: 'visual'|'code-block'|'buffer' }
function M.get_selection()
  local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
  local filetype = vim.bo.filetype

  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local selection = get_visual_selection()
    local in_block, language = get_markdown_code_block(lines, selection.line_start)
    if in_block and language then
      filetype = language
    end

    return {
      lines = selection.lines,
      filetype = filetype,
      line_start = selection.line_start,
      line_end = selection.line_end,
      selection_type = 'visual',
    }
  end

  local cursor_line = vim.fn.line('.')
  local in_block, language, block_start, block_end = get_markdown_code_block(lines, cursor_line)
  if in_block and block_start and block_end then
    local block_lines = {}
    for i = block_start + 1, block_end - 1 do
      block_lines[#block_lines + 1] = lines[i]
    end
    if language then
      filetype = language
    end

    return {
      lines = block_lines,
      filetype = filetype,
      line_start = block_start + 1,
      line_end = block_end - 1,
      selection_type = 'code-block',
    }
  end

  -- Fallback: entire buffer
  return {
    lines = lines,
    filetype = filetype,
    line_start = 1,
    line_end = #lines,
    selection_type = 'buffer',
  }
end

--- Extracts context lines from markdown code blocks with language 'context' or 'ctx'.
--- Skips empty lines and removes comment prefixes.
--- @param opts table? Optional table with until_line (integer)
--- @return table { lines: string[] }
function M.get_context(opts)
  opts = opts or {}

  local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
  local until_line = opts.until_line or #lines
  local context_lines, in_block = {}, false

  for i = 1, math.min(#lines, until_line) do
    local line = uncomment(lines[i])

    if not in_block then
      local language = line:match(CODE_BLOCK_START_PATTERN)
      if language and (language == 'context' or language == 'ctx') then
        in_block = true
      end
    else
      if line:match(CODE_BLOCK_END_PATTERN) then
        in_block = false
      elseif line:match('%S') then
        table.insert(context_lines, line)
      end
    end
  end

  return { lines = context_lines }
end

--- Parses Shelly argument lines (e.g. @@key, @@key = value, @@no:key)
--- @param line string The line to parse
--- @return string|nil key The argument key, or nil if not matched
--- @return string|boolean|nil value The argument value, true for flags, nil for negations or no match
function M.parse_shelly_arg(line)
  local arg = line:match('^%s*@@%s*(.+)')
  if not arg then
    return nil
  end

  -- @@key = value
  local key, value = arg:match('^(%w+)%s*=%s*(.+)$')
  if key then
    return vim.trim(key), vim.trim(value)
  end

  -- @@no:key
  local no_key = arg:match('^no:(%w+)%s*$')
  if no_key then
    return vim.trim(no_key), nil
  end

  -- @@key
  local simple_key = arg:match('^(%w+)%s*$')
  if simple_key then
    return vim.trim(simple_key), true
  end

  return nil
end

--- Parses URL lines
--- @param line string
--- @return string|nil url
function M.parse_url(line)
  local url = line:match('^%s*[%w%+%-%.]+://%S+')
  return url and vim.trim(line) or nil
end

--- Parses substitution lines (e.g. key = value)
--- @param line string
--- @return string|nil key, string|nil value
function M.parse_substitution(line)
  if is_command_line_argument(line) then
    return nil
  end
  local key, value = line:match('^%s*(%S+)%s*=%s*(.+)%s*$')
  return key, value
end

--- Parses dictionary lines (e.g. key: value)
--- @param line string
--- @return string|nil key, string|nil value
function M.parse_dictionary(line)
  local key, value = line:match('^%s*([%w_-]+)%s*:%s*(.+)%s*$')
  return key, value
end

--- Utility function to substitute keys in a line using a substitutions table.
--- Each key in substitutions is replaced by its value in the line.
--- @param line string Line to process
--- @param substitutions table<string, string> Table of substitutions
--- @return string Substituted line
function M.substitute_line(line, substitutions)
  for sub_key, sub_value in pairs(substitutions) do
    line = line:gsub(sub_key, sub_value)
  end
  return line
end

--- Evaluates Shelly syntax in lines: parses arguments, substitutions, dictionaries, command args, URLs.
--- @param lines string[] Lines to evaluate
--- @param opts table? Optional table of options. Supported flags:
---   previous: Evaluated?
---   parse_text_lines: boolean?
--- @return Evaluated
function M.evaluate(lines, opts)
  opts = opts or {}

  local evaluated = opts.previous and (vim.deepcopy(opts.previous)) or M.DEFAULT_EVALUATED

  local line_count = #lines

  for i = 1, line_count do
    local line = vim.trim(lines[i])
    if line == '' then
      goto continue
    end
    local substituted_line = M.substitute_line(line, evaluated.shelly_substitutions)

    local arg_key, arg_val = M.parse_shelly_arg(substituted_line)
    if arg_key ~= nil then
      evaluated.shelly_args[arg_key] = arg_val
      goto continue
    end

    local url = M.parse_url(substituted_line)
    if url ~= nil then
      table.insert(evaluated.urls, url)
      goto continue
    end

    local sub_key, sub_val = M.parse_substitution(substituted_line)
    if sub_key ~= nil and sub_val ~= nil then
      evaluated.shelly_substitutions[sub_key] = sub_val
      goto continue
    end

    local dict_key, dict_val = M.parse_dictionary(substituted_line)
    if dict_key ~= nil and dict_val ~= nil then
      evaluated.dictionary[dict_key] = dict_val
      goto continue
    end

    if is_command_line_argument(substituted_line) then
      table.insert(evaluated.command_args, substituted_line)
      goto continue
    end

    if opts.parse_text_lines then
      for j = i, line_count do
        table.insert(evaluated.lines, M.substitute_line(lines[j], evaluated.shelly_substitutions))
      end
      break
    end

    ::continue::
  end

  return evaluated
end

--- Executes a shell command asynchronously using vim.system.
--- @param command string[] Command as list of arguments
--- @param opts table|nil Options table passed to vim.system (see :h vim.system)
--- @param callback fun(result: table) Callback with result table {stdout: string[], stderr: string[]}
function M.execute_shell(command, opts, callback)
  opts = opts or {}
  opts.text = true

  --- Splits text into lines, removing trailing empty line.
  --- @param text string
  --- @return string[]
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

  if opts.shelly_args ~= nil then
    if opts.shelly_args.cmd then
      print(vim.inspect(command))
    end

    opts.shelly_args = nil
  end

  vim.system(command, opts, function(result)
    vim.schedule(function()
      callback({
        stdout = split_into_lines(result.stdout),
        stderr = split_into_lines(result.stderr),
      })
    end)
  end)
end

return M
