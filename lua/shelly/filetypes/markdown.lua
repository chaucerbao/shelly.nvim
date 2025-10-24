local utils = require("shelly.utils")

local M = {}

--- Execute Markdown code block
---@param callback function(result: {stdout: string[], stderr: string[]}) Callback with results
function M.execute(callback)
  local selection = utils.parse_selection()

  -- For markdown, parse_selection should have detected the code block language
  local filetype = selection.filetype

  -- Map common language identifiers to runner names
  local filetype_map = {
    python = "python",
    py = "python",
    lua = "lua",
    javascript = "javascript",
    js = "javascript",
    typescript = "typescript",
    ts = "typescript",
    sql = "postgresql",
    postgresql = "postgresql",
    psql = "postgresql",
    redis = "redis",
    bash = "sh",
    sh = "sh",
    shell = "sh"
  }

  local runner_name = filetype_map[filetype] or filetype

  -- Try to load the appropriate runner
  local success, runner = pcall(require, "shelly.filetypes." .. runner_name)

  if success and runner.execute then
    -- Delegate to the specific filetype runner
    runner.execute(callback)
  else
    vim.schedule(function()
      callback({
        stdout = {},
        stderr = {"No runner found for filetype: " .. filetype}
      })
    end)
  end
end

return M
