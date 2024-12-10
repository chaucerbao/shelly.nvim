local http = require('shelly.filetypes.http')
local ecmascript = require('shelly.filetypes.ecmascript')
local redis = require('shelly.filetypes.redis')
local sql = require('shelly.filetypes.sql')

return {
  http = http,
  javascript = ecmascript.createEvaluate('node'),
  redis = redis,
  sql = sql,
  typescript = ecmascript.createEvaluate('deno'),
}
