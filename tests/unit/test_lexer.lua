local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local lexer = require('bases.engine.expr.lexer')

local T = new_set()

-- Helper to get token types from result
local function token_types(tokens)
  local types = {}
  for _, t in ipairs(tokens) do
    table.insert(types, t.type)
  end
  return types
end

-- Helper to get token values (excluding EOF)
local function token_values(tokens)
  local values = {}
  for _, t in ipairs(tokens) do
    if t.type ~= lexer.EOF then
      table.insert(values, t.value)
    end
  end
  return values
end


T['tokenize'] = new_set()

-- =======================
-- Numeric Literals
-- =======================

T['tokenize']['integer'] = function()
  local tokens, err = lexer.tokenize('42')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[1].value, 42)
  expect.equality(tokens[2].type, lexer.EOF)
end

T['tokenize']['decimal'] = function()
  local tokens, err = lexer.tokenize('3.14')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[1].value, 3.14)
end

T['tokenize']['negative number at start'] = function()
  local tokens, err = lexer.tokenize('-5')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[1].value, -5)
end

T['tokenize']['negative decimal at start'] = function()
  local tokens, err = lexer.tokenize('-3.14')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[1].value, -3.14)
end

T['tokenize']['negative number after operator'] = function()
  local tokens, err = lexer.tokenize('( -5 )')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.LPAREN, lexer.NUMBER, lexer.RPAREN, lexer.EOF })
  expect.equality(tokens[2].value, -5)
end

T['tokenize']['negative number after comma'] = function()
  local tokens, err = lexer.tokenize('func(-5, -10)')
  expect.equality(err, nil)
  local types = token_types(tokens)
  expect.equality(types[1], lexer.IDENTIFIER)
  expect.equality(types[2], lexer.LPAREN)
  expect.equality(types[3], lexer.NUMBER)
  expect.equality(types[4], lexer.COMMA)
  expect.equality(types[5], lexer.NUMBER)
  expect.equality(tokens[3].value, -5)
  expect.equality(tokens[5].value, -10)
end

T['tokenize']['zero'] = function()
  local tokens, err = lexer.tokenize('0')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[1].value, 0)
end

-- =======================
-- String Literals
-- =======================

T['tokenize']['double-quoted string'] = function()
  local tokens, err = lexer.tokenize('"hello world"')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.STRING)
  expect.equality(tokens[1].value, 'hello world')
end

T['tokenize']['single-quoted string'] = function()
  local tokens, err = lexer.tokenize("'hello world'")
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.STRING)
  expect.equality(tokens[1].value, 'hello world')
end

T['tokenize']['empty string'] = function()
  local tokens, err = lexer.tokenize('""')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.STRING)
  expect.equality(tokens[1].value, '')
end

T['tokenize']['string with escape sequences'] = function()
  local tokens, err = lexer.tokenize('"line1\\nline2\\ttab\\r\\\\backslash\\"quote"')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.STRING)
  expect.equality(tokens[1].value, 'line1\nline2\ttab\r\\backslash"quote')
end

T['tokenize']['string with single quote escape'] = function()
  local tokens, err = lexer.tokenize("'can\\'t'")
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.STRING)
  expect.equality(tokens[1].value, "can't")
end

T['tokenize']['unterminated string double quote'] = function()
  local tokens, err = lexer.tokenize('"hello')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unterminated string', 1, true), nil)
end

T['tokenize']['unterminated string single quote'] = function()
  local tokens, err = lexer.tokenize("'hello")
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unterminated string', 1, true), nil)
end

-- =======================
-- Boolean Literals
-- =======================

T['tokenize']['boolean true'] = function()
  local tokens, err = lexer.tokenize('true')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.BOOLEAN)
  expect.equality(tokens[1].value, true)
end

T['tokenize']['boolean false'] = function()
  local tokens, err = lexer.tokenize('false')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.BOOLEAN)
  expect.equality(tokens[1].value, false)
end

