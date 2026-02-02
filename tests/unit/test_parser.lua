local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local parser = require('bases.engine.expr.parser')

local T = new_set()

-- =======================
-- Literal Nodes
-- =======================

T['parse_expression'] = new_set()

T['parse_expression']['number literal'] = function()
  local ast, err = parser.parse_expression('42')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.value, 42)
  expect.equality(ast.datatype, 'number')
end

T['parse_expression']['negative number literal'] = function()
  local ast, err = parser.parse_expression('-42')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.value, -42)
  expect.equality(ast.datatype, 'number')
end

T['parse_expression']['decimal number literal'] = function()
  local ast, err = parser.parse_expression('3.14')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.value, 3.14)
  expect.equality(ast.datatype, 'number')
end

T['parse_expression']['string literal double quotes'] = function()
  local ast, err = parser.parse_expression('"hello world"')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.value, 'hello world')
  expect.equality(ast.datatype, 'string')
end

T['parse_expression']['string literal single quotes'] = function()
  local ast, err = parser.parse_expression("'hello world'")
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.value, 'hello world')
  expect.equality(ast.datatype, 'string')
end

T['parse_expression']['empty string literal'] = function()
  local ast, err = parser.parse_expression('""')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.value, '')
  expect.equality(ast.datatype, 'string')
end

T['parse_expression']['boolean literal true'] = function()
  local ast, err = parser.parse_expression('true')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.value, true)
  expect.equality(ast.datatype, 'boolean')
end

T['parse_expression']['boolean literal false'] = function()
  local ast, err = parser.parse_expression('false')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.value, false)
  expect.equality(ast.datatype, 'boolean')
end

T['parse_expression']['regex literal'] = function()
  local ast, err = parser.parse_expression('/pattern/')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.datatype, 'regex')
  expect.equality(ast.value.pattern, 'pattern')
  expect.equality(ast.value.flags, '')
end

T['parse_expression']['regex literal with flags'] = function()
  local ast, err = parser.parse_expression('/pattern/g')
  expect.equality(err, nil)
  expect.equality(ast.type, 'literal')
  expect.equality(ast.datatype, 'regex')
  expect.equality(ast.value.pattern, 'pattern')
  expect.equality(ast.value.flags, 'g')
end

-- =======================
-- Identifier Nodes
-- =======================

T['parse_expression']['simple identifier'] = function()
  local ast, err = parser.parse_expression('file')
  expect.equality(err, nil)
  expect.equality(ast.type, 'identifier')
  expect.equality(ast.name, 'file')
end

T['parse_expression']['identifier with underscore'] = function()
  local ast, err = parser.parse_expression('my_var')
  expect.equality(err, nil)
  expect.equality(ast.type, 'identifier')
  expect.equality(ast.name, 'my_var')
end

-- =======================
-- Binary Operations
-- =======================

