local shell = require('shelly.commands.shell')
local git_status = require('shelly.commands.git-status')

return {
  shell = shell,
  git_status = git_status,
}
