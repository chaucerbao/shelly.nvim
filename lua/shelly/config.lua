--- @type config
local config = {}

--- @param user_config? config
local function setup(user_config)
  config = vim.tbl_deep_extend('force', config, user_config or {})

  return config
end

--- @return config
local function get()
  return config
end

return {
  config = config,
  setup = setup,
  get = get,
}
