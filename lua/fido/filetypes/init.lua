local filetypes = {
  http = require('fido.filetypes.http'),
  node = require('fido.filetypes.node'),
  psql = require('fido.filetypes.psql'),
  redis = require('fido.filetypes.redis'),
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
