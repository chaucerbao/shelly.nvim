local buffers = require('shelly.buffers')
local utils = require('shelly.utils')

--- @return { status: [string, string], filenames: string[] }[]
local function get_selected_files()
  local file_status_pattern = '^(..)%s+(.*%S)%s*$'

  local current_line = vim.fn.line('.')
  local current_region = vim.fn.mode():match('^[Vv]') and { vim.fn.line('v'), current_line }

  if current_region then
    table.sort(current_region)
  end

  local range_start, range_end =
    (current_region and current_region[1] or current_line), (current_region and current_region[2] or current_line)

  local buffer_lines = vim.api.nvim_buf_get_lines(0, range_start - 1, range_end, false)

  local files = {}
  for _, line in ipairs(buffer_lines) do
    local status, description = line:match(file_status_pattern)
    local filenames = vim.split(description, ' -> ', { plain = true })

    if status and #filenames > 0 then
      table.insert(files, {
        status = { status:sub(1, 1), status:sub(2, 2) },
        filenames = vim.tbl_map(function(filename)
          return (filename:find('^"[^"]+"$') ~= nil) and filename:sub(2, -2) or filename
        end, filenames),
      })
    end
  end

  return files
end

--- @param args? { bang?: boolean  }
--- @param callback? fun(scratch_winid: number): nil
local function git_status(args, callback)
  utils.run_shell_commands({ { { 'git', 'status', '--porcelain' } } }, function(jobs)
    local job = jobs[1]

    vim.schedule(function()
      local scratch_winid = buffers.render_scratch_buffer(
        vim.split(job.stderr .. job.stdout, '\n'),
        { name = 'Git', filetype = 'text', size = 40, vertical = args and args.bang or false }
      )

      utils.exit_visual_mode()

      if callback then
        callback(scratch_winid)
      end
    end)
  end)
end

local function edit_selected_files()
  local files = get_selected_files()
  if #files == 0 then
    vim.notify('No selection')
  end

  vim.cmd.wincmd('p')
  vim.cmd.edit(files[1].filenames[#files[1].filenames])
end

local function stage_selected_files()
  local files = get_selected_files()

  local filenames = {}
  for _, file in ipairs(files) do
    table.insert(filenames, file.filenames[#file.filenames])
  end

  utils.run_shell_commands({ { vim.list_extend({ 'git', 'add', '--' }, filenames) } }, git_status)
end

local function unstage_selected_files()
  local files = get_selected_files()

  local renamed_filenames = {}
  local filenames = {}
  for _, file in ipairs(files) do
    if file.status[1] == 'R' then
      table.insert(renamed_filenames, file.filenames)
    else
      table.insert(filenames, file.filenames[1])
    end
  end

  local commands = {}
  if #renamed_filenames > 0 then
    for _, filenames in ipairs(renamed_filenames) do
      table.insert(commands, { vim.list_extend({ 'git', 'mv', '--' }, { filenames[2], filenames[1] }) })
    end
  end
  if #filenames > 0 then
    table.insert(commands, { vim.list_extend({ 'git', 'restore', '--staged', '--' }, filenames) })
  end

  utils.run_shell_commands(commands, git_status)
end

local function restore_selected_files()
  local files = get_selected_files()

  local renamed_filenames = {}
  local filenames = {}
  for _, file in ipairs(files) do
    if file.status[1] == 'R' then
      table.insert(renamed_filenames, file.filenames)
    end

    table.insert(filenames, file.filenames[1])
  end

  local commands = {}
  if #renamed_filenames > 0 then
    for _, filenames in ipairs(renamed_filenames) do
      table.insert(commands, { vim.list_extend({ 'git', 'mv', '--' }, { filenames[2], filenames[1] }) })
    end
  end
  if #filenames > 0 then
    table.insert(commands, { vim.list_extend({ 'git', 'restore', '--' }, filenames) })
  end

  utils.run_shell_commands(commands, git_status)
end

--- @param command string
local function create(command, options)
  options = options or {}

  vim.api.nvim_create_user_command(command, function(args)
    git_status(args, function(scratch_winid)
      local scratch_bufnr = vim.fn.winbufnr(scratch_winid)

      if options.mappings then
        if options.mappings.edit then
          vim.keymap.set({ 'n', 'v' }, options.mappings.edit, edit_selected_files, { buffer = scratch_bufnr })
        end

        if options.mappings.stage then
          vim.keymap.set({ 'n', 'v' }, options.mappings.stage, stage_selected_files, { buffer = scratch_bufnr })
        end

        if options.mappings.unstage then
          vim.keymap.set({ 'n', 'v' }, options.mappings.unstage, unstage_selected_files, { buffer = scratch_bufnr })
        end

        if options.mappings.restore then
          vim.keymap.set({ 'n', 'v' }, options.mappings.restore, restore_selected_files, { buffer = scratch_bufnr })
        end

        if options.mappings.refresh then
          vim.keymap.set({ 'n' }, options.mappings.refresh, git_status, { buffer = scratch_bufnr })
        end
      end
    end)
  end, { bang = true })
end

return {
  create = create,
}
