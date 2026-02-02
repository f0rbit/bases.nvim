local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local functions = require('bases.engine.expr.functions')
local types = require('bases.engine.expr.types')

local T = new_set()

-- =======================
-- M.call (dispatcher)
-- =======================

T['call'] = new_set()

T['call']['dispatches to fn_date'] = function()
  local args = { types.string('2021-01-01') }
  local result = functions.call('date', args, nil)
  expect.equality(result.type, 'date')
end

T['call']['dispatches to fn_today'] = function()
  local args = {}
  local result = functions.call('today', args, nil)
  expect.equality(result.type, 'date')
end

T['call']['dispatches to fn_now'] = function()
  local args = {}
  local result = functions.call('now', args, nil)
  expect.equality(result.type, 'date')
end

T['call']['dispatches to fn_if'] = function()
  local args = { types.boolean(true), types.string('yes'), types.string('no') }
  local result = functions.call('if', args, nil)
  expect.equality(result.value, 'yes')
end

T['call']['dispatches to fn_image'] = function()
  local args = { types.string('image.png') }
  local result = functions.call('image', args, nil)
  expect.equality(result.type, 'image')
end

T['call']['dispatches to fn_max'] = function()
  local args = { types.number(1), types.number(5), types.number(3) }
  local result = functions.call('max', args, nil)
  expect.equality(result.value, 5)
end

T['call']['dispatches to fn_min'] = function()
  local args = { types.number(1), types.number(5), types.number(3) }
  local result = functions.call('min', args, nil)
  expect.equality(result.value, 1)
end

T['call']['dispatches to fn_link'] = function()
  local args = { types.string('note') }
  local result = functions.call('link', args, nil)
  expect.equality(result.type, 'link')
end

T['call']['dispatches to fn_list'] = function()
  local args = {}
  local result = functions.call('list', args, nil)
  expect.equality(result.type, 'list')
end

T['call']['dispatches to fn_number'] = function()
  local args = { types.string('42') }
  local result = functions.call('number', args, nil)
  expect.equality(result.type, 'number')
end

T['call']['dispatches to fn_duration'] = function()
  local args = { types.string('5d') }
  local result = functions.call('duration', args, nil)
  expect.equality(result.type, 'duration')
end

T['call']['unknown function returns null'] = function()
  local args = {}
  local result = functions.call('unknown_function', args, nil)
  expect.equality(result.type, 'null')
end

-- =======================
-- fn_date
-- =======================

T['fn_date'] = new_set()

T['fn_date']['parses valid ISO date'] = function()
  local args = { types.string('2021-01-01') }
  local result = functions.fn_date(args)
  expect.equality(result.type, 'date')
  expect.no_equality(result.value, nil)
end

T['fn_date']['parses valid ISO datetime'] = function()
  local args = { types.string('2021-01-01T12:30:45') }
  local result = functions.fn_date(args)
  expect.equality(result.type, 'date')
  expect.no_equality(result.value, nil)
end

T['fn_date']['invalid date string returns null'] = function()
  local args = { types.string('not-a-date') }
  local result = functions.fn_date(args)
  expect.equality(result.type, 'null')
end

T['fn_date']['no args returns null'] = function()
  local args = {}
  local result = functions.fn_date(args)
  expect.equality(result.type, 'null')
end

T['fn_date']['converts number to string'] = function()
  local args = { types.number(2021) }
  local result = functions.fn_date(args)
  expect.equality(result.type, 'null')
end

T['fn_date']['empty string returns null'] = function()
  local args = { types.string('') }
  local result = functions.fn_date(args)
  expect.equality(result.type, 'null')
end

-- =======================
-- fn_today
-- =======================

T['fn_today'] = new_set()

T['fn_today']['returns date type'] = function()
  local args = {}
  local result = functions.fn_today(args)
  expect.equality(result.type, 'date')
end

T['fn_today']['returns number value'] = function()
  local args = {}
  local result = functions.fn_today(args)
  expect.equality(type(result.value), 'number')
end

T['fn_today']['value is reasonable milliseconds'] = function()
  local args = {}
  local result = functions.fn_today(args)
  -- Value should be positive and large (timestamp in ms)
  expect.equality(result.value > 1000000000000, true)
end

T['fn_today']['ignores args'] = function()
  local args = { types.string('ignored') }
  local result = functions.fn_today(args)
  expect.equality(result.type, 'date')
end

-- =======================
-- fn_now
-- =======================

T['fn_now'] = new_set()

