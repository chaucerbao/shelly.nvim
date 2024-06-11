local buffers = require('shelly.buffers')
local utils = require('shelly.utils')

--- @return { status: string, filename: string }[]
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
    local status, filename = line:match(file_status_pattern)

    if status and filename then
      table.insert(
        files,
        { status = status, filename = (filename:find('^"[^"]+"$') ~= nil) and filename:sub(2, -2) or filename }
      )
    end
  end

  return files
end

--- @param args? { bang?: boolean  }
--- @param callback? fun(scratch_winid: number): nil
local function git_status(args, callback)
  vim.system({ 'git', 'status', '--porcelain' }, { text = true, timeout = 5 * 1000 }, function(job)
    vim.schedule(function()
      local scratch_winid = buffers.render_scratch_buffer(
        vim.split((job.code == 0) and job.stdout or job.stderr, '\n'),
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
  local filenames = vim.tbl_map(function(file)
    return file.filename
  end, get_selected_files())

  vim.cmd.wincmd('p')
  vim.cmd.edit(filenames[1])
end

local function stage_selected_files()
  local filenames = vim.tbl_map(function(file)
    return file.filename
  end, get_selected_files())

  vim.system(vim.list_extend({ 'git', 'add', '--' }, filenames), { text = true, timeout = 5 * 1000 }, git_status)
end

local function unstage_selected_files()
  local filenames = vim.tbl_map(function(file)
    return file.filename
  end, get_selected_files())

  vim.system(
    vim.list_extend({ 'git', 'restore', '--staged', '--' }, filenames),
    { text = true, timeout = 5 * 1000 },
    git_status
  )
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
