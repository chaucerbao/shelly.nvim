local http = require('shelly.filetypes.http')
local javascript = require('shelly.filetypes.javascript')
local redis = require('shelly.filetypes.redis')
local sql = require('shelly.filetypes.sql')

return {
  http = http,
  javascript = javascript,
  redis = redis,
  sql = sql,
}
