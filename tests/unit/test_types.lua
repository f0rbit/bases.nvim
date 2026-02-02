local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local types = require('bases.engine.expr.types')

local T = new_set()

-- =======================
-- Constructors
-- =======================

T['constructors'] = new_set()

T['constructors']['string'] = function()
  local tv = types.string('hello')
  expect.equality(tv.type, 'string')
  expect.equality(tv.value, 'hello')
end

T['constructors']['string coerces non-string'] = function()
  local tv = types.string(42)
  expect.equality(tv.type, 'string')
  expect.equality(tv.value, '42')
end

T['constructors']['number'] = function()
  local tv = types.number(42)
  expect.equality(tv.type, 'number')
  expect.equality(tv.value, 42)
end

T['constructors']['number with decimal'] = function()
  local tv = types.number(3.14)
  expect.equality(tv.type, 'number')
  expect.equality(tv.value, 3.14)
end

T['constructors']['number coerces string'] = function()
  local tv = types.number('42')
  expect.equality(tv.type, 'number')
  expect.equality(tv.value, 42)
end

T['constructors']['boolean true'] = function()
  local tv = types.boolean(true)
  expect.equality(tv.type, 'boolean')
  expect.equality(tv.value, true)
end

T['constructors']['boolean false'] = function()
  local tv = types.boolean(false)
  expect.equality(tv.type, 'boolean')
  expect.equality(tv.value, false)
end

T['constructors']['boolean coerces truthy value'] = function()
  local tv = types.boolean('hello')
  expect.equality(tv.type, 'boolean')
  expect.equality(tv.value, true)
end

T['constructors']['boolean coerces nil'] = function()
  local tv = types.boolean(nil)
  expect.equality(tv.type, 'boolean')
  expect.equality(tv.value, false)
end

T['constructors']['date'] = function()
  local tv = types.date(1609459200000)
  expect.equality(tv.type, 'date')
  expect.equality(tv.value, 1609459200000)
end

T['constructors']['duration'] = function()
  local tv = types.duration(86400000)
  expect.equality(tv.type, 'duration')
  expect.equality(tv.value, 86400000)
end

T['constructors']['link with path only'] = function()
  local tv = types.link('note')
  expect.equality(tv.type, 'link')
  expect.equality(tv.value, 'note')
  expect.equality(tv.path, 'note')
end

T['constructors']['link with path and display'] = function()
  local tv = types.link('path/to/note', 'My Note')
  expect.equality(tv.type, 'link')
  expect.equality(tv.value, 'My Note')
  expect.equality(tv.path, 'path/to/note')
end

