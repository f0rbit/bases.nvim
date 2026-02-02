---@class Token
---@field type string
---@field value any
---@field pos number

local M = {}

-- Token type constants
M.NUMBER = "NUMBER"
M.STRING = "STRING"
M.BOOLEAN = "BOOLEAN"
M.REGEX = "REGEX"
M.IDENTIFIER = "IDENTIFIER"
M.PLUS = "PLUS"
M.MINUS = "MINUS"
M.STAR = "STAR"
M.SLASH = "SLASH"
M.PERCENT = "PERCENT"
M.EQ = "EQ"
M.NEQ = "NEQ"
M.LT = "LT"
M.GT = "GT"
M.LTE = "LTE"
M.GTE = "GTE"
M.AND = "AND"
M.OR = "OR"
M.NOT = "NOT"
M.DOT = "DOT"
M.COMMA = "COMMA"
M.COLON = "COLON"
M.LPAREN = "LPAREN"
M.RPAREN = "RPAREN"
M.LBRACKET = "LBRACKET"
M.RBRACKET = "RBRACKET"
M.LBRACE = "LBRACE"
M.RBRACE = "RBRACE"
M.EOF = "EOF"

---Check if character is whitespace
---@param c string
---@return boolean
local function is_whitespace(c)
  return c == " " or c == "\t" or c == "\n" or c == "\r"
end

---Check if character is a letter or underscore
---@param c string
---@return boolean
local function is_alpha(c)
  return c:match("[a-zA-Z_]") ~= nil
end

---Check if character is a digit
---@param c string
---@return boolean
local function is_digit(c)
  return c:match("[0-9]") ~= nil
end

---Check if character is alphanumeric or underscore
---@param c string
---@return boolean
local function is_alnum(c)
  return c:match("[a-zA-Z0-9_]") ~= nil
end