T['parse_expression']['addition'] = function()
  local ast, err = parser.parse_expression('a + b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '+')
  expect.equality(ast.left.type, 'identifier')
  expect.equality(ast.left.name, 'a')
  expect.equality(ast.right.type, 'identifier')
  expect.equality(ast.right.name, 'b')
end

T['parse_expression']['subtraction'] = function()
  local ast, err = parser.parse_expression('a - b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '-')
end

T['parse_expression']['multiplication'] = function()
  local ast, err = parser.parse_expression('a * b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '*')
end

T['parse_expression']['division'] = function()
  local ast, err = parser.parse_expression('a / b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '/')
end

T['parse_expression']['modulo'] = function()
  local ast, err = parser.parse_expression('a % b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '%')
end

T['parse_expression']['equality'] = function()
  local ast, err = parser.parse_expression('a == b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '==')
end

T['parse_expression']['inequality'] = function()
  local ast, err = parser.parse_expression('a != b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '!=')
end

T['parse_expression']['less than'] = function()
  local ast, err = parser.parse_expression('a < b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '<')
end

T['parse_expression']['greater than'] = function()
  local ast, err = parser.parse_expression('a > b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '>')
end

T['parse_expression']['less than or equal'] = function()
  local ast, err = parser.parse_expression('a <= b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '<=')
end

T['parse_expression']['greater than or equal'] = function()
  local ast, err = parser.parse_expression('a >= b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '>=')
end

T['parse_expression']['logical AND'] = function()
  local ast, err = parser.parse_expression('a && b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '&&')
end

T['parse_expression']['logical OR'] = function()
  local ast, err = parser.parse_expression('a || b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '||')
end

-- =======================
-- Operator Precedence
-- =======================

T['parse_expression']['multiplication before addition'] = function()
  -- a + b * c should parse as a + (b * c)
  local ast, err = parser.parse_expression('a + b * c')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '+')
  expect.equality(ast.left.name, 'a')
  expect.equality(ast.right.type, 'binary_op')
  expect.equality(ast.right.operator, '*')
  expect.equality(ast.right.left.name, 'b')
  expect.equality(ast.right.right.name, 'c')
end

T['parse_expression']['addition before equality'] = function()
  -- a == b + c should parse as a == (b + c)
  local ast, err = parser.parse_expression('a == b + c')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '==')
  expect.equality(ast.left.name, 'a')
  expect.equality(ast.right.type, 'binary_op')
  expect.equality(ast.right.operator, '+')
end

T['parse_expression']['equality before AND'] = function()
  -- a && b == c should parse as a && (b == c)
  local ast, err = parser.parse_expression('a && b == c')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '&&')
  expect.equality(ast.left.name, 'a')
  expect.equality(ast.right.type, 'binary_op')
  expect.equality(ast.right.operator, '==')
end

T['parse_expression']['AND before OR'] = function()
  -- a || b && c should parse as a || (b && c)
  local ast, err = parser.parse_expression('a || b && c')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '||')
  expect.equality(ast.left.name, 'a')
  expect.equality(ast.right.type, 'binary_op')
  expect.equality(ast.right.operator, '&&')
end

T['parse_expression']['left associativity for addition'] = function()
  -- a + b + c should parse as (a + b) + c
  local ast, err = parser.parse_expression('a + b + c')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '+')
  expect.equality(ast.right.name, 'c')
  expect.equality(ast.left.type, 'binary_op')
  expect.equality(ast.left.operator, '+')
  expect.equality(ast.left.left.name, 'a')
  expect.equality(ast.left.right.name, 'b')
end

T['parse_expression']['complex precedence'] = function()
  -- a + b * c - d / e should parse as (a + (b * c)) - (d / e)
  local ast, err = parser.parse_expression('a + b * c - d / e')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '-')

  -- Left side: a + (b * c)
  expect.equality(ast.left.type, 'binary_op')
  expect.equality(ast.left.operator, '+')
  expect.equality(ast.left.right.operator, '*')

  -- Right side: d / e
  expect.equality(ast.right.type, 'binary_op')
  expect.equality(ast.right.operator, '/')
end

-- =======================
-- Unary Operations
-- =======================

T['parse_expression']['logical NOT'] = function()
  local ast, err = parser.parse_expression('!active')
  expect.equality(err, nil)
  expect.equality(ast.type, 'unary_op')
  expect.equality(ast.operator, '!')
  expect.equality(ast.operand.type, 'identifier')
  expect.equality(ast.operand.name, 'active')
end

T['parse_expression']['unary minus with binary context'] = function()
  -- Test unary minus in a context where it's a binary operator with spaces
  -- The expression "a + - b" has unary minus on b after the plus operator
  local ast, err = parser.parse_expression('a + - b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '+')
  expect.equality(ast.left.name, 'a')
  expect.equality(ast.right.type, 'unary_op')
  expect.equality(ast.right.operator, '-')
  expect.equality(ast.right.operand.name, 'b')
end

T['parse_expression']['double negation'] = function()
  local ast, err = parser.parse_expression('!!x')
  expect.equality(err, nil)
  expect.equality(ast.type, 'unary_op')
  expect.equality(ast.operator, '!')
  expect.equality(ast.operand.type, 'unary_op')
  expect.equality(ast.operand.operator, '!')
  expect.equality(ast.operand.operand.name, 'x')
end

T['parse_expression']['unary has higher precedence than binary'] = function()
  -- !a && b should parse as (!a) && b
  local ast, err = parser.parse_expression('!a && b')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '&&')
  expect.equality(ast.left.type, 'unary_op')
  expect.equality(ast.left.operator, '!')
  expect.equality(ast.right.name, 'b')
end

-- =======================
-- Member Access
-- =======================

T['parse_expression']['simple member access'] = function()
  local ast, err = parser.parse_expression('file.name')
  expect.equality(err, nil)
  expect.equality(ast.type, 'member')
  expect.equality(ast.object.type, 'identifier')
  expect.equality(ast.object.name, 'file')
  expect.equality(ast.property, 'name')
end

T['parse_expression']['chained member access'] = function()
  local ast, err = parser.parse_expression('file.name.length')
  expect.equality(err, nil)
  expect.equality(ast.type, 'member')
  expect.equality(ast.property, 'length')
  expect.equality(ast.object.type, 'member')
  expect.equality(ast.object.property, 'name')
  expect.equality(ast.object.object.name, 'file')
end

T['parse_expression']['deeply nested member access'] = function()
  local ast, err = parser.parse_expression('a.b.c.d')
  expect.equality(err, nil)
  expect.equality(ast.type, 'member')
  expect.equality(ast.property, 'd')
  expect.equality(ast.object.type, 'member')
  expect.equality(ast.object.property, 'c')
end

-- =======================
-- Method Calls
-- =======================

T['parse_expression']['method call no arguments'] = function()
  local ast, err = parser.parse_expression('name.lower()')
  expect.equality(err, nil)
  expect.equality(ast.type, 'call')
  expect.equality(ast.callee.type, 'member')
  expect.equality(ast.callee.object.name, 'name')
  expect.equality(ast.callee.property, 'lower')
  expect.equality(#ast.args, 0)
end

T['parse_expression']['method call with one argument'] = function()
  local ast, err = parser.parse_expression('name.contains("test")')
  expect.equality(err, nil)
  expect.equality(ast.type, 'call')
  expect.equality(ast.callee.type, 'member')
  expect.equality(ast.callee.property, 'contains')
  expect.equality(#ast.args, 1)
  expect.equality(ast.args[1].type, 'literal')
  expect.equality(ast.args[1].value, 'test')
end

T['parse_expression']['method call with multiple arguments'] = function()
  local ast, err = parser.parse_expression('str.replace("old", "new")')
  expect.equality(err, nil)
  expect.equality(ast.type, 'call')
  expect.equality(#ast.args, 2)
  expect.equality(ast.args[1].value, 'old')
  expect.equality(ast.args[2].value, 'new')
end

T['parse_expression']['chained method calls'] = function()
  local ast, err = parser.parse_expression('name.lower().trim()')
  expect.equality(err, nil)
  expect.equality(ast.type, 'call')
  expect.equality(ast.callee.type, 'member')
  expect.equality(ast.callee.property, 'trim')
  expect.equality(ast.callee.object.type, 'call')
  expect.equality(ast.callee.object.callee.property, 'lower')
end

-- =======================
-- Index Access
-- =======================

T['parse_expression']['array index with number'] = function()
  local ast, err = parser.parse_expression('tags[0]')
  expect.equality(err, nil)
  expect.equality(ast.type, 'index')
  expect.equality(ast.object.type, 'identifier')
  expect.equality(ast.object.name, 'tags')
  expect.equality(ast.index.type, 'literal')
  expect.equality(ast.index.value, 0)
end

T['parse_expression']['array index with expression'] = function()
  local ast, err = parser.parse_expression('arr[i + 1]')
  expect.equality(err, nil)
  expect.equality(ast.type, 'index')
  expect.equality(ast.index.type, 'binary_op')
  expect.equality(ast.index.operator, '+')
end

T['parse_expression']['chained index access'] = function()
  local ast, err = parser.parse_expression('matrix[0][1]')
  expect.equality(err, nil)
  expect.equality(ast.type, 'index')
  expect.equality(ast.index.value, 1)
  expect.equality(ast.object.type, 'index')
  expect.equality(ast.object.index.value, 0)
end

T['parse_expression']['member access after index'] = function()
  local ast, err = parser.parse_expression('items[0].name')
  expect.equality(err, nil)
  expect.equality(ast.type, 'member')
  expect.equality(ast.property, 'name')
  expect.equality(ast.object.type, 'index')
  expect.equality(ast.object.object.name, 'items')
end

-- =======================
-- Function Calls
-- =======================

T['parse_expression']['function call no arguments'] = function()
  local ast, err = parser.parse_expression('today()')
  expect.equality(err, nil)
  expect.equality(ast.type, 'call')
  expect.equality(ast.callee.type, 'identifier')
  expect.equality(ast.callee.name, 'today')
  expect.equality(#ast.args, 0)
end

T['parse_expression']['function call with one argument'] = function()
  local ast, err = parser.parse_expression('date("2025-01-01")')
  expect.equality(err, nil)
  expect.equality(ast.type, 'call')
  expect.equality(ast.callee.name, 'date')
  expect.equality(#ast.args, 1)
  expect.equality(ast.args[1].value, '2025-01-01')
end

T['parse_expression']['function call with multiple arguments'] = function()
  local ast, err = parser.parse_expression('func(a, b, c)')
  expect.equality(err, nil)
  expect.equality(ast.type, 'call')
  expect.equality(#ast.args, 3)
  expect.equality(ast.args[1].name, 'a')
  expect.equality(ast.args[2].name, 'b')
  expect.equality(ast.args[3].name, 'c')
end

T['parse_expression']['function call with expression arguments'] = function()
  local ast, err = parser.parse_expression('max(a + 1, b * 2)')
  expect.equality(err, nil)
  expect.equality(#ast.args, 2)
  expect.equality(ast.args[1].type, 'binary_op')
  expect.equality(ast.args[1].operator, '+')
  expect.equality(ast.args[2].type, 'binary_op')
  expect.equality(ast.args[2].operator, '*')
end

T['parse_expression']['nested function calls'] = function()
  local ast, err = parser.parse_expression('outer(inner(x))')
  expect.equality(err, nil)
  expect.equality(ast.type, 'call')
  expect.equality(ast.callee.name, 'outer')
  expect.equality(ast.args[1].type, 'call')
  expect.equality(ast.args[1].callee.name, 'inner')
end

-- =======================
-- Array Literals
-- =======================

T['parse_expression']['empty array'] = function()
  local ast, err = parser.parse_expression('[]')
  expect.equality(err, nil)
  expect.equality(ast.type, 'array')
  expect.equality(#ast.elements, 0)
end

T['parse_expression']['array with one element'] = function()
  local ast, err = parser.parse_expression('[1]')
  expect.equality(err, nil)
  expect.equality(ast.type, 'array')
  expect.equality(#ast.elements, 1)
  expect.equality(ast.elements[1].value, 1)
end

T['parse_expression']['array with multiple elements'] = function()
  local ast, err = parser.parse_expression('[1, 2, 3]')
  expect.equality(err, nil)
  expect.equality(ast.type, 'array')
  expect.equality(#ast.elements, 3)
  expect.equality(ast.elements[1].value, 1)
  expect.equality(ast.elements[2].value, 2)
  expect.equality(ast.elements[3].value, 3)
end

T['parse_expression']['array with mixed types'] = function()
  local ast, err = parser.parse_expression('[1, "text", true]')
  expect.equality(err, nil)
  expect.equality(#ast.elements, 3)
  expect.equality(ast.elements[1].datatype, 'number')
  expect.equality(ast.elements[2].datatype, 'string')
  expect.equality(ast.elements[3].datatype, 'boolean')
end

T['parse_expression']['array with expressions'] = function()
  local ast, err = parser.parse_expression('[a + 1, b * 2]')
  expect.equality(err, nil)
  expect.equality(#ast.elements, 2)
  expect.equality(ast.elements[1].type, 'binary_op')
  expect.equality(ast.elements[2].type, 'binary_op')
end

T['parse_expression']['nested arrays'] = function()
  local ast, err = parser.parse_expression('[[1, 2], [3, 4]]')
  expect.equality(err, nil)
  expect.equality(ast.type, 'array')
  expect.equality(#ast.elements, 2)
  expect.equality(ast.elements[1].type, 'array')
  expect.equality(ast.elements[2].type, 'array')
  expect.equality(#ast.elements[1].elements, 2)
end

-- =======================
-- Object Literals
-- =======================

T['parse_expression']['empty object'] = function()
  local ast, err = parser.parse_expression('{}')
  expect.equality(err, nil)
  expect.equality(ast.type, 'object')
  expect.equality(#ast.entries, 0)
end

T['parse_expression']['object with one property'] = function()
  local ast, err = parser.parse_expression('{a: 1}')
  expect.equality(err, nil)
  expect.equality(ast.type, 'object')
  expect.equality(#ast.entries, 1)
  expect.equality(ast.entries[1].key, 'a')
  expect.equality(ast.entries[1].value.value, 1)
end

T['parse_expression']['object with multiple properties'] = function()
  local ast, err = parser.parse_expression('{a: 1, b: 2}')
  expect.equality(err, nil)
  expect.equality(#ast.entries, 2)
  expect.equality(ast.entries[1].key, 'a')
  expect.equality(ast.entries[1].value.value, 1)
  expect.equality(ast.entries[2].key, 'b')
  expect.equality(ast.entries[2].value.value, 2)
end

T['parse_expression']['object with string keys'] = function()
  local ast, err = parser.parse_expression('{"key-name": "value"}')
  expect.equality(err, nil)
  expect.equality(#ast.entries, 1)
  expect.equality(ast.entries[1].key, 'key-name')
  expect.equality(ast.entries[1].value.value, 'value')
end

T['parse_expression']['object with expression values'] = function()
  local ast, err = parser.parse_expression('{a: x + 1, b: y * 2}')
  expect.equality(err, nil)
  expect.equality(ast.entries[1].value.type, 'binary_op')
  expect.equality(ast.entries[2].value.type, 'binary_op')
end

T['parse_expression']['nested objects'] = function()
  local ast, err = parser.parse_expression('{a: {b: 1}}')
  expect.equality(err, nil)
  expect.equality(ast.type, 'object')
  expect.equality(ast.entries[1].key, 'a')
  expect.equality(ast.entries[1].value.type, 'object')
  expect.equality(ast.entries[1].value.entries[1].key, 'b')
end

-- =======================
-- Parenthesized Grouping
-- =======================

T['parse_expression']['simple parentheses'] = function()
  local ast, err = parser.parse_expression('(x)')
  expect.equality(err, nil)
  expect.equality(ast.type, 'identifier')
  expect.equality(ast.name, 'x')
end

T['parse_expression']['parentheses override precedence'] = function()
  -- (a + b) * c should parse as (a + b) * c, not a + (b * c)
  local ast, err = parser.parse_expression('(a + b) * c')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '*')
  expect.equality(ast.left.type, 'binary_op')
  expect.equality(ast.left.operator, '+')
  expect.equality(ast.right.name, 'c')
end

T['parse_expression']['nested parentheses'] = function()
  local ast, err = parser.parse_expression('((x))')
  expect.equality(err, nil)
  expect.equality(ast.type, 'identifier')
  expect.equality(ast.name, 'x')
end

T['parse_expression']['complex grouping'] = function()
  local ast, err = parser.parse_expression('(a + b) * (c - d)')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '*')
  expect.equality(ast.left.type, 'binary_op')
  expect.equality(ast.left.operator, '+')
  expect.equality(ast.right.type, 'binary_op')
  expect.equality(ast.right.operator, '-')
end

-- =======================
-- Complex Expressions
-- =======================

T['parse_expression']['filter expression'] = function()
  local ast, err = parser.parse_expression('note.status == "active" && file.hasTag("project")')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '&&')
  expect.equality(ast.left.type, 'binary_op')
  expect.equality(ast.left.operator, '==')
  expect.equality(ast.right.type, 'call')
end

T['parse_expression']['formula expression'] = function()
  local ast, err = parser.parse_expression('note.budget * 1.2 + 100')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '+')
  expect.equality(ast.left.type, 'binary_op')
  expect.equality(ast.left.operator, '*')
end

T['parse_expression']['date comparison'] = function()
  local ast, err = parser.parse_expression('note.due < today()')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '<')
  expect.equality(ast.left.type, 'member')
  expect.equality(ast.right.type, 'call')
end

T['parse_expression']['array filter pattern'] = function()
  local ast, err = parser.parse_expression('tags[0] == "urgent"')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '==')
  expect.equality(ast.left.type, 'index')
end

T['parse_expression']['multiple conditions'] = function()
  local ast, err = parser.parse_expression('a > 5 && b < 10 || c == 3')
  expect.equality(err, nil)
  expect.equality(ast.type, 'binary_op')
  expect.equality(ast.operator, '||')
  expect.equality(ast.left.type, 'binary_op')
  expect.equality(ast.left.operator, '&&')
end

-- =======================
-- Error Cases
-- =======================

T['parse_expression']['unexpected EOF after operator'] = function()
  local ast, err = parser.parse_expression('a +')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected token', 1, true), nil)
end

T['parse_expression']['missing closing parenthesis'] = function()
  local ast, err = parser.parse_expression('(a + b')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find("Expected ')'", 1, true), nil)
end

T['parse_expression']['missing closing bracket'] = function()
  local ast, err = parser.parse_expression('[1, 2')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find("Expected ']'", 1, true), nil)
end

T['parse_expression']['missing closing brace'] = function()
  local ast, err = parser.parse_expression('{a: 1')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find("Expected '}'", 1, true), nil)
end

T['parse_expression']['trailing tokens'] = function()
  local ast, err = parser.parse_expression('42 43')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected token', 1, true), nil)
end

T['parse_expression']['empty input'] = function()
  local ast, err = parser.parse_expression('')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected token', 1, true), nil)
end

T['parse_expression']['missing expression after unary'] = function()
  local ast, err = parser.parse_expression('!')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected token', 1, true), nil)
end

T['parse_expression']['missing index expression'] = function()
  local ast, err = parser.parse_expression('arr[]')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected token', 1, true), nil)
end

T['parse_expression']['missing property name after dot'] = function()
  local ast, err = parser.parse_expression('file.')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find("Expected property name after '.'", 1, true), nil)
end

T['parse_expression']['missing colon in object'] = function()
  local ast, err = parser.parse_expression('{a 1}')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find("Expected ':'", 1, true), nil)
end

T['parse_expression']['invalid object key'] = function()
  local ast, err = parser.parse_expression('{123: "value"}')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Expected property key', 1, true), nil)
end

T['parse_expression']['missing argument after comma'] = function()
  local ast, err = parser.parse_expression('func(a,)')
  expect.equality(ast, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected token', 1, true), nil)
end

return T