T['fn_now']['returns date type'] = function()
  local args = {}
  local result = functions.fn_now(args)
  expect.equality(result.type, 'date')
end

T['fn_now']['returns number value'] = function()
  local args = {}
  local result = functions.fn_now(args)
  expect.equality(type(result.value), 'number')
end

T['fn_now']['value is reasonable milliseconds'] = function()
  local args = {}
  local result = functions.fn_now(args)
  -- Value should be positive and large (timestamp in ms)
  expect.equality(result.value > 1000000000000, true)
end

T['fn_now']['is later than today'] = function()
  local args = {}
  local now_result = functions.fn_now(args)
  local today_result = functions.fn_today(args)
  -- Now should be >= today (midnight)
  expect.equality(now_result.value >= today_result.value, true)
end

T['fn_now']['ignores args'] = function()
  local args = { types.string('ignored') }
  local result = functions.fn_now(args)
  expect.equality(result.type, 'date')
end

-- =======================
-- fn_if
-- =======================

T['fn_if'] = new_set()

T['fn_if']['truthy condition returns true_val'] = function()
  local args = { types.boolean(true), types.string('yes'), types.string('no') }
  local result = functions.fn_if(args)
  expect.equality(result.value, 'yes')
end

T['fn_if']['falsy condition returns false_val'] = function()
  local args = { types.boolean(false), types.string('yes'), types.string('no') }
  local result = functions.fn_if(args)
  expect.equality(result.value, 'no')
end

T['fn_if']['truthy string returns true_val'] = function()
  local args = { types.string('hello'), types.number(1), types.number(2) }
  local result = functions.fn_if(args)
  expect.equality(result.value, 1)
end

T['fn_if']['empty string returns false_val'] = function()
  local args = { types.string(''), types.number(1), types.number(2) }
  local result = functions.fn_if(args)
  expect.equality(result.value, 2)
end

T['fn_if']['non-zero number returns true_val'] = function()
  local args = { types.number(5), types.string('yes'), types.string('no') }
  local result = functions.fn_if(args)
  expect.equality(result.value, 'yes')
end

T['fn_if']['zero number returns false_val'] = function()
  local args = { types.number(0), types.string('yes'), types.string('no') }
  local result = functions.fn_if(args)
  expect.equality(result.value, 'no')
end

T['fn_if']['null condition returns false_val'] = function()
  local args = { types.null(), types.string('yes'), types.string('no') }
  local result = functions.fn_if(args)
  expect.equality(result.value, 'no')
end

T['fn_if']['missing false_val returns null'] = function()
  local args = { types.boolean(false), types.string('yes') }
  local result = functions.fn_if(args)
  expect.equality(result.type, 'null')
end

T['fn_if']['missing false_val with truthy condition returns true_val'] = function()
  local args = { types.boolean(true), types.string('yes') }
  local result = functions.fn_if(args)
  expect.equality(result.value, 'yes')
end

T['fn_if']['less than 2 args returns null'] = function()
  local args = { types.boolean(true) }
  local result = functions.fn_if(args)
  expect.equality(result.type, 'null')
end

T['fn_if']['no args returns null'] = function()
  local args = {}
  local result = functions.fn_if(args)
  expect.equality(result.type, 'null')
end

-- =======================
-- fn_image
-- =======================

T['fn_image'] = new_set()

T['fn_image']['creates image typed value'] = function()
  local args = { types.string('image.png') }
  local result = functions.fn_image(args)
  expect.equality(result.type, 'image')
  expect.equality(result.value, 'image.png')
end

T['fn_image']['handles path with directory'] = function()
  local args = { types.string('images/photo.jpg') }
  local result = functions.fn_image(args)
  expect.equality(result.type, 'image')
  expect.equality(result.value, 'images/photo.jpg')
end

T['fn_image']['converts number to string'] = function()
  local args = { types.number(123) }
  local result = functions.fn_image(args)
  expect.equality(result.type, 'image')
  expect.equality(result.value, '123')
end

T['fn_image']['no args returns null'] = function()
  local args = {}
  local result = functions.fn_image(args)
  expect.equality(result.type, 'null')
end

T['fn_image']['empty string creates empty image'] = function()
  local args = { types.string('') }
  local result = functions.fn_image(args)
  expect.equality(result.type, 'image')
  expect.equality(result.value, '')
end

-- =======================
-- fn_max
-- =======================

T['fn_max'] = new_set()