---Tokenize source code into tokens
---@param source string
---@return Token[]?, string?
function M.tokenize(source)
  local tokens = {}
  local pos = 1
  local len = #source

  ---Look ahead at character without consuming
  ---@param offset? number
  ---@return string?
  local function peek(offset)
    offset = offset or 0
    local p = pos + offset
    if p > len then
      return nil
    end
    return source:sub(p, p)
  end

  ---Consume and return current character
  ---@return string?
  local function advance()
    if pos > len then
      return nil
    end
    local c = source:sub(pos, pos)
    pos = pos + 1
    return c
  end

  ---Add token to list
  ---@param type string
  ---@param value any
  ---@param token_pos number
  local function add_token(type, value, token_pos)
    table.insert(tokens, { type = type, value = value, pos = token_pos })
  end

  ---Check if previous token allows a regex literal to follow
  ---@return boolean
  local function can_start_regex()
    if #tokens == 0 then
      return true
    end
    local last = tokens[#tokens]
    return last.type == M.LPAREN
      or last.type == M.COMMA
      or last.type == M.EQ
      or last.type == M.NEQ
      or last.type == M.LT
      or last.type == M.GT
      or last.type == M.LTE
      or last.type == M.GTE
      or last.type == M.AND
      or last.type == M.OR
      or last.type == M.NOT
      or last.type == M.PLUS
      or last.type == M.MINUS
      or last.type == M.STAR
      or last.type == M.SLASH
      or last.type == M.PERCENT
  end

  ---Check if position allows arithmetic operator (surrounded by whitespace)
  ---@param current_pos number
  ---@return boolean
  local function allows_arithmetic_op(current_pos)
    -- Check character before
    local before_pos = current_pos - 1
    local before_is_space = before_pos < 1 or is_whitespace(source:sub(before_pos, before_pos))

    -- Check character after
    local after_pos = current_pos + 1
    local after_is_space = after_pos > len or is_whitespace(source:sub(after_pos, after_pos))

    return before_is_space and after_is_space
  end

  ---Check if minus can be unary (part of negative number)
  ---@return boolean
  local function can_be_unary_minus()
    if #tokens == 0 then
      return true
    end
    local last = tokens[#tokens]
    return last.type == M.LPAREN
      or last.type == M.COMMA
      or last.type == M.EQ
      or last.type == M.NEQ
      or last.type == M.LT
      or last.type == M.GT
      or last.type == M.LTE
      or last.type == M.GTE
      or last.type == M.AND
      or last.type == M.OR
      or last.type == M.NOT
      or last.type == M.PLUS
      or last.type == M.MINUS
      or last.type == M.STAR
      or last.type == M.SLASH
      or last.type == M.PERCENT
  end

  while pos <= len do
    local start_pos = pos
    local c = peek()

    if is_whitespace(c) then
      -- Skip whitespace
      advance()

    elseif c == "/" and peek(1) == "/" then
      -- Comments: // to end of line
      advance() -- consume first /
      advance() -- consume second /
      while peek() and peek() ~= "\n" do
        advance()
      end

    elseif c == '"' or c == "'" then
      -- String literals
      local quote = c
      advance() -- consume opening quote
      local value = ""

      while peek() and peek() ~= quote do
        local ch = peek()
        if ch == "\\" then
          advance()
          local escaped = peek()
          if escaped == "\\" then
            value = value .. "\\"
          elseif escaped == "n" then
            value = value .. "\n"
          elseif escaped == "r" then
            value = value .. "\r"
          elseif escaped == "t" then
            value = value .. "\t"
          elseif escaped == '"' then
            value = value .. '"'
          elseif escaped == "'" then
            value = value .. "'"
          else
            value = value .. (escaped or "")
          end
          advance()
        else
          value = value .. ch
          advance()
        end
      end

      if not peek() then
        return nil, string.format("Unterminated string at position %d", start_pos)
      end
      advance() -- consume closing quote
      add_token(M.STRING, value, start_pos)

    elseif is_digit(c) or (c == "-" and is_digit(peek(1) or "") and can_be_unary_minus()) then
      -- Numbers
      local num_str = ""

      -- Optional negative sign
      if c == "-" then
        num_str = "-"
        advance()
      end

      -- Integer part
      while peek() and is_digit(peek()) do
        num_str = num_str .. peek()
        advance()
      end

      -- Optional decimal part
      if peek() == "." and is_digit(peek(1) or "") then
        num_str = num_str .. "."
        advance()
        while peek() and is_digit(peek()) do
          num_str = num_str .. peek()
          advance()
        end
      end

      local num = tonumber(num_str)
      if not num then
        return nil, string.format("Invalid number '%s' at position %d", num_str, start_pos)
      end
      add_token(M.NUMBER, num, start_pos)

    elseif c == "/" and can_start_regex() then
      -- Regex literals: /pattern/flags
      advance() -- consume opening /
      local pattern = ""

      while peek() and peek() ~= "/" do
        local ch = peek()
        if ch == "\\" then
          pattern = pattern .. ch
          advance()
          if peek() then
            pattern = pattern .. peek()
            advance()
          end
        else
          pattern = pattern .. ch
          advance()
        end
      end

      if not peek() then
        return nil, string.format("Unterminated regex at position %d", start_pos)
      end
      advance() -- consume closing /

      -- Parse flags
      local flags = ""
      while peek() and peek() == "g" do
        flags = flags .. peek()
        advance()
      end

      add_token(M.REGEX, { pattern = pattern, flags = flags }, start_pos)

    -- Two-character operators
    elseif c == "=" and peek(1) == "=" then
      advance()
      advance()
      add_token(M.EQ, "==", start_pos)

    elseif c == "!" and peek(1) == "=" then
      advance()
      advance()
      add_token(M.NEQ, "!=", start_pos)

    elseif c == "<" and peek(1) == "=" then
      advance()
      advance()
      add_token(M.LTE, "<=", start_pos)

    elseif c == ">" and peek(1) == "=" then
      advance()
      advance()
      add_token(M.GTE, ">=", start_pos)

    elseif c == "&" and peek(1) == "&" then
      advance()
      advance()
      add_token(M.AND, "&&", start_pos)

    elseif c == "|" and peek(1) == "|" then
      advance()
      advance()
      add_token(M.OR, "||", start_pos)

    -- Arithmetic operators (must be space-surrounded)
    elseif c == "+" then
      if allows_arithmetic_op(pos) then
        advance()
        add_token(M.PLUS, "+", start_pos)
      else
        return nil, string.format("Arithmetic operator '+' must be surrounded by whitespace at position %d", pos)
      end

    elseif c == "-" then
      if allows_arithmetic_op(pos) then
        advance()
        add_token(M.MINUS, "-", start_pos)
      else
        return nil, string.format("Arithmetic operator '-' must be surrounded by whitespace at position %d", pos)
      end

    elseif c == "*" then
      if allows_arithmetic_op(pos) then
        advance()
        add_token(M.STAR, "*", start_pos)
      else
        return nil, string.format("Arithmetic operator '*' must be surrounded by whitespace at position %d", pos)
      end

    elseif c == "/" then
      if allows_arithmetic_op(pos) then
        advance()
        add_token(M.SLASH, "/", start_pos)
      else
        return nil, string.format("Arithmetic operator '/' must be surrounded by whitespace at position %d", pos)
      end

    elseif c == "%" then
      if allows_arithmetic_op(pos) then
        advance()
        add_token(M.PERCENT, "%", start_pos)
      else
        return nil, string.format("Arithmetic operator '%%' must be surrounded by whitespace at position %d", pos)
      end

    -- Single-character operators and delimiters
    elseif c == "<" then
      advance()
      add_token(M.LT, "<", start_pos)

    elseif c == ">" then
      advance()
      add_token(M.GT, ">", start_pos)

    elseif c == "!" then
      advance()
      add_token(M.NOT, "!", start_pos)

    elseif c == "." then
      advance()
      add_token(M.DOT, ".", start_pos)

    elseif c == "," then
      advance()
      add_token(M.COMMA, ",", start_pos)

    elseif c == ":" then
      advance()
      add_token(M.COLON, ":", start_pos)

    elseif c == "(" then
      advance()
      add_token(M.LPAREN, "(", start_pos)

    elseif c == ")" then
      advance()
      add_token(M.RPAREN, ")", start_pos)

    elseif c == "[" then
      advance()
      add_token(M.LBRACKET, "[", start_pos)

    elseif c == "]" then
      advance()
      add_token(M.RBRACKET, "]", start_pos)

    elseif c == "{" then
      advance()
      add_token(M.LBRACE, "{", start_pos)

    elseif c == "}" then
      advance()
      add_token(M.RBRACE, "}", start_pos)

    elseif is_alpha(c) then
      -- Identifiers and keywords
      local ident = ""
      while peek() and is_alnum(peek()) do
        ident = ident .. peek()
        advance()
      end

      -- Check for boolean keywords
      if ident == "true" then
        add_token(M.BOOLEAN, true, start_pos)
      elseif ident == "false" then
        add_token(M.BOOLEAN, false, start_pos)
      else
        add_token(M.IDENTIFIER, ident, start_pos)
      end

    else
      -- Unknown character
      return nil, string.format("Unexpected character '%s' at position %d", c, pos)
    end
  end

  -- Add EOF token
  add_token(M.EOF, nil, pos)
  return tokens, nil
end

return M