-- =======================
-- Regex Literals
-- =======================

T['tokenize']['regex at start'] = function()
  local tokens, err = lexer.tokenize('/pattern/')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.REGEX)
  expect.equality(tokens[1].value.pattern, 'pattern')
  expect.equality(tokens[1].value.flags, '')
end

T['tokenize']['regex with flags'] = function()
  local tokens, err = lexer.tokenize('/pattern/g')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.REGEX)
  expect.equality(tokens[1].value.pattern, 'pattern')
  expect.equality(tokens[1].value.flags, 'g')
end

T['tokenize']['regex after operator'] = function()
  local tokens, err = lexer.tokenize('field == /pattern/')
  expect.equality(err, nil)
  expect.equality(tokens[3].type, lexer.REGEX)
  expect.equality(tokens[3].value.pattern, 'pattern')
end

T['tokenize']['regex after lparen'] = function()
  local tokens, err = lexer.tokenize('( /pattern/ )')
  expect.equality(err, nil)
  expect.equality(tokens[2].type, lexer.REGEX)
end

T['tokenize']['regex after comma'] = function()
  local tokens, err = lexer.tokenize('func(/pattern/, /other/)')
  expect.equality(err, nil)
  expect.equality(tokens[3].type, lexer.REGEX)
  expect.equality(tokens[5].type, lexer.REGEX)
end

T['tokenize']['regex with escape sequences'] = function()
  local tokens, err = lexer.tokenize('/pattern\\/with\\/slashes/')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.REGEX)
  expect.equality(tokens[1].value.pattern, 'pattern\\/with\\/slashes')
end

T['tokenize']['unterminated regex'] = function()
  local tokens, err = lexer.tokenize('/pattern')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unterminated regex', 1, true), nil)
end

-- =======================
-- Comparison Operators
-- =======================

T['tokenize']['operator =='] = function()
  local tokens, err = lexer.tokenize('==')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.EQ)
  expect.equality(tokens[1].value, '==')
end

T['tokenize']['operator !='] = function()
  local tokens, err = lexer.tokenize('!=')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NEQ)
  expect.equality(tokens[1].value, '!=')
end

T['tokenize']['operator <'] = function()
  local tokens, err = lexer.tokenize('<')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.LT)
  expect.equality(tokens[1].value, '<')
end

T['tokenize']['operator >'] = function()
  local tokens, err = lexer.tokenize('>')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.GT)
  expect.equality(tokens[1].value, '>')
end

T['tokenize']['operator <='] = function()
  local tokens, err = lexer.tokenize('<=')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.LTE)
  expect.equality(tokens[1].value, '<=')
end

T['tokenize']['operator >='] = function()
  local tokens, err = lexer.tokenize('>=')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.GTE)
  expect.equality(tokens[1].value, '>=')
end

-- =======================
-- Logical Operators
-- =======================

T['tokenize']['operator &&'] = function()
  local tokens, err = lexer.tokenize('&&')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.AND)
  expect.equality(tokens[1].value, '&&')
end

T['tokenize']['operator ||'] = function()
  local tokens, err = lexer.tokenize('||')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.OR)
  expect.equality(tokens[1].value, '||')
end

T['tokenize']['operator !'] = function()
  local tokens, err = lexer.tokenize('!')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NOT)
  expect.equality(tokens[1].value, '!')
end

-- =======================
-- Arithmetic Operators
-- =======================

T['tokenize']['operator + with whitespace'] = function()
  local tokens, err = lexer.tokenize('a + b')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.IDENTIFIER, lexer.PLUS, lexer.IDENTIFIER, lexer.EOF })
end

T['tokenize']['operator - with whitespace'] = function()
  local tokens, err = lexer.tokenize('a - b')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.IDENTIFIER, lexer.MINUS, lexer.IDENTIFIER, lexer.EOF })
end

