local uri_pattern = '(%a+://.*%S)'
local arg_pattern = '(%-?%-%w.*%S)'

--- @param pattern string
local function create_line_pattern(pattern)
  return '^%s*' .. pattern .. '%s*$'
end

--- @param separator string
local function create_key_value_line_pattern(separator)
  return '^%s*(%S+)%s*' .. separator .. '%s*(.*%S)%s*$'
end

--- @param lines string[]
--- @return lines string[]
local function trim_lines(lines)
  return vim.tbl_filter(
    function(line)
      return #line > 0
    end,

    vim.tbl_map(function(line)
      return vim.trim(line)
    end, lines)
  )
end

--- @param line string
--- @param type 'single' | 'double' | 'both' | nil
local function escape_quotes(line, type)
  type = type or 'both'

  if type == 'single' or type == 'both' then
    line = vim.trim(line):gsub("'", "'\\''")
  end

  if type == 'double' or type == 'both' then
    line = vim.trim(line):gsub('"', '\\"')
  end

  return line
end

return {
  uri_pattern = uri_pattern,
  uri_line_pattern = create_line_pattern(uri_pattern),

  arg_pattern = arg_pattern,
  arg_line_pattern = create_line_pattern(arg_pattern),

  create_line_pattern = create_line_pattern,
  create_key_value_line_pattern = create_key_value_line_pattern,

  trim_lines = trim_lines,
  escape_quotes = escape_quotes,
}