T['fn_max']['returns max of numbers'] = function()
  local args = { types.number(1), types.number(5), types.number(3) }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['fn_max']['single number returns that number'] = function()
  local args = { types.number(42) }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 42)
end

T['fn_max']['handles negative numbers'] = function()
  local args = { types.number(-1), types.number(-5), types.number(-3) }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, -1)
end

T['fn_max']['handles decimals'] = function()
  local args = { types.number(1.5), types.number(2.7), types.number(1.9) }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 2.7)
end

T['fn_max']['skips non-numeric values'] = function()
  local args = { types.number(1), types.string('hello'), types.number(5) }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['fn_max']['converts numeric strings'] = function()
  local args = { types.number(1), types.string('10'), types.number(5) }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 10)
end

T['fn_max']['handles booleans'] = function()
  local args = { types.boolean(true), types.number(5) }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['fn_max']['all non-numeric returns null'] = function()
  local args = { types.string('a'), types.string('b') }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'null')
end

T['fn_max']['no args returns null'] = function()
  local args = {}
  local result = functions.fn_max(args)
  expect.equality(result.type, 'null')
end

T['fn_max']['handles zero'] = function()
  local args = { types.number(0), types.number(-1), types.number(-5) }
  local result = functions.fn_max(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

-- =======================
-- fn_min
-- =======================

T['fn_min'] = new_set()

T['fn_min']['returns min of numbers'] = function()
  local args = { types.number(1), types.number(5), types.number(3) }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 1)
end

T['fn_min']['single number returns that number'] = function()
  local args = { types.number(42) }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 42)
end

T['fn_min']['handles negative numbers'] = function()
  local args = { types.number(-1), types.number(-5), types.number(-3) }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, -5)
end

T['fn_min']['handles decimals'] = function()
  local args = { types.number(1.5), types.number(2.7), types.number(1.9) }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 1.5)
end

T['fn_min']['skips non-numeric values'] = function()
  local args = { types.number(10), types.string('hello'), types.number(5) }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['fn_min']['converts numeric strings'] = function()
  local args = { types.number(10), types.string('1'), types.number(5) }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 1)
end

T['fn_min']['handles booleans'] = function()
  local args = { types.boolean(false), types.number(5) }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

T['fn_min']['all non-numeric returns null'] = function()
  local args = { types.string('a'), types.string('b') }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'null')
end

T['fn_min']['no args returns null'] = function()
  local args = {}
  local result = functions.fn_min(args)
  expect.equality(result.type, 'null')
end

T['fn_min']['handles zero'] = function()
  local args = { types.number(0), types.number(1), types.number(5) }
  local result = functions.fn_min(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

-- =======================
-- fn_link
-- =======================

T['fn_link'] = new_set()

T['fn_link']['creates link with path only'] = function()
  local args = { types.string('note') }
  local result = functions.fn_link(args)
  expect.equality(result.type, 'link')
  expect.equality(result.path, 'note')
  expect.equality(result.value, 'note')
end

T['fn_link']['creates link with path and display'] = function()
  local args = { types.string('path/to/note'), types.string('My Note') }
  local result = functions.fn_link(args)
  expect.equality(result.type, 'link')
  expect.equality(result.path, 'path/to/note')
  expect.equality(result.value, 'My Note')
end

T['fn_link']['converts number path to string'] = function()
  local args = { types.number(123) }
  local result = functions.fn_link(args)
  expect.equality(result.type, 'link')
  expect.equality(result.path, '123')
end

T['fn_link']['converts number display to string'] = function()
  local args = { types.string('note'), types.number(456) }
  local result = functions.fn_link(args)
  expect.equality(result.type, 'link')
  expect.equality(result.value, '456')
end

T['fn_link']['no args returns null'] = function()
  local args = {}
  local result = functions.fn_link(args)
  expect.equality(result.type, 'null')
end

T['fn_link']['empty path creates empty link'] = function()
  local args = { types.string('') }
  local result = functions.fn_link(args)
  expect.equality(result.type, 'link')
  expect.equality(result.path, '')
  expect.equality(result.value, '')
end

T['fn_link']['empty display text'] = function()
  local args = { types.string('note'), types.string('') }
  local result = functions.fn_link(args)
  expect.equality(result.type, 'link')
  expect.equality(result.path, 'note')
  expect.equality(result.value, '')
end

-- =======================
-- fn_list
-- =======================

T['fn_list'] = new_set()

T['fn_list']['no args returns empty list'] = function()
  local args = {}
  local result = functions.fn_list(args)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 0)
