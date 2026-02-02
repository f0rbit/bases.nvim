local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local evaluator_mod = require('bases.engine.expr.evaluator')
local types = require('bases.engine.expr.types')
local helpers = require('tests.helpers')

local T = new_set()

-- Helper to create evaluator with test data
local function make_test_evaluator(opts)
  opts = opts or {}
  local note = helpers.make_note_data({
    path = opts.path or 'projects/alpha.md',
    frontmatter = opts.frontmatter or { status = 'active', priority = 1, budget = 5000 },
    tags = opts.tags or { 'project' },
    ctime = opts.ctime or 1706054400000,
    mtime = opts.mtime or 1706140800000,
    size = opts.size or 1024,
  })
  local index = helpers.make_note_index({ note })
  return evaluator_mod.new(note, opts.formulas or {}, index, opts.this_file)
end

-- =======================
-- Literal Evaluation
-- =======================

T['literals'] = new_set()

T['literals']['number literal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('42')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 42)
end

T['literals']['decimal number literal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('3.14')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 3.14)
end

T['literals']['negative number literal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('-10')
  expect.equality(result.type, 'number')
  expect.equality(result.value, -10)
end

T['literals']['string literal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('"hello"')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello')
end

T['literals']['empty string literal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('""')
  expect.equality(result.type, 'string')
  expect.equality(result.value, '')
end

T['literals']['boolean true literal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('true')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['literals']['boolean false literal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('false')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

-- =======================
-- Frontmatter Access
-- =======================

T['frontmatter'] = new_set()

T['frontmatter']['bare identifier resolves to frontmatter'] = function()
  local ev = make_test_evaluator({ frontmatter = { status = 'active' } })
  local result = ev:eval_string('status')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'active')
end

T['frontmatter']['numeric frontmatter property'] = function()
  local ev = make_test_evaluator({ frontmatter = { priority = 5 } })
  local result = ev:eval_string('priority')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['frontmatter']['boolean frontmatter property'] = function()
  local ev = make_test_evaluator({ frontmatter = { completed = true } })
  local result = ev:eval_string('completed')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['frontmatter']['array frontmatter property'] = function()
  local ev = make_test_evaluator({ frontmatter = { tags = { 'work', 'urgent' } } })
  local result = ev:eval_string('tags')
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].value, 'work')
  expect.equality(result.value[2].value, 'urgent')
end

T['frontmatter']['missing property returns null'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  local result = ev:eval_string('nonexistent')
  expect.equality(result.type, 'null')
end

T['frontmatter']['note namespace explicit'] = function()
  local ev = make_test_evaluator({ frontmatter = { status = 'done' } })
  local result = ev:eval_string('note.status')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'done')
end

-- =======================
-- File Properties
-- =======================

T['file_properties'] = new_set()

T['file_properties']['file.name'] = function()
  local ev = make_test_evaluator({ path = 'projects/my-project.md' })
  local result = ev:eval_string('file.name')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'my-project')
end

T['file_properties']['file.path'] = function()
  local ev = make_test_evaluator({ path = 'projects/alpha.md' })
  local result = ev:eval_string('file.path')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'projects/alpha.md')
end

T['file_properties']['file.folder'] = function()
  local ev = make_test_evaluator({ path = 'projects/alpha.md' })
  local result = ev:eval_string('file.folder')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'projects')
end

T['file_properties']['file.ext'] = function()
  local ev = make_test_evaluator({ path = 'projects/alpha.md' })
  local result = ev:eval_string('file.ext')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'md')
end

T['file_properties']['file.size'] = function()
  local ev = make_test_evaluator({ size = 2048 })
  local result = ev:eval_string('file.size')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 2048)
end

T['file_properties']['file.ctime'] = function()
  local ev = make_test_evaluator({ ctime = 1609459200000 })
  local result = ev:eval_string('file.ctime')
  expect.equality(result.type, 'date')
  expect.equality(result.value, 1609459200000)
end

T['file_properties']['file.mtime'] = function()
  local ev = make_test_evaluator({ mtime = 1609545600000 })
  local result = ev:eval_string('file.mtime')
  expect.equality(result.type, 'date')
  expect.equality(result.value, 1609545600000)
end

