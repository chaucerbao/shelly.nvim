local filetypes = {
  http = require('fido.filetypes.http'),
  javascript = require('fido.filetypes.javascript'),
  redis = require('fido.filetypes.redis'),
  sql = require('fido.filetypes.sql'),
}

return vim.tbl_extend('force', filetypes, {
  setup = function()
    for _, filetype in pairs(filetypes) do
      if filetype.setup then
        filetype.setup()
      end
    end
  end,
})