T['tokenize']['operator * with whitespace'] = function()
  local tokens, err = lexer.tokenize('a * b')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.IDENTIFIER, lexer.STAR, lexer.IDENTIFIER, lexer.EOF })
end

T['tokenize']['operator / with whitespace'] = function()
  local tokens, err = lexer.tokenize('a / b')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.IDENTIFIER, lexer.SLASH, lexer.IDENTIFIER, lexer.EOF })
end

T['tokenize']['operator % with whitespace'] = function()
  local tokens, err = lexer.tokenize('a % b')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.IDENTIFIER, lexer.PERCENT, lexer.IDENTIFIER, lexer.EOF })
end

T['tokenize']['arithmetic operator + without whitespace fails'] = function()
  local tokens, err = lexer.tokenize('a+b')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('must be surrounded by whitespace', 1, true), nil)
end

T['tokenize']['arithmetic operator - without whitespace fails'] = function()
  local tokens, err = lexer.tokenize('a-b')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('must be surrounded by whitespace', 1, true), nil)
end

T['tokenize']['arithmetic operator * without whitespace fails'] = function()
  local tokens, err = lexer.tokenize('a*b')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('must be surrounded by whitespace', 1, true), nil)
end

T['tokenize']['arithmetic operator / without whitespace fails'] = function()
  local tokens, err = lexer.tokenize('a/b')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('must be surrounded by whitespace', 1, true), nil)
end

T['tokenize']['arithmetic operator % without whitespace fails'] = function()
  local tokens, err = lexer.tokenize('a%b')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('must be surrounded by whitespace', 1, true), nil)
end

T['tokenize']['operator + at start with whitespace'] = function()
  local tokens, err = lexer.tokenize(' + b')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.PLUS)
end

T['tokenize']['operator + at end with whitespace'] = function()
  local tokens, err = lexer.tokenize('a + ')
  expect.equality(err, nil)
  expect.equality(tokens[2].type, lexer.PLUS)
end

-- =======================
-- Delimiters
-- =======================

T['tokenize']['delimiter .'] = function()
  local tokens, err = lexer.tokenize('.')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.DOT)
end

T['tokenize']['delimiter ,'] = function()
  local tokens, err = lexer.tokenize(',')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.COMMA)
end

T['tokenize']['delimiter :'] = function()
  local tokens, err = lexer.tokenize(':')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.COLON)
end

T['tokenize']['delimiter ( )'] = function()
  local tokens, err = lexer.tokenize('( )')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.LPAREN, lexer.RPAREN, lexer.EOF })
end

T['tokenize']['delimiter [ ]'] = function()
  local tokens, err = lexer.tokenize('[ ]')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.LBRACKET, lexer.RBRACKET, lexer.EOF })
end

T['tokenize']['delimiter { }'] = function()
  local tokens, err = lexer.tokenize('{ }')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.LBRACE, lexer.RBRACE, lexer.EOF })
end

-- =======================
-- Identifiers
-- =======================

T['tokenize']['identifier simple'] = function()
  local tokens, err = lexer.tokenize('foo')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.IDENTIFIER)
  expect.equality(tokens[1].value, 'foo')
end

T['tokenize']['identifier with underscore'] = function()
  local tokens, err = lexer.tokenize('foo_bar')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.IDENTIFIER)
  expect.equality(tokens[1].value, 'foo_bar')
end

T['tokenize']['identifier starting with underscore'] = function()
  local tokens, err = lexer.tokenize('_private')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.IDENTIFIER)
  expect.equality(tokens[1].value, '_private')
end

T['tokenize']['identifier with numbers'] = function()
  local tokens, err = lexer.tokenize('var123')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.IDENTIFIER)
  expect.equality(tokens[1].value, 'var123')
end

T['tokenize']['identifier uppercase'] = function()
  local tokens, err = lexer.tokenize('FOO_BAR')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.IDENTIFIER)
  expect.equality(tokens[1].value, 'FOO_BAR')
end

-- =======================
-- Comments
-- =======================