end

T['fn_list']['list arg returns as-is'] = function()
  local list_arg = types.list({ types.number(1), types.number(2) })
  local args = { list_arg }
  local result = functions.fn_list(args)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].value, 1)
  expect.equality(result.value[2].value, 2)
end

T['fn_list']['wraps non-list arg'] = function()
  local args = { types.string('hello') }
  local result = functions.fn_list(args)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 1)
  expect.equality(result.value[1].type, 'string')
  expect.equality(result.value[1].value, 'hello')
end

T['fn_list']['wraps number'] = function()
  local args = { types.number(42) }
  local result = functions.fn_list(args)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 1)
  expect.equality(result.value[1].value, 42)
end

T['fn_list']['wraps boolean'] = function()
  local args = { types.boolean(true) }
  local result = functions.fn_list(args)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 1)
  expect.equality(result.value[1].value, true)
end

T['fn_list']['wraps null'] = function()
  local args = { types.null() }
  local result = functions.fn_list(args)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 1)
  expect.equality(result.value[1].type, 'null')
end

T['fn_list']['wraps link'] = function()
  local args = { types.link('note') }
  local result = functions.fn_list(args)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 1)
  expect.equality(result.value[1].type, 'link')
end

T['fn_list']['only wraps first arg'] = function()
  local args = { types.number(1), types.number(2) }
  local result = functions.fn_list(args)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 1)
  expect.equality(result.value[1].value, 1)
end

-- =======================
-- fn_number
-- =======================

T['fn_number'] = new_set()

T['fn_number']['converts string to number'] = function()
  local args = { types.string('42') }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 42)
end

T['fn_number']['converts string with decimal'] = function()
  local args = { types.string('3.14') }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 3.14)
end

T['fn_number']['number arg returns number'] = function()
  local args = { types.number(100) }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 100)
end

T['fn_number']['boolean true converts to 1'] = function()
  local args = { types.boolean(true) }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 1)
end

T['fn_number']['boolean false converts to 0'] = function()
  local args = { types.boolean(false) }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

T['fn_number']['date converts to number'] = function()
  local args = { types.date(1609459200000) }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 1609459200000)
end

T['fn_number']['duration converts to number'] = function()
  local args = { types.duration(86400000) }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 86400000)
end

T['fn_number']['invalid string returns null'] = function()
  local args = { types.string('abc') }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'null')
end

T['fn_number']['null returns null'] = function()
  local args = { types.null() }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'null')
end

T['fn_number']['list returns null'] = function()
  local args = { types.list({ types.number(1) }) }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'null')
end

T['fn_number']['link returns null'] = function()
  local args = { types.link('note') }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'null')
end

T['fn_number']['no args returns null'] = function()
  local args = {}
  local result = functions.fn_number(args)
  expect.equality(result.type, 'null')
end

T['fn_number']['negative number string'] = function()
  local args = { types.string('-42') }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, -42)
end

T['fn_number']['zero string'] = function()
  local args = { types.string('0') }
  local result = functions.fn_number(args)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

-- =======================
-- fn_duration
-- =======================

T['fn_duration'] = new_set()

T['fn_duration']['parses valid duration'] = function()
  local args = { types.string('5d') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 432000000)
end

T['fn_duration']['parses seconds'] = function()
  local args = { types.string('10s') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 10000)
end

T['fn_duration']['parses minutes'] = function()
  local args = { types.string('5m') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 300000)
end

T['fn_duration']['parses hours'] = function()
  local args = { types.string('2h') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 7200000)
end

T['fn_duration']['parses weeks'] = function()
  local args = { types.string('1w') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 604800000)
end

T['fn_duration']['parses negative duration'] = function()
  local args = { types.string('-5d') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, -432000000)
end

T['fn_duration']['parses decimal duration'] = function()
  local args = { types.string('1.5h') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 5400000)
end

T['fn_duration']['invalid duration returns duration(0)'] = function()
  local args = { types.string('invalid') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 0)
end

T['fn_duration']['no args returns null'] = function()
  local args = {}
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'null')
end

T['fn_duration']['empty string returns duration(0)'] = function()
  local args = { types.string('') }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 0)
end

T['fn_duration']['converts number to string'] = function()
  local args = { types.number(123) }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 0)
end

T['fn_duration']['converts boolean to string'] = function()
  local args = { types.boolean(true) }
  local result = functions.fn_duration(args)
  expect.equality(result.type, 'duration')
  expect.equality(result.value, 0)
end

return T