T['file_properties']['file as identifier'] = function()
  local ev = make_test_evaluator({ path = 'projects/alpha.md' })
  local result = ev:eval_string('file')
  expect.equality(result.type, 'file')
  expect.equality(result.value.path, 'projects/alpha.md')
end

-- =======================
-- Formula Resolution
-- =======================

T['formulas'] = new_set()

T['formulas']['simple formula resolution'] = function()
  local ev = make_test_evaluator({
    frontmatter = { budget = 1000 },
    formulas = { total = 'budget * 2' },
  })
  local result = ev:eval_string('formula.total')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 2000)
end

T['formulas']['formula with arithmetic'] = function()
  local ev = make_test_evaluator({
    frontmatter = { a = 10, b = 20 },
    formulas = { sum = 'a + b' },
  })
  local result = ev:eval_string('formula.sum')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 30)
end

T['formulas']['formula referencing another formula'] = function()
  local ev = make_test_evaluator({
    frontmatter = { base = 100 },
    formulas = { doubled = 'base * 2', quadrupled = 'formula.doubled * 2' },
  })
  local result = ev:eval_string('formula.quadrupled')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 400)
end

T['formulas']['circular formula returns null'] = function()
  local ev = make_test_evaluator({
    formulas = { a = 'formula.b', b = 'formula.a' },
  })
  local result = ev:eval_string('formula.a')
  expect.equality(result.type, 'null')
end

T['formulas']['self-referencing formula returns null'] = function()
  local ev = make_test_evaluator({
    formulas = { recursive = 'formula.recursive + 1' },
  })
  local result = ev:eval_string('formula.recursive')
  expect.equality(result.type, 'null')
end

T['formulas']['missing formula returns null'] = function()
  local ev = make_test_evaluator({ formulas = {} })
  local result = ev:eval_string('formula.nonexistent')
  expect.equality(result.type, 'null')
end

T['formulas']['formula caching'] = function()
  local call_count = 0
  local ev = make_test_evaluator({
    frontmatter = { value = 10 },
    formulas = { expensive = 'value + 1' },
  })

  -- First evaluation
  local result1 = ev:eval_string('formula.expensive')
  expect.equality(result1.value, 11)

  -- Second evaluation should use cache
  local result2 = ev:eval_string('formula.expensive')
  expect.equality(result2.value, 11)
end

-- =======================
-- Arithmetic Operations
-- =======================

T['arithmetic'] = new_set()

T['arithmetic']['addition'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('3 + 5')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 8)
end

T['arithmetic']['subtraction'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('10 - 3')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 7)
end

T['arithmetic']['multiplication'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('4 * 5')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 20)
end

T['arithmetic']['division'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('10 / 4')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 2.5)
end