T['tokenize']['single-line comment'] = function()
  local tokens, err = lexer.tokenize('// this is a comment')
  expect.equality(err, nil)
  expect.equality(#tokens, 1)
  expect.equality(tokens[1].type, lexer.EOF)
end

T['tokenize']['comment with code after'] = function()
  local tokens, err = lexer.tokenize('42 // comment\n43')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.NUMBER, lexer.NUMBER, lexer.EOF })
  expect.equality(tokens[1].value, 42)
  expect.equality(tokens[2].value, 43)
end

T['tokenize']['comment at end of line'] = function()
  local tokens, err = lexer.tokenize('foo // comment')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.IDENTIFIER)
  expect.equality(tokens[2].type, lexer.EOF)
end

-- =======================
-- Unary Minus Disambiguation
-- =======================

T['tokenize']['unary minus at start'] = function()
  local tokens, err = lexer.tokenize('-42')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[1].value, -42)
end

T['tokenize']['binary minus with spaces'] = function()
  local tokens, err = lexer.tokenize('5 - 3')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.NUMBER, lexer.MINUS, lexer.NUMBER, lexer.EOF })
  expect.equality(tokens[1].value, 5)
  expect.equality(tokens[3].value, 3)
end

T['tokenize']['unary minus after operator'] = function()
  local tokens, err = lexer.tokenize('5 + -3')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.NUMBER, lexer.PLUS, lexer.NUMBER, lexer.EOF })
  expect.equality(tokens[1].value, 5)
  expect.equality(tokens[3].value, -3)
end

T['tokenize']['unary minus in expression'] = function()
  local tokens, err = lexer.tokenize('( -5 )')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.LPAREN, lexer.NUMBER, lexer.RPAREN, lexer.EOF })
  expect.equality(tokens[2].value, -5)
end

-- =======================
-- Complex Expressions
-- =======================

T['tokenize']['field access'] = function()
  local tokens, err = lexer.tokenize('object.field')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.IDENTIFIER, lexer.DOT, lexer.IDENTIFIER, lexer.EOF })
end

T['tokenize']['function call'] = function()
  local tokens, err = lexer.tokenize('func(arg1, arg2)')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), {
    lexer.IDENTIFIER,
    lexer.LPAREN,
    lexer.IDENTIFIER,
    lexer.COMMA,
    lexer.IDENTIFIER,
    lexer.RPAREN,
    lexer.EOF,
  })
end

T['tokenize']['array indexing'] = function()
  local tokens, err = lexer.tokenize('arr[0]')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), {
    lexer.IDENTIFIER,
    lexer.LBRACKET,
    lexer.NUMBER,
    lexer.RBRACKET,
    lexer.EOF,
  })
end

T['tokenize']['complex boolean expression'] = function()
  local tokens, err = lexer.tokenize('a > 5 && b < 10 || c == 3')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), {
    lexer.IDENTIFIER,
    lexer.GT,
    lexer.NUMBER,
    lexer.AND,
    lexer.IDENTIFIER,
    lexer.LT,
    lexer.NUMBER,
    lexer.OR,
    lexer.IDENTIFIER,
    lexer.EQ,
    lexer.NUMBER,
    lexer.EOF,
  })
end

T['tokenize']['arithmetic expression'] = function()
  local tokens, err = lexer.tokenize('a + b * c - d / e % f')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), {
    lexer.IDENTIFIER,
    lexer.PLUS,
    lexer.IDENTIFIER,
    lexer.STAR,
    lexer.IDENTIFIER,
    lexer.MINUS,
    lexer.IDENTIFIER,
    lexer.SLASH,
    lexer.IDENTIFIER,
    lexer.PERCENT,
    lexer.IDENTIFIER,
    lexer.EOF,
  })
end

T['tokenize']['nested parentheses'] = function()
  local tokens, err = lexer.tokenize('((a))')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), {
    lexer.LPAREN,
    lexer.LPAREN,
    lexer.IDENTIFIER,
    lexer.RPAREN,
    lexer.RPAREN,
    lexer.EOF,
  })
