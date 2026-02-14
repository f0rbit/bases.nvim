local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()
local parser = require("bases.engine.expr.parser")

local function parse(expr)
  local ast, err = parser.parse_expression(expr)
  assert(ast, "parse failed: " .. (err or "unknown"))
  return ast
end

-- Literals

T["parse number literal"] = function()
  local ast = parse("42")
  expect.equality(ast.type, "literal")
  expect.equality(ast.datatype, "number")
  expect.equality(ast.value, 42)
end

T["parse string literal"] = function()
  local ast = parse('"hello"')
  expect.equality(ast.type, "literal")
  expect.equality(ast.datatype, "string")
  expect.equality(ast.value, "hello")
end

T["parse boolean literal true"] = function()
  local ast = parse("true")
  expect.equality(ast.type, "literal")
  expect.equality(ast.datatype, "boolean")
  expect.equality(ast.value, true)
end

T["parse boolean literal false"] = function()
  local ast = parse("false")
  expect.equality(ast.type, "literal")
  expect.equality(ast.datatype, "boolean")
  expect.equality(ast.value, false)
end

T["parse regex literal"] = function()
  local ast = parse("/test/g")
  expect.equality(ast.type, "literal")
  expect.equality(ast.datatype, "regex")
  expect.equality(ast.value.pattern, "test")
  expect.equality(ast.value.flags, "g")
end

-- Identifiers

T["parse identifier"] = function()
  local ast = parse("name")
  expect.equality(ast.type, "identifier")
  expect.equality(ast.name, "name")
end

-- Binary operators

T["parse addition"] = function()
  local ast = parse("1 + 2")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "+")
  expect.equality(ast.left.type, "literal")
  expect.equality(ast.left.value, 1)
  expect.equality(ast.right.type, "literal")
  expect.equality(ast.right.value, 2)
end

T["parse subtraction"] = function()
  local ast = parse("5 - 3")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "-")
end

T["parse multiplication"] = function()
  local ast = parse("4 * 2")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "*")
end

T["parse division"] = function()
  local ast = parse("8 / 4")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "/")
end

T["parse modulo"] = function()
  local ast = parse("7 % 3")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "%")
end

T["parse comparison =="] = function()
  local ast = parse("a == 5")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "==")
end

T["parse comparison !="] = function()
  local ast = parse("a != 5")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "!=")
end

T["parse comparison >"] = function()
  local ast = parse("a > 5")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, ">")
  expect.equality(ast.left.type, "identifier")
  expect.equality(ast.left.name, "a")
  expect.equality(ast.right.type, "literal")
  expect.equality(ast.right.value, 5)
end

T["parse comparison <"] = function()
  local ast = parse("a < 5")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "<")
end

T["parse comparison >="] = function()
  local ast = parse("a >= 5")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, ">=")
end

T["parse comparison <="] = function()
  local ast = parse("a <= 5")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "<=")
end

-- Logical operators

T["parse logical and"] = function()
  local ast = parse("a && b")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "&&")
end

T["parse logical or"] = function()
  local ast = parse("a || b")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "||")
end

-- Operator precedence

T["multiplication before addition"] = function()
  local ast = parse("1 + 2 * 3")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "+")
  expect.equality(ast.left.value, 1)
  expect.equality(ast.right.type, "binary_op")
  expect.equality(ast.right.operator, "*")
  expect.equality(ast.right.left.value, 2)
  expect.equality(ast.right.right.value, 3)
end

T["comparison before logical"] = function()
  local ast = parse("a > 1 && b < 2")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "&&")
  expect.equality(ast.left.type, "binary_op")
  expect.equality(ast.left.operator, ">")
  expect.equality(ast.right.type, "binary_op")
  expect.equality(ast.right.operator, "<")
end

T["or has lower precedence than and"] = function()
  local ast = parse("a || b && c")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "||")
  expect.equality(ast.right.type, "binary_op")
  expect.equality(ast.right.operator, "&&")
end

T["parentheses override precedence"] = function()
  local ast = parse("(1 + 2) * 3")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, "*")
  expect.equality(ast.left.type, "binary_op")
  expect.equality(ast.left.operator, "+")
  expect.equality(ast.right.value, 3)
end

-- Unary operators