T['arithmetic']['division by zero returns null'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('10 / 0')
  expect.equality(result.type, 'null')
end

T['arithmetic']['modulo'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('10 % 3')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 1)
end

T['arithmetic']['modulo by zero returns null'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('10 % 0')
  expect.equality(result.type, 'null')
end

T['arithmetic']['operator precedence multiplication before addition'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('2 + 3 * 4')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 14)
end

T['arithmetic']['parentheses override precedence'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('(2 + 3) * 4')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 20)
end

T['arithmetic']['negative numbers'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('-5 + 10')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

-- =======================
-- String Concatenation
-- =======================

T['string_concat'] = new_set()

T['string_concat']['string + string'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('"hello" + " world"')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello world')
end

T['string_concat']['string + number'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('"value: " + 42')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'value: 42')
end

T['string_concat']['number + string'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('42 + " items"')
  expect.equality(result.type, 'string')
  expect.equality(result.value, '42 items')
end

T['string_concat']['string + boolean'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('"result: " + true')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'result: true')
end

-- =======================
-- Comparison Operations
-- =======================

T['comparison'] = new_set()

T['comparison']['equality true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 == 5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['equality false'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 == 3')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['comparison']['inequality true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 != 3')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['inequality false'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 != 5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['comparison']['less than true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('3 < 5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['less than false'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 < 3')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['comparison']['greater than true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 > 3')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['greater than false'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('3 > 5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['comparison']['less than or equal true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('3 <= 5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['less than or equal equal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 <= 5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['greater than or equal true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 >= 3')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['greater than or equal equal'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('5 >= 5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['string equality'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('"hello" == "hello"')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['type coercion number string'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('42 == "42"')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['comparison']['null equality'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  local result = ev:eval_string('missing == missing')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

-- =======================
-- Logical Operations
-- =======================

T['logical'] = new_set()

T['logical']['and both true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('true && true')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['logical']['and first false'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('false && true')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['logical']['and second false'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('true && false')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['logical']['and short circuit'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  -- If short-circuit works, missing property won't cause issues
  local result = ev:eval_string('false && missing')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['logical']['or both false'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('false || false')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['logical']['or first true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('true || false')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['logical']['or second true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('false || true')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['logical']['or short circuit'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  -- If short-circuit works, missing property won't cause issues
  local result = ev:eval_string('true || missing')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['logical']['not true'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('!true')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['logical']['not false'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('!false')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['logical']['not truthy value'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('!5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['logical']['not falsy value'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('!0')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

-- =======================
-- Unary Operations
-- =======================

T['unary'] = new_set()

T['unary']['minus number'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('-5')
  expect.equality(result.type, 'number')
  expect.equality(result.value, -5)
end

T['unary']['minus positive'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('-42')
  expect.equality(result.type, 'number')
  expect.equality(result.value, -42)
end

T['unary']['minus negative with spaces'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('- -5')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['unary']['negate variable via subtraction'] = function()
  local ev = make_test_evaluator({ frontmatter = { value = 10 } })
  local result = ev:eval_string('0 - value')
  expect.equality(result.type, 'number')
  expect.equality(result.value, -10)
end

T['unary']['minus non-numeric returns null'] = function()
  local ev = make_test_evaluator({ frontmatter = { text = 'hello' } })
  local result = ev:eval_string('-text')
  expect.equality(result.type, 'null')
end

-- =======================
-- Date Arithmetic
-- =======================

T['date_arithmetic'] = new_set()

T['date_arithmetic']['date plus duration'] = function()
  local ev = make_test_evaluator()
  local base_date = 1609459200000 -- 2021-01-01
  local one_day = 86400000 -- 24 hours in ms
  local result = ev:eval_string(base_date .. ' + ' .. one_day)
  expect.equality(result.type, 'number')
  expect.equality(result.value, base_date + one_day)
end

T['date_arithmetic']['date minus date'] = function()
  local ev = make_test_evaluator({ frontmatter = { start = 1609459200000, finish = 1609545600000 } })
  local result = ev:eval_string('finish - start')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 86400000)
end

-- =======================
-- Array Literals
-- =======================

T['arrays'] = new_set()

T['arrays']['empty array'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('[]')
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 0)
end

T['arrays']['number array'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('[1, 2, 3]')
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].type, 'number')
  expect.equality(result.value[1].value, 1)
  expect.equality(result.value[2].value, 2)
  expect.equality(result.value[3].value, 3)
end

T['arrays']['string array'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('["a", "b", "c"]')
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].type, 'string')
  expect.equality(result.value[1].value, 'a')
end

T['arrays']['mixed type array'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('[1, "two", true]')
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].type, 'number')
  expect.equality(result.value[2].type, 'string')
  expect.equality(result.value[3].type, 'boolean')
end

T['arrays']['nested array'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('[[1, 2], [3, 4]]')
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].type, 'list')
  expect.equality(#result.value[1].value, 2)
end

T['arrays']['array with expressions'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('[1 + 1, 2 * 2, 3 - 1]')
  expect.equality(result.type, 'list')
  expect.equality(result.value[1].value, 2)
  expect.equality(result.value[2].value, 4)
  expect.equality(result.value[3].value, 2)
end

-- =======================
-- Index Access
-- =======================

T['index_access'] = new_set()

T['index_access']['array index zero-based'] = function()
  local ev = make_test_evaluator({ frontmatter = { items = { 'a', 'b', 'c' } } })
  local result = ev:eval_string('items[0]')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'a')
end

T['index_access']['array index first'] = function()
  local ev = make_test_evaluator({ frontmatter = { items = { 'a', 'b', 'c' } } })
  local result = ev:eval_string('items[1]')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'b')
end

T['index_access']['array index last'] = function()
  local ev = make_test_evaluator({ frontmatter = { items = { 'a', 'b', 'c' } } })
  local result = ev:eval_string('items[2]')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'c')
end

T['index_access']['array index out of bounds'] = function()
  local ev = make_test_evaluator({ frontmatter = { items = { 'a', 'b' } } })
  local result = ev:eval_string('items[5]')
  expect.equality(result.type, 'null')
end

T['index_access']['array index negative'] = function()
  local ev = make_test_evaluator({ frontmatter = { items = { 'a', 'b', 'c' } } })
  local result = ev:eval_string('items[-1]')
  expect.equality(result.type, 'null')
end

T['index_access']['literal array index'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('[10, 20, 30][1]')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 20)
end

-- =======================
-- This Namespace
-- =======================

T['this_namespace'] = new_set()

T['this_namespace']['this.property with this_file'] = function()
  local this_file = helpers.make_note_data({
    path = 'context.md',
    frontmatter = { category = 'meta' },
  })
  local ev = make_test_evaluator({ this_file = this_file })
  local result = ev:eval_string('this.category')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'meta')
end

T['this_namespace']['this.property without this_file returns null'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('this.field')
  expect.equality(result.type, 'null')
end

T['this_namespace']['this.property missing in this_file returns null'] = function()
  local this_file = helpers.make_note_data({
    path = 'context.md',
    frontmatter = {},
  })
  local ev = make_test_evaluator({ this_file = this_file })
  local result = ev:eval_string('this.missing')
  expect.equality(result.type, 'null')
end

-- =======================
-- Null Handling
-- =======================

T['null_handling'] = new_set()

T['null_handling']['missing property returns null'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  local result = ev:eval_string('nonexistent')
  expect.equality(result.type, 'null')
end

T['null_handling']['null plus number returns null'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  local result = ev:eval_string('missing + 5')
  expect.equality(result.type, 'null')
end

T['null_handling']['null minus number returns null'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  local result = ev:eval_string('missing - 5')
  expect.equality(result.type, 'null')
end

T['null_handling']['null times number returns null'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  local result = ev:eval_string('missing * 5')
  expect.equality(result.type, 'null')
end

T['null_handling']['null divided by number returns null'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  local result = ev:eval_string('missing / 5')
  expect.equality(result.type, 'null')
end

T['null_handling']['null comparison with number'] = function()
  local ev = make_test_evaluator({ frontmatter = {} })
  local result = ev:eval_string('missing == 5')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['null_handling']['parse error returns null'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('invalid syntax @@#')
  expect.equality(result.type, 'null')
end

-- =======================
-- Integration Tests
-- =======================

T['integration'] = new_set()

T['integration']['complex expression with frontmatter'] = function()
  local ev = make_test_evaluator({ frontmatter = { budget = 1000, spent = 300 } })
  local result = ev:eval_string('(budget - spent) / budget')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0.7)
end

T['integration']['formula with comparison'] = function()
  local ev = make_test_evaluator({
    frontmatter = { progress = 75, target = 100 },
    formulas = { complete = 'progress >= target' },
  })
  local result = ev:eval_string('formula.complete')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['integration']['conditional with logical operators'] = function()
  local ev = make_test_evaluator({ frontmatter = { score = 85, passing = 60 } })
  local result = ev:eval_string('score >= passing && score < 90')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['integration']['array access with calculation'] = function()
  local ev = make_test_evaluator({ frontmatter = { values = { 10, 20, 30 } } })
  local result = ev:eval_string('values[1] * 2')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 40)
end

T['integration']['file properties in expression'] = function()
  local ev = make_test_evaluator({ path = 'projects/important.md', frontmatter = { priority = 5 } })
  local result = ev:eval_string('priority > 3 && file.folder == "projects"')
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['integration']['nested array literal with indexing'] = function()
  local ev = make_test_evaluator()
  local result = ev:eval_string('[[1, 2], [3, 4]][1][0]')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 3)
end

T['integration']['string concatenation with properties'] = function()
  local ev = make_test_evaluator({ path = 'notes/test.md', frontmatter = { name = 'Project Alpha' } })
  local result = ev:eval_string('name + " in " + file.folder')
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'Project Alpha in notes')
end

return T
