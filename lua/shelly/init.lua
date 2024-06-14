local buffers = require('shelly.buffers')
local commands = require('shelly.commands')
local config = require('shelly.config')
local filetypes = require('shelly.filetypes')

--- @alias config { mappings?: { close?: string } }
--- @alias range { syntax: string, range: [number, number] }
--- @alias fence { syntax: string, range: [number, number], lines: string[] }
--- @alias scope { lines: string[], variables: { [string]: string } }

local syntax_evaluator = {
  http = filetypes.http.evaluate,
  javascript = filetypes.javascript.evaluate,
  sql = filetypes.sql.evaluate,
  redis = filetypes.redis.evaluate,
}

local function evaluate()
  local scope, fence = buffers.parse_buffer()

  if scope and fence then
    for syntax, evaluate_filetype in pairs(syntax_evaluator) do
      if fence.syntax == syntax then
        evaluate_filetype(scope, fence)
        break
      end
    end
  end
end

return {
  setup = config.setup,
  evaluate = evaluate,
  commands = commands,
}
