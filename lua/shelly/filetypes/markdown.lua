local utils = require('shelly.utils')

--- Executes a Markdown code block by delegating to the appropriate runner.
--- @type FiletypeRunner
local function execute(evaluated, callback)
  local selection = utils.parse_selection()
  local filetype = selection.filetype
  local filetype_map = {
    python = 'python',
    py = 'python',
    lua = 'lua',
    javascript = 'javascript',
    js = 'javascript',
    typescript = 'typescript',
    ts = 'typescript',
    sql = 'postgresql',
    postgresql = 'postgresql',
    psql = 'postgresql',
    redis = 'redis',
    bash = 'sh',
    sh = 'sh',
    shell = 'sh',
    http = 'http',
  }
  local runner_name = filetype_map[filetype] or filetype
  local success, runner = pcall(require, 'shelly.filetypes.' .. runner_name)
  if success and runner.execute then
    runner.execute(callback)
  else
    vim.schedule(function()
      callback({
        stdout = {},
        stderr = { 'No runner found for filetype: ' .. filetype },
      })
    end)
  end
end

return { execute = execute }
