local uri_pattern = '(%a+://.*%S)'
local arg_pattern = '(%-?%-%w.*%S*)'

--- @param pattern string
local function create_line_pattern(pattern)
  return '^%s*' .. pattern .. '%s*$'
end

--- @param separator string
local function create_key_value_line_pattern(separator)
  return '^%s*(%S+)%s*' .. separator .. '%s*(.*%S)%s*$'
end

--- @param lines string[]
--- @return string[]
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

local function exit_visual_mode()
  if vim.fn.mode():match('^[Vv]') then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)
  end
end

--- @param commands [string[], table<string, unknown>?][]
--- @param callback? fun(jobs: unknown[]): nil
--- @param state? { index: number, jobs: unknown[] }
local function run_shell_commands(commands, callback, state)
  state = state or {}
  state.index = state.index or 1
  state.jobs = state.jobs or {}

  if state.index > #commands then
    if callback then
      callback(state.jobs)
    end

    return
  end

  local cmd = commands[state.index][1]
  local system_options = commands[state.index][2] or {}

  vim.system(cmd, vim.tbl_extend('force', { text = true, timeout = 10 * 1000 }, system_options), function(job)
    table.insert(state.jobs, job)

    run_shell_commands(commands, callback, { index = state.index + 1, jobs = state.jobs })
  end)
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

  exit_visual_mode = exit_visual_mode,
  run_shell_commands = run_shell_commands,
}
