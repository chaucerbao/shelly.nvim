local M = {}

local CODE_BLOCK_START_PATTERN = '^%s*```%s*([%w%-_]+)%s*$'
local CODE_BLOCK_END_PATTERN = '^%s*```%s*$'

--- Removes code comment prefixes and suffixes from a line.
---
--- @param line string Line to clean
--- @return string Cleaned line

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
local function remove_from_comment(line)
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
--- @return table { lines: string[], filetype: string, line_start: integer, line_end: integer, selection_type: 'visual'|'code-block'|'buffer' }
function M.get_selection()
  local mode = vim.fn.mode()
  local selected_lines = {}
  local filetype = vim.bo.filetype
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local selection = get_visual_selection()
    local line_start, line_end = selection.line_start, selection.line_end
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
      selection_type = 'visual',
    }
  end
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
      selection_type = 'code-block',
    }
  end
  for _, line in ipairs(lines) do
    table.insert(selected_lines, line)
  end
  return {
    lines = selected_lines,
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
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local until_line = opts.until_line or #lines
  local context_lines, in_block = {}, false
  for i = 1, math.min(#lines, until_line) do
    local line = remove_from_comment(lines[i])
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

--- Evaluates Shelly syntax in lines: parses arguments, substitutions, dictionaries, command args, URLs.
--- @param lines string[] Lines to evaluate
--- @return table {
---   shelly_args: table<string, string|boolean>,
---   shelly_substitutions: table<string, string>,
---   dictionary: table<string, string>,
---   command_args: string[],
---   urls: string[],
---   processed_lines: string[]
--- }
function M.evaluate(lines)
  local shelly_args = {}
  local shelly_substitutions = {}
  local dictionary = {}
  local command_args = {}
  local urls = {}
  local processed_lines = {}
  local found_first_processed = false
  local line_count = #lines
  local idx = 1
  while idx <= line_count do
    local current_line = lines[idx]
    if not found_first_processed then
      if current_line:match('^%s*$') then
        idx = idx + 1
      elseif current_line:match('^%s*@@(%S+)') then
        local arg_match = current_line:match('^%s*@@(%S+)')
        local key, value = arg_match:match('^([^=]+)=(.+)$')
        if key and value then
          shelly_args[key] = vim.trim(value)
        elseif arg_match:match('^no') then
          shelly_args[arg_match] = false
        else
          shelly_args[arg_match] = true
        end
        idx = idx + 1
      elseif current_line:match('^%s*[%w%+%-%.]+://') then
        table.insert(urls, vim.trim(current_line))
        idx = idx + 1
      elseif
        current_line:match('^%s*(%S+)%s*=%s*(.+)%s*$')
        and not current_line:match('^%-%-')
        and not current_line:match('^%-[^-]')
      then
        local var_key, var_value = current_line:match('^%s*(%S+)%s*=%s*(.+)%s*$')
        shelly_substitutions[var_key] = var_value
        idx = idx + 1
      elseif current_line:match('^%s*(%S+)%s*:%s*(.+)%s*$') then
        local dict_key, dict_value = current_line:match('^%s*(%S+)%s*:%s*(.+)%s*$')
        dictionary[dict_key] = dict_value
        idx = idx + 1
      elseif is_command_line_argument(current_line) then
        table.insert(command_args, vim.trim(current_line))
        idx = idx + 1
      else
        local substituted_line = current_line
        for sub_key, sub_value in pairs(shelly_substitutions) do
          substituted_line = substituted_line:gsub(sub_key, sub_value)
        end
        table.insert(processed_lines, substituted_line)
        found_first_processed = true
        -- Append remaining lines as processed lines with substitutions
        for append_idx = idx + 1, line_count do
          local append_line = lines[append_idx]
          local substituted_append = append_line
          for sub_key, sub_value in pairs(shelly_substitutions) do
            substituted_append = substituted_append:gsub(sub_key, sub_value)
          end
          table.insert(processed_lines, substituted_append)
        end
        break
      end
    else
      break
    end
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
