local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()
local lexer = require("bases.engine.expr.lexer")

local function tokenize(src)
  local tokens, err = lexer.tokenize(src)
  assert(tokens, "tokenize failed: " .. (err or "unknown"))
  return tokens
end

-- Numbers

T["tokenize integer"] = function()
  local tokens = tokenize("42")
  expect.equality(tokens[1].type, "NUMBER")
  expect.equality(tokens[1].value, 42)
  expect.equality(tokens[2].type, "EOF")
end

T["tokenize decimal"] = function()
  local tokens = tokenize("3.14")
  expect.equality(tokens[1].type, "NUMBER")
  expect.equality(tokens[1].value, 3.14)
end

T["tokenize negative number"] = function()
  local tokens = tokenize("-7")
  expect.equality(tokens[1].type, "NUMBER")
  expect.equality(tokens[1].value, -7)
end

T["tokenize negative decimal"] = function()
  local tokens = tokenize("-0.5")
  expect.equality(tokens[1].type, "NUMBER")
  expect.equality(tokens[1].value, -0.5)
end

-- Strings

T["tokenize double-quoted string"] = function()
  local tokens = tokenize('"hello"')
  expect.equality(tokens[1].type, "STRING")
  expect.equality(tokens[1].value, "hello")
end

T["tokenize single-quoted string"] = function()
  local tokens = tokenize("'world'")
  expect.equality(tokens[1].type, "STRING")
  expect.equality(tokens[1].value, "world")
end

T["tokenize empty string"] = function()
  local tokens = tokenize('""')
  expect.equality(tokens[1].type, "STRING")
  expect.equality(tokens[1].value, "")
end

T["tokenize string with escape sequences"] = function()
  local tokens = tokenize('"line1\\nline2"')
  expect.equality(tokens[1].type, "STRING")
  expect.equality(tokens[1].value, "line1\nline2")
end

T["tokenize string with escaped quotes"] = function()
  local tokens = tokenize('"say \\"hi\\""')
  expect.equality(tokens[1].type, "STRING")
  expect.equality(tokens[1].value, 'say "hi"')
end

T["unterminated string returns error"] = function()
  local tokens, err = lexer.tokenize('"oops')
  expect.equality(tokens, nil)
  assert(err:find("Unterminated string"))
end

-- Booleans

T["tokenize true"] = function()
  local tokens = tokenize("true")
  expect.equality(tokens[1].type, "BOOLEAN")
  expect.equality(tokens[1].value, true)
end

T["tokenize false"] = function()
  local tokens = tokenize("false")
  expect.equality(tokens[1].type, "BOOLEAN")
  expect.equality(tokens[1].value, false)
end

-- Identifiers

T["tokenize identifier"] = function()
  local tokens = tokenize("name")
  expect.equality(tokens[1].type, "IDENTIFIER")
  expect.equality(tokens[1].value, "name")
end

T["tokenize identifier with underscore"] = function()
  local tokens = tokenize("my_var")
  expect.equality(tokens[1].type, "IDENTIFIER")
  expect.equality(tokens[1].value, "my_var")
end

T["tokenize identifier with digits"] = function()
  local tokens = tokenize("item2")
  expect.equality(tokens[1].type, "IDENTIFIER")
  expect.equality(tokens[1].value, "item2")
end

-- Operators

T["tokenize arithmetic with spaces"] = function()
  local tokens = tokenize("1 + 2 * 3")
  expect.equality(tokens[1].type, "NUMBER")
  expect.equality(tokens[1].value, 1)
  expect.equality(tokens[2].type, "PLUS")
  expect.equality(tokens[2].value, "+")
  expect.equality(tokens[3].type, "NUMBER")
  expect.equality(tokens[3].value, 2)
  expect.equality(tokens[4].type, "STAR")
  expect.equality(tokens[4].value, "*")
  expect.equality(tokens[5].type, "NUMBER")
  expect.equality(tokens[5].value, 3)
end

T["tokenize comparison =="] = function()
  local tokens = tokenize("a == b")
  expect.equality(tokens[1].type, "IDENTIFIER")
  expect.equality(tokens[2].type, "EQ")
  expect.equality(tokens[2].value, "==")
  expect.equality(tokens[3].type, "IDENTIFIER")
end

T["tokenize comparison !="] = function()
  local tokens = tokenize("a != b")
  expect.equality(tokens[2].type, "NEQ")
  expect.equality(tokens[2].value, "!=")
end

T["tokenize comparison <"] = function()
  local tokens = tokenize("a < b")
  expect.equality(tokens[2].type, "LT")
end