T["parse unary not"] = function()
  local ast = parse("!a")
  expect.equality(ast.type, "unary_op")
  expect.equality(ast.operator, "!")
  expect.equality(ast.operand.type, "identifier")
  expect.equality(ast.operand.name, "a")
end

-- Function calls

T["parse function call no args"] = function()
  local ast = parse("now()")
  expect.equality(ast.type, "call")
  expect.equality(ast.callee.type, "identifier")
  expect.equality(ast.callee.name, "now")
  expect.equality(#ast.args, 0)
end

T["parse function call single arg"] = function()
  local ast = parse("length(name)")
  expect.equality(ast.type, "call")
  expect.equality(ast.callee.type, "identifier")
  expect.equality(ast.callee.name, "length")
  expect.equality(#ast.args, 1)
  expect.equality(ast.args[1].type, "identifier")
end

T["parse function call multiple args"] = function()
  local ast = parse('contains(name, "test")')
  expect.equality(ast.type, "call")
  expect.equality(ast.callee.name, "contains")
  expect.equality(#ast.args, 2)
  expect.equality(ast.args[1].type, "identifier")
  expect.equality(ast.args[2].type, "literal")
  expect.equality(ast.args[2].value, "test")
end

-- Method calls (member + call)

T["parse method call"] = function()
  local ast = parse('name.contains("test")')
  expect.equality(ast.type, "call")
  expect.equality(ast.callee.type, "member")
  expect.equality(ast.callee.object.type, "identifier")
  expect.equality(ast.callee.object.name, "name")
  expect.equality(ast.callee.property, "contains")
  expect.equality(#ast.args, 1)
end

T["parse method call no args"] = function()
  local ast = parse("name.length()")
  expect.equality(ast.type, "call")
  expect.equality(ast.callee.type, "member")
  expect.equality(ast.callee.property, "length")
  expect.equality(#ast.args, 0)
end

-- Member access

T["parse member access"] = function()
  local ast = parse("file.name")
  expect.equality(ast.type, "member")
  expect.equality(ast.object.type, "identifier")
  expect.equality(ast.object.name, "file")
  expect.equality(ast.property, "name")
end

-- Index access

T["parse index access"] = function()
  local ast = parse("items[0]")
  expect.equality(ast.type, "index")
  expect.equality(ast.object.type, "identifier")
  expect.equality(ast.index.type, "literal")
  expect.equality(ast.index.value, 0)
end

-- Array literal

T["parse array literal"] = function()
  local ast = parse("[1, 2, 3]")
  expect.equality(ast.type, "array")
  expect.equality(#ast.elements, 3)
  expect.equality(ast.elements[1].value, 1)
  expect.equality(ast.elements[2].value, 2)
  expect.equality(ast.elements[3].value, 3)
end

T["parse empty array"] = function()
  local ast = parse("[]")
  expect.equality(ast.type, "array")
  expect.equality(#ast.elements, 0)
end

-- Object literal

T["parse object literal"] = function()
  local ast = parse("{a: 1, b: 2}")
  expect.equality(ast.type, "object")
  expect.equality(#ast.entries, 2)
  expect.equality(ast.entries[1].key, "a")
  expect.equality(ast.entries[1].value.value, 1)
  expect.equality(ast.entries[2].key, "b")
  expect.equality(ast.entries[2].value.value, 2)
end

-- Nested expressions

T["parse nested function call in comparison"] = function()
  local ast = parse("length(name) > 5")
  expect.equality(ast.type, "binary_op")
  expect.equality(ast.operator, ">")
  expect.equality(ast.left.type, "call")
  expect.equality(ast.right.value, 5)
end

T["parse chained method calls"] = function()
  local ast = parse('name.toUpperCase().contains("A")')
  expect.equality(ast.type, "call")
  expect.equality(ast.callee.type, "member")
  expect.equality(ast.callee.property, "contains")
  expect.equality(ast.callee.object.type, "call")
end

-- Error handling

T["parse error on unexpected token"] = function()
  local ast, err = parser.parse_expression("1 + ")
  expect.equality(ast, nil)
  assert(err ~= nil)
end

T["parse error on extra tokens"] = function()
  local ast, err = parser.parse_expression("1 2")
  expect.equality(ast, nil)
  assert(err:find("Unexpected token"))
end

return T
