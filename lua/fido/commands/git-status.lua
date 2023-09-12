-- Import
local regex = require('fido.regex')

-- Constants
local name = 'GitStatus'
local git_status = 'git status'

-- Helpers
local function get_selected_lines()
  local start_line = vim.fn.line('.')
  local end_line = start_line

  if vim.api.nvim_get_mode().mode:match('^[vV]$') then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)

    start_line = vim.api.nvim_buf_get_mark(0, '<')[1]
    end_line = vim.api.nvim_buf_get_mark(0, '>')[1]
  end

  return start_line, end_line
end

local function parse_files()
  local start_line, end_line = get_selected_lines()
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  local files = {}
  for _, line in pairs(lines) do
    if string.find(line, regex.tracked_file) then
      local file = string.match(line, regex.tracked_file)
      table.insert(files, file)
    elseif string.find(line, regex.untracked_file) then
      local file = string.match(line, regex.untracked_file)
      table.insert(files, file)
    end
  end

  return files
end

local function format_stdout(lines)
  return vim.tbl_map(function(line)
    return string.gsub(line, '\t', '        ')
  end, lines)
end

local function execute_on_files(command)
  local files = parse_files()

  if #files then
    os.execute(command .. ' -- ' .. table.concat(
      vim.tbl_map(function(file)
        return '"' .. file .. '"'
      end, files),
      ' '
    ))

    return format_stdout(vim.fn.systemlist(git_status))
  end
end

return {
  create = function(params)
    vim.api.nvim_create_user_command(params.command, function()
      require('fido').fetch({
        name = name,
        size = 50,
        execute = function()
          return git_status, nil
        end,
        process = function(lines, args)
          args.window.child.focus()

          if params.stage_mapping and vim.fn.mapcheck(params.stage_mapping, 'n') == '' then
            vim.keymap.set({ 'n', 'v' }, params.stage_mapping, function()
              local current_line = vim.fn.line('.')
              args.render({ name = name }, execute_on_files('git add'))
              vim.cmd('silent normal ' .. current_line .. 'G')
            end, { buffer = true })
          end

          if params.unstage_mapping and vim.fn.mapcheck(params.unstage_mapping, 'n') == '' then
            vim.keymap.set({ 'n', 'v' }, params.unstage_mapping, function()
              local current_line = vim.fn.line('.')
              args.render({ name = name }, execute_on_files('git restore --staged'))
              vim.cmd('silent normal ' .. current_line .. 'G')
            end, { buffer = true })
          end

          if params.refresh_mapping and vim.fn.mapcheck(params.refresh_mapping, 'n') == '' then
            vim.keymap.set('n', params.refresh_mapping, function()
              local current_line = vim.fn.line('.')
              args.render({ name = name }, format_stdout(vim.fn.systemlist(git_status)))
              vim.cmd('silent normal ' .. current_line .. 'G')
            end, { buffer = true })
          end

          vim.defer_fn(function()
            args.window.child.focus()
          end, 0)

          return format_stdout(lines)
        end,
      })
    end, { nargs = '*' })
  end,
}