T["tokenize comparison >"] = function()
  local tokens = tokenize("a > b")
  expect.equality(tokens[2].type, "GT")
end

T["tokenize comparison <="] = function()
  local tokens = tokenize("a <= b")
  expect.equality(tokens[2].type, "LTE")
end

T["tokenize comparison >="] = function()
  local tokens = tokenize("a >= b")
  expect.equality(tokens[2].type, "GTE")
end

T["tokenize logical &&"] = function()
  local tokens = tokenize("a && b")
  expect.equality(tokens[2].type, "AND")
  expect.equality(tokens[2].value, "&&")
end

T["tokenize logical ||"] = function()
  local tokens = tokenize("a || b")
  expect.equality(tokens[2].type, "OR")
  expect.equality(tokens[2].value, "||")
end

T["tokenize not !"] = function()
  local tokens = tokenize("!a")
  expect.equality(tokens[1].type, "NOT")
  expect.equality(tokens[1].value, "!")
end

-- Delimiters

T["tokenize parentheses"] = function()
  local tokens = tokenize("(a)")
  expect.equality(tokens[1].type, "LPAREN")
  expect.equality(tokens[2].type, "IDENTIFIER")
  expect.equality(tokens[3].type, "RPAREN")
end

T["tokenize brackets"] = function()
  local tokens = tokenize("[1, 2]")
  expect.equality(tokens[1].type, "LBRACKET")
  expect.equality(tokens[2].type, "NUMBER")
  expect.equality(tokens[3].type, "COMMA")
  expect.equality(tokens[4].type, "NUMBER")
  expect.equality(tokens[5].type, "RBRACKET")
end

T["tokenize braces"] = function()
  local tokens = tokenize("{a: 1}")
  expect.equality(tokens[1].type, "LBRACE")
  expect.equality(tokens[2].type, "IDENTIFIER")
  expect.equality(tokens[3].type, "COLON")
  expect.equality(tokens[4].type, "NUMBER")
  expect.equality(tokens[5].type, "RBRACE")
end

T["tokenize dot"] = function()
  local tokens = tokenize("a.b")
  expect.equality(tokens[1].type, "IDENTIFIER")
  expect.equality(tokens[2].type, "DOT")
  expect.equality(tokens[3].type, "IDENTIFIER")
end

-- Function call pattern

T["tokenize function call"] = function()
  local tokens = tokenize('contains(name, "test")')
  expect.equality(tokens[1].type, "IDENTIFIER")
  expect.equality(tokens[1].value, "contains")
  expect.equality(tokens[2].type, "LPAREN")
  expect.equality(tokens[3].type, "IDENTIFIER")
  expect.equality(tokens[3].value, "name")
  expect.equality(tokens[4].type, "COMMA")
  expect.equality(tokens[5].type, "STRING")
  expect.equality(tokens[5].value, "test")
  expect.equality(tokens[6].type, "RPAREN")
end

-- Regex

T["tokenize regex literal"] = function()
  local tokens = tokenize("/hello/")
  expect.equality(tokens[1].type, "REGEX")
  expect.equality(tokens[1].value.pattern, "hello")
  expect.equality(tokens[1].value.flags, "")
end

T["tokenize regex with flags"] = function()
  local tokens = tokenize("/test/g")
  expect.equality(tokens[1].type, "REGEX")
  expect.equality(tokens[1].value.pattern, "test")
  expect.equality(tokens[1].value.flags, "g")
end

-- Edge cases

T["tokenize empty input"] = function()
  local tokens = tokenize("")
  expect.equality(#tokens, 1)
  expect.equality(tokens[1].type, "EOF")
end

T["tokenize whitespace only"] = function()
  local tokens = tokenize("   ")
  expect.equality(#tokens, 1)
  expect.equality(tokens[1].type, "EOF")
end

T["token positions are tracked"] = function()
  local tokens = tokenize("a == b")
  expect.equality(tokens[1].pos, 1)
  expect.equality(tokens[2].pos, 3)
  expect.equality(tokens[3].pos, 6)
end

T["tokenize comment is skipped"] = function()
  local tokens = tokenize("a // this is a comment")
  expect.equality(tokens[1].type, "IDENTIFIER")
  expect.equality(tokens[1].value, "a")
  expect.equality(tokens[2].type, "EOF")
end

T["tokenize minus as operator between expressions"] = function()
  local tokens = tokenize("a - b")
  expect.equality(tokens[2].type, "MINUS")
end

T["unknown character returns error"] = function()
  local tokens, err = lexer.tokenize("@")
  expect.equality(tokens, nil)
  assert(err:find("Unexpected character"))
end

return T