T['constructors']['list empty'] = function()
  local tv = types.list({})
  expect.equality(tv.type, 'list')
  expect.equality(#tv.value, 0)
end

T['constructors']['list with items'] = function()
  local items = { types.number(1), types.string('a'), types.boolean(true) }
  local tv = types.list(items)
  expect.equality(tv.type, 'list')
  expect.equality(#tv.value, 3)
  expect.equality(tv.value[1].value, 1)
  expect.equality(tv.value[2].value, 'a')
  expect.equality(tv.value[3].value, true)
end

T['constructors']['file'] = function()
  local note_data = { path = 'note.md', content = 'test' }
  local tv = types.file(note_data)
  expect.equality(tv.type, 'file')
  expect.equality(tv.value.path, 'note.md')
end

T['constructors']['null'] = function()
  local tv = types.null()
  expect.equality(tv.type, 'null')
  expect.equality(tv.value, nil)
end

T['constructors']['image'] = function()
  local tv = types.image('image.png')
  expect.equality(tv.type, 'image')
  expect.equality(tv.value, 'image.png')
end

T['constructors']['regex without flags'] = function()
  local tv = types.regex('pattern')
  expect.equality(tv.type, 'regex')
  expect.equality(tv.value, 'pattern')
  expect.equality(tv.flags, '')
end

T['constructors']['regex with flags'] = function()
  local tv = types.regex('pattern', 'gi')
  expect.equality(tv.type, 'regex')
  expect.equality(tv.value, 'pattern')
  expect.equality(tv.flags, 'gi')
end

T['constructors']['object empty'] = function()
  local tv = types.object({})
  expect.equality(tv.type, 'object')
  expect.equality(next(tv.value), nil)
end

T['constructors']['object with entries'] = function()
  local entries = { name = types.string('John'), age = types.number(30) }
  local tv = types.object(entries)
  expect.equality(tv.type, 'object')
  expect.equality(tv.value.name.value, 'John')
  expect.equality(tv.value.age.value, 30)
end

-- =======================
-- from_raw
-- =======================

T['from_raw'] = new_set()

T['from_raw']['nil to null'] = function()
  local tv = types.from_raw(nil)
  expect.equality(tv.type, 'null')
  expect.equality(tv.value, nil)
end

T['from_raw']['string'] = function()
  local tv = types.from_raw('hello')
  expect.equality(tv.type, 'string')
  expect.equality(tv.value, 'hello')
end

T['from_raw']['link without display'] = function()
  local tv = types.from_raw('[[note]]')
  expect.equality(tv.type, 'link')
  expect.equality(tv.value, 'note')
  expect.equality(tv.path, 'note')
end

T['from_raw']['link with display'] = function()
  local tv = types.from_raw('[[path/to/note|My Note]]')
  expect.equality(tv.type, 'link')
  expect.equality(tv.value, 'My Note')
  expect.equality(tv.path, 'path/to/note')
end

T['from_raw']['link with nested brackets in text'] = function()
  local tv = types.from_raw('text [[link]] more')
  expect.equality(tv.type, 'string')
  expect.equality(tv.value, 'text [[link]] more')
end

T['from_raw']['number'] = function()
  local tv = types.from_raw(42)
  expect.equality(tv.type, 'number')
  expect.equality(tv.value, 42)
end

T['from_raw']['number decimal'] = function()
  local tv = types.from_raw(3.14)
  expect.equality(tv.type, 'number')
  expect.equality(tv.value, 3.14)
end

T['from_raw']['boolean true'] = function()
  local tv = types.from_raw(true)
  expect.equality(tv.type, 'boolean')
  expect.equality(tv.value, true)
end

T['from_raw']['boolean false'] = function()
  local tv = types.from_raw(false)
  expect.equality(tv.type, 'boolean')
  expect.equality(tv.value, false)
end

T['from_raw']['list'] = function()
  local tv = types.from_raw({ 1, 2, 3 })
  expect.equality(tv.type, 'list')
  expect.equality(#tv.value, 3)
  expect.equality(tv.value[1].type, 'number')
  expect.equality(tv.value[1].value, 1)
  expect.equality(tv.value[2].value, 2)
  expect.equality(tv.value[3].value, 3)
end

T['from_raw']['list with mixed types'] = function()
  local tv = types.from_raw({ 'hello', 42, true })
  expect.equality(tv.type, 'list')
  expect.equality(#tv.value, 3)
  expect.equality(tv.value[1].type, 'string')
  expect.equality(tv.value[2].type, 'number')
  expect.equality(tv.value[3].type, 'boolean')
end

T['from_raw']['nested list'] = function()
  local tv = types.from_raw({ { 1, 2 }, { 3, 4 } })
  expect.equality(tv.type, 'list')
  expect.equality(#tv.value, 2)
  expect.equality(tv.value[1].type, 'list')
  expect.equality(tv.value[1].value[1].value, 1)
end

T['from_raw']['object'] = function()
  local tv = types.from_raw({ name = 'John', age = 30 })
  expect.equality(tv.type, 'object')
  expect.equality(tv.value.name.type, 'string')
  expect.equality(tv.value.name.value, 'John')
  expect.equality(tv.value.age.type, 'number')
  expect.equality(tv.value.age.value, 30)
end

T['from_raw']['object with numeric keys as strings'] = function()
  local tv = types.from_raw({ [100] = 'value' })
  expect.equality(tv.type, 'object')
  expect.equality(tv.value['100'].value, 'value')
end

T['from_raw']['nested object'] = function()
  local tv = types.from_raw({ person = { name = 'John', age = 30 } })
  expect.equality(tv.type, 'object')
  expect.equality(tv.value.person.type, 'object')
  expect.equality(tv.value.person.value.name.value, 'John')
end

T['from_raw']['function fallback to string'] = function()
  local fn = function() end
  local tv = types.from_raw(fn)
  expect.equality(tv.type, 'string')
  expect.no_equality(tv.value:find('function', 1, true), nil)
end

-- =======================
-- to_number
-- =======================

T['to_number'] = new_set()

T['to_number']['number'] = function()
  local result = types.to_number(types.number(42))
  expect.equality(result, 42)
end

T['to_number']['number decimal'] = function()
  local result = types.to_number(types.number(3.14))
  expect.equality(result, 3.14)
end

T['to_number']['string with valid number'] = function()
  local result = types.to_number(types.string('42'))
  expect.equality(result, 42)
end

T['to_number']['string with decimal'] = function()
  local result = types.to_number(types.string('3.14'))
  expect.equality(result, 3.14)
end

T['to_number']['string invalid'] = function()
  local result = types.to_number(types.string('abc'))
  expect.equality(result, nil)
end

T['to_number']['boolean true'] = function()
  local result = types.to_number(types.boolean(true))
  expect.equality(result, 1)
end

T['to_number']['boolean false'] = function()
  local result = types.to_number(types.boolean(false))
  expect.equality(result, 0)
end

T['to_number']['date'] = function()
  local result = types.to_number(types.date(1609459200000))
  expect.equality(result, 1609459200000)
end

T['to_number']['duration'] = function()
  local result = types.to_number(types.duration(86400000))
  expect.equality(result, 86400000)
end

T['to_number']['list'] = function()
  local result = types.to_number(types.list({ types.number(1) }))
  expect.equality(result, nil)
end

T['to_number']['null'] = function()
  local result = types.to_number(types.null())
  expect.equality(result, nil)
end

T['to_number']['link'] = function()
  local result = types.to_number(types.link('note'))
  expect.equality(result, nil)
end

T['to_number']['object'] = function()
  local result = types.to_number(types.object({}))
  expect.equality(result, nil)
end

-- =======================
-- to_string
-- =======================

T['to_string'] = new_set()

T['to_string']['string'] = function()
  local result = types.to_string(types.string('hello'))
  expect.equality(result, 'hello')
end

T['to_string']['number'] = function()
  local result = types.to_string(types.number(42))
  expect.equality(result, '42')
end

T['to_string']['number decimal'] = function()
  local result = types.to_string(types.number(3.14))
  expect.equality(result, '3.14')
end

T['to_string']['boolean true'] = function()
  local result = types.to_string(types.boolean(true))
  expect.equality(result, 'true')
end

T['to_string']['boolean false'] = function()
  local result = types.to_string(types.boolean(false))
  expect.equality(result, 'false')
end

T['to_string']['date'] = function()
  local result = types.to_string(types.date(1609459200000))
  expect.equality(type(result), 'string')
  expect.equality(#result, 19)
end

T['to_string']['duration'] = function()
  local result = types.to_string(types.duration(86400000))
  expect.equality(result, '86400000')
end

T['to_string']['list empty'] = function()
  local result = types.to_string(types.list({}))
  expect.equality(result, '')
end

T['to_string']['list with items'] = function()
  local items = { types.string('a'), types.string('b'), types.string('c') }
  local result = types.to_string(types.list(items))
  expect.equality(result, 'a, b, c')
end

T['to_string']['list with mixed types'] = function()
  local items = { types.number(1), types.string('a'), types.boolean(true) }
  local result = types.to_string(types.list(items))
  expect.equality(result, '1, a, true')
end

T['to_string']['null'] = function()
  local result = types.to_string(types.null())
  expect.equality(result, '')
end

T['to_string']['link'] = function()
  local result = types.to_string(types.link('path/to/note', 'My Note'))
  expect.equality(result, 'My Note')
end

T['to_string']['link without display'] = function()
  local result = types.to_string(types.link('note'))
  expect.equality(result, 'note')
end

T['to_string']['file with path'] = function()
  local result = types.to_string(types.file({ path = 'folder/note.md' }))
  expect.equality(result, 'note.md')
end

T['to_string']['file with path no folder'] = function()
  local result = types.to_string(types.file({ path = 'note.md' }))
  expect.equality(result, 'note.md')
end

T['to_string']['file without path'] = function()
  local result = types.to_string(types.file({}))
  expect.equality(result, '')
end

T['to_string']['image'] = function()
  local result = types.to_string(types.image('image.png'))
  expect.equality(result, 'image.png')
end

T['to_string']['regex without flags'] = function()
  local result = types.to_string(types.regex('pattern'))
  expect.equality(result, '/pattern/')
end

T['to_string']['regex with flags'] = function()
  local result = types.to_string(types.regex('pattern', 'gi'))
  expect.equality(result, '/pattern/gi')
end

T['to_string']['object'] = function()
  local result = types.to_string(types.object({ name = types.string('John') }))
  expect.equality(result, '[object]')
end

-- =======================
-- to_boolean / is_truthy
-- =======================

T['to_boolean'] = new_set()

T['to_boolean']['boolean true'] = function()
  local result = types.to_boolean(types.boolean(true))
  expect.equality(result, true)
end

T['to_boolean']['boolean false'] = function()
  local result = types.to_boolean(types.boolean(false))
  expect.equality(result, false)
end

T['to_boolean']['string non-empty'] = function()
  local result = types.to_boolean(types.string('hello'))
  expect.equality(result, true)
end

T['to_boolean']['string empty'] = function()
  local result = types.to_boolean(types.string(''))
  expect.equality(result, false)
end

T['to_boolean']['number non-zero'] = function()
  local result = types.to_boolean(types.number(42))
  expect.equality(result, true)
end

T['to_boolean']['number zero'] = function()
  local result = types.to_boolean(types.number(0))
  expect.equality(result, false)
end

T['to_boolean']['number negative'] = function()
  local result = types.to_boolean(types.number(-1))
  expect.equality(result, true)
end

T['to_boolean']['list non-empty'] = function()
  local result = types.to_boolean(types.list({ types.number(1) }))
  expect.equality(result, true)
end

T['to_boolean']['list empty'] = function()
  local result = types.to_boolean(types.list({}))
  expect.equality(result, false)
end

T['to_boolean']['null'] = function()
  local result = types.to_boolean(types.null())
  expect.equality(result, false)
end

T['to_boolean']['date'] = function()
  local result = types.to_boolean(types.date(1609459200000))
  expect.equality(result, true)
end

T['to_boolean']['duration'] = function()
  local result = types.to_boolean(types.duration(0))
  expect.equality(result, true)
end

T['to_boolean']['link'] = function()
  local result = types.to_boolean(types.link('note'))
  expect.equality(result, true)
end

T['to_boolean']['file'] = function()
  local result = types.to_boolean(types.file({ path = 'note.md' }))
  expect.equality(result, true)
end

T['to_boolean']['image'] = function()
  local result = types.to_boolean(types.image('image.png'))
  expect.equality(result, true)
end

T['to_boolean']['regex'] = function()
  local result = types.to_boolean(types.regex('pattern'))
  expect.equality(result, true)
end

T['to_boolean']['object'] = function()
  local result = types.to_boolean(types.object({}))
  expect.equality(result, true)
end

T['is_truthy'] = new_set()

T['is_truthy']['same as to_boolean for true'] = function()
  local tv = types.boolean(true)
  expect.equality(types.is_truthy(tv), types.to_boolean(tv))
end

T['is_truthy']['same as to_boolean for false'] = function()
  local tv = types.boolean(false)
  expect.equality(types.is_truthy(tv), types.to_boolean(tv))
end

T['is_truthy']['same as to_boolean for string'] = function()
  local tv = types.string('test')
  expect.equality(types.is_truthy(tv), types.to_boolean(tv))
end

-- =======================
-- parse_duration
-- =======================

T['parse_duration'] = new_set()

T['parse_duration']['seconds short'] = function()
  local result = types.parse_duration('5s')
  expect.equality(result, 5000)
end

T['parse_duration']['seconds long'] = function()
  local result = types.parse_duration('10seconds')
  expect.equality(result, 10000)
end

T['parse_duration']['second singular'] = function()
  local result = types.parse_duration('1second')
  expect.equality(result, 1000)
end

T['parse_duration']['minutes short'] = function()
  local result = types.parse_duration('5m')
  expect.equality(result, 300000)
end

T['parse_duration']['minutes long'] = function()
  local result = types.parse_duration('10minutes')
  expect.equality(result, 600000)
end

T['parse_duration']['minute singular'] = function()
  local result = types.parse_duration('1minute')
  expect.equality(result, 60000)
end

T['parse_duration']['hours short'] = function()
  local result = types.parse_duration('2h')
  expect.equality(result, 7200000)
end

T['parse_duration']['hours long'] = function()
  local result = types.parse_duration('3hours')
  expect.equality(result, 10800000)
end

T['parse_duration']['hour singular'] = function()
  local result = types.parse_duration('1hour')
  expect.equality(result, 3600000)
end

T['parse_duration']['days short'] = function()
  local result = types.parse_duration('7d')
  expect.equality(result, 604800000)
end

T['parse_duration']['days long'] = function()
  local result = types.parse_duration('2days')
  expect.equality(result, 172800000)
end

T['parse_duration']['day singular'] = function()
  local result = types.parse_duration('1day')
  expect.equality(result, 86400000)
end

T['parse_duration']['weeks short'] = function()
  local result = types.parse_duration('2w')
  expect.equality(result, 1209600000)
end

T['parse_duration']['weeks long'] = function()
  local result = types.parse_duration('3weeks')
  expect.equality(result, 1814400000)
end

T['parse_duration']['week singular'] = function()
  local result = types.parse_duration('1week')
  expect.equality(result, 604800000)
end

T['parse_duration']['months short'] = function()
  local result = types.parse_duration('2M')
  expect.equality(result, 5184000000)
end

T['parse_duration']['months long'] = function()
  local result = types.parse_duration('3months')
  expect.equality(result, 7776000000)
end

T['parse_duration']['month singular'] = function()
  local result = types.parse_duration('1month')
  expect.equality(result, 2592000000)
end

T['parse_duration']['years short'] = function()
  local result = types.parse_duration('2y')
  expect.equality(result, 63072000000)
end

T['parse_duration']['years long'] = function()
  local result = types.parse_duration('5years')
  expect.equality(result, 157680000000)
end

T['parse_duration']['year singular'] = function()
  local result = types.parse_duration('1year')
  expect.equality(result, 31536000000)
end

T['parse_duration']['decimal seconds'] = function()
  local result = types.parse_duration('1.5s')
  expect.equality(result, 1500)
end

T['parse_duration']['decimal days'] = function()
  local result = types.parse_duration('1.5d')
  expect.equality(result, 129600000)
end

T['parse_duration']['negative seconds'] = function()
  local result = types.parse_duration('-5s')
  expect.equality(result, -5000)
end

T['parse_duration']['negative days'] = function()
  local result = types.parse_duration('-2d')
  expect.equality(result, -172800000)
end

T['parse_duration']['with whitespace'] = function()
  local result = types.parse_duration('  5d  ')
  expect.equality(result, 432000000)
end

T['parse_duration']['with space before unit'] = function()
  local result = types.parse_duration('5 days')
  expect.equality(result, 432000000)
end

T['parse_duration']['invalid no unit'] = function()
  local result = types.parse_duration('42')
  expect.equality(result, nil)
end

T['parse_duration']['invalid no number'] = function()
  local result = types.parse_duration('days')
  expect.equality(result, nil)
end

T['parse_duration']['invalid unknown unit'] = function()
  local result = types.parse_duration('5x')
  expect.equality(result, nil)
end

T['parse_duration']['invalid empty string'] = function()
  local result = types.parse_duration('')
  expect.equality(result, nil)
end

T['parse_duration']['invalid text'] = function()
  local result = types.parse_duration('hello')
  expect.equality(result, nil)
end

-- =======================
-- date_from_iso
-- =======================

T['date_from_iso'] = new_set()

T['date_from_iso']['date only YYYY-MM-DD'] = function()
  local result = types.date_from_iso('2021-01-01')
  expect.equality(result.type, 'date')
  expect.no_equality(result.value, nil)
end

T['date_from_iso']['date with time YYYY-MM-DDTHH:MM:SS'] = function()
  local result = types.date_from_iso('2021-01-01T12:30:45')
  expect.equality(result.type, 'date')
  expect.no_equality(result.value, nil)
end

T['date_from_iso']['date with zero time'] = function()
  local result = types.date_from_iso('2021-01-01T00:00:00')
  expect.equality(result.type, 'date')
  expect.no_equality(result.value, nil)
end

T['date_from_iso']['date end of year'] = function()
  local result = types.date_from_iso('2021-12-31T23:59:59')
  expect.equality(result.type, 'date')
  expect.no_equality(result.value, nil)
end

T['date_from_iso']['invalid format'] = function()
  local result = types.date_from_iso('2021/01/01')
  expect.equality(result, nil)
end

T['date_from_iso']['invalid date'] = function()
  local result = types.date_from_iso('not-a-date')
  expect.equality(result, nil)
end

T['date_from_iso']['invalid month'] = function()
  -- Note: os.time() normalizes invalid dates, so 2021-13-01 becomes 2022-01-01
  local result = types.date_from_iso('2021-13-01')
  expect.equality(result.type, 'date')
  expect.no_equality(result.value, nil)
end

T['date_from_iso']['invalid day'] = function()
  -- Note: os.time() normalizes invalid dates, so 2021-01-32 becomes 2021-02-01
  local result = types.date_from_iso('2021-01-32')
  expect.equality(result.type, 'date')
  expect.no_equality(result.value, nil)
end

T['date_from_iso']['empty string'] = function()
  local result = types.date_from_iso('')
  expect.equality(result, nil)
end

-- =======================
-- date_to_iso
-- =======================

T['date_to_iso'] = new_set()

T['date_to_iso']['formats milliseconds correctly'] = function()
  local result = types.date_to_iso(1609459200000)
  expect.equality(type(result), 'string')
  expect.equality(#result, 19)
end

T['date_to_iso']['zero timestamp'] = function()
  local result = types.date_to_iso(0)
  expect.equality(type(result), 'string')
  expect.equality(#result, 19)
end

T['date_to_iso']['has correct format structure'] = function()
  local result = types.date_to_iso(1609459200000)
  expect.equality(#result, 19)
  expect.equality(result:sub(5, 5), '-')
  expect.equality(result:sub(8, 8), '-')
  expect.equality(result:sub(11, 11), 'T')
  expect.equality(result:sub(14, 14), ':')
  expect.equality(result:sub(17, 17), ':')
end

T['date_to_iso']['round trip consistency'] = function()
  local original_iso = '2021-06-15T10:30:00'
  local date_tv = types.date_from_iso(original_iso)
  expect.no_equality(date_tv, nil)
  local converted_iso = types.date_to_iso(date_tv.value)
  expect.equality(converted_iso, original_iso)
end

return T
