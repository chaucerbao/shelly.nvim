local utils = require('shelly.utils')
local new_set, expect = MiniTest.new_set, MiniTest.expect
local T = new_set()

T['parse_shelly_arg()'] = function()
  local key, value

  key, value = utils.parse_shelly_arg(' @@ flag ')
  expect.equality(key, 'flag')
  expect.equality(value, true)

  key, value = utils.parse_shelly_arg(' @@ no:flag ')
  expect.equality(key, 'flag')
  expect.equality(value, nil)

  key, value = utils.parse_shelly_arg(' @@ flag = 5 ')
  expect.equality(key, 'flag')
  expect.equality(value, '5')
end

T['parse_url()'] = function()
  local url

  url = utils.parse_url(' scheme://one:two@three.four/five-six_seven ')
  expect.equality(url, 'scheme://one:two@three.four/five-six_seven')
end

T['parse_substitution()'] = function()
  local key, value

  key, value = utils.parse_substitution(' {:xxx:} = o.o u.u ')
  expect.equality(key, '{:xxx:}')
  expect.equality(value, 'o.o u.u ')
end

T['parse_dictionary()'] = function()
  local key, value

  key, value = utils.parse_dictionary(' A-B : a:/b c ')
  expect.equality(key, 'A-B')
  expect.equality(value, 'a:/b c ')
end

T['substitute_line()'] = function()
  local line

  line = utils.substitute_line(' $:X y z$:Xz ', { ['2'] = '3', ['$:X'] = '1', ['1'] = '2' })
  expect.equality(line, ' 2 y z2z ')
end

return T