end

T['tokenize']['object literal'] = function()
  local tokens, err = lexer.tokenize('{ key: value }')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), {
    lexer.LBRACE,
    lexer.IDENTIFIER,
    lexer.COLON,
    lexer.IDENTIFIER,
    lexer.RBRACE,
    lexer.EOF,
  })
end

T['tokenize']['mixed types'] = function()
  local tokens, err = lexer.tokenize('42, "string", true, false, /regex/')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), {
    lexer.NUMBER,
    lexer.COMMA,
    lexer.STRING,
    lexer.COMMA,
    lexer.BOOLEAN,
    lexer.COMMA,
    lexer.BOOLEAN,
    lexer.COMMA,
    lexer.REGEX,
    lexer.EOF,
  })
  expect.equality(tokens[1].value, 42)
  expect.equality(tokens[3].value, 'string')
  expect.equality(tokens[5].value, true)
  expect.equality(tokens[7].value, false)
end

-- =======================
-- Whitespace Handling
-- =======================

T['tokenize']['ignores leading whitespace'] = function()
  local tokens, err = lexer.tokenize('   42')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[1].value, 42)
end

T['tokenize']['ignores trailing whitespace'] = function()
  local tokens, err = lexer.tokenize('42   ')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[2].type, lexer.EOF)
end

T['tokenize']['ignores whitespace between tokens'] = function()
  local tokens, err = lexer.tokenize('a    +    b')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.IDENTIFIER, lexer.PLUS, lexer.IDENTIFIER, lexer.EOF })
end

T['tokenize']['handles tabs and newlines'] = function()
  local tokens, err = lexer.tokenize('a\t+\nb')
  expect.equality(err, nil)
  expect.equality(token_types(tokens), { lexer.IDENTIFIER, lexer.PLUS, lexer.IDENTIFIER, lexer.EOF })
end

-- =======================
-- Error Cases
-- =======================

T['tokenize']['unknown character @'] = function()
  local tokens, err = lexer.tokenize('@')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected character', 1, true), nil)
end

T['tokenize']['unknown character #'] = function()
  local tokens, err = lexer.tokenize('#')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected character', 1, true), nil)
end

T['tokenize']['single ampersand'] = function()
  local tokens, err = lexer.tokenize('&')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected character', 1, true), nil)
end

T['tokenize']['single pipe'] = function()
  local tokens, err = lexer.tokenize('|')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unexpected character', 1, true), nil)
end

-- =======================
-- Position Tracking
-- =======================

T['tokenize']['tracks position correctly'] = function()
  local tokens, err = lexer.tokenize('42 + 3')
  expect.equality(err, nil)
  expect.equality(tokens[1].pos, 1) -- 42 at position 1
  expect.equality(tokens[2].pos, 4) -- + at position 4
  expect.equality(tokens[3].pos, 6) -- 3 at position 6
end

T['tokenize']['position in error message'] = function()
  local tokens, err = lexer.tokenize('42 + a@b')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('position', 1, true), nil)
end

-- =======================
-- Edge Cases
-- =======================

T['tokenize']['empty string returns only EOF'] = function()
  local tokens, err = lexer.tokenize('')
  expect.equality(err, nil)
  expect.equality(#tokens, 1)
  expect.equality(tokens[1].type, lexer.EOF)
end

T['tokenize']['whitespace only returns only EOF'] = function()
  local tokens, err = lexer.tokenize('   \t\n  ')
  expect.equality(err, nil)
  expect.equality(#tokens, 1)
  expect.equality(tokens[1].type, lexer.EOF)
end

T['tokenize']['comment only returns only EOF'] = function()
  local tokens, err = lexer.tokenize('// just a comment')
  expect.equality(err, nil)
  expect.equality(#tokens, 1)
  expect.equality(tokens[1].type, lexer.EOF)
end

return T
