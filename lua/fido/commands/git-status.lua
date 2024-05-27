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
    local file = vim.fn.trim((string.find(line, regex.tracked_file) and string.match(line, regex.tracked_file)) or line)

    if vim.fn.filereadable(file) > 0 then
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

  if #files > 0 then
    os.execute(command .. ' -- ' .. table.concat(
      vim.tbl_map(function(file)
        return '"' .. file .. '"'
      end, files),
      ' '
    ))
  end

  return format_stdout(vim.fn.systemlist(git_status))
end

return {
  create = function(params)
    vim.api.nvim_create_user_command(params.command, function()
      require('fido').fetch({
        name = name,
        size = 50,
        focus = 'child',
        execute = function()
          return git_status, nil
        end,
        process = function(lines, args)
          vim.keymap.set('n', '<Enter>', function()
            local files = parse_files()

            if #files > 0 then
              args.window.parent.focus()
              vim.cmd('edit ' .. files[1] .. '')
            end
          end, { buffer = true })

          local function render_and_jump(lines)
            local current_line = vim.fn.line('.')
            args.render(lines, { name = name })
            vim.cmd('silent normal ' .. current_line .. 'G')
          end

          if params.mappings.stage_files then
            vim.keymap.set({ 'n', 'v' }, params.mappings.stage_files, function()
              render_and_jump(execute_on_files('git add'))
            end, { buffer = true })
          end

          if params.mappings.unstage_files then
            vim.keymap.set({ 'n', 'v' }, params.mappings.unstage_files, function()
              render_and_jump(execute_on_files('git restore --staged'))
            end, { buffer = true })
          end

          if params.mappings.refresh then
            vim.keymap.set('n', params.mappings.refresh, function()
              render_and_jump(format_stdout(vim.fn.systemlist(git_status)))
            end, { buffer = true })
          end

          return format_stdout(lines)
        end,
      })
    end, { nargs = '*' })
  end,
}
