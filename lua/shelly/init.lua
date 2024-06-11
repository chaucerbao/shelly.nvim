local buffers = require('shelly.buffers')
local commands = require('shelly.commands')
local filetypes = require('shelly.filetypes')

--- @alias range { syntax: string, range: [number, number] }
--- @alias fence { syntax: string, range: [number, number], lines: string[] }
--- @alias scope { lines: string[], variables: { [string]: string } }

local function evaluate()
  local scope, fence = buffers.parse_buffer()

  local syntax_to_evaluate = {
    http = filetypes.http.evaluate,
    javascript = filetypes.javascript.evaluate,
    sql = filetypes.sql.evaluate,
    redis = filetypes.redis.evaluate,
  }

  if scope and fence then
    for syntax, evaluate_filetype in pairs(syntax_to_evaluate) do
      if fence.syntax == syntax then
        evaluate_filetype(scope, fence)
        break
      end
    end
  end
end

return {
  evaluate = evaluate,
  commands = commands,
}
