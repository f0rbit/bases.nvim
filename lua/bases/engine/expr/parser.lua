---@class ASTNode
---@field type string
---@field value? any
---@field datatype? string
---@field name? string
---@field operator? string
---@field left? ASTNode
---@field right? ASTNode
---@field operand? ASTNode
---@field callee? ASTNode
---@field args? ASTNode[]
---@field object? ASTNode
---@field property? string
---@field index? ASTNode
---@field elements? ASTNode[]
---@field entries? {key: string, value: ASTNode}[]

local lexer = require("bases.engine.expr.lexer")

local M = {}

---Parser state
---@class Parser
---@field tokens Token[]
---@field current number
local Parser = {}
Parser.__index = Parser

---Create a new parser
---@param tokens Token[]
---@return Parser
function Parser.new(tokens)
  return setmetatable({
    tokens = tokens,
    current = 1,
  }, Parser)
end

---Get current token
---@return Token
function Parser:peek()
  return self.tokens[self.current]
end

---Get token at offset from current
---@param offset number
---@return Token?
function Parser:peek_ahead(offset)
  local index = self.current + offset
  if index > #self.tokens then
    return nil
  end
  return self.tokens[index]
end

---Check if current token matches type
---@param token_type string
---@return boolean
function Parser:check(token_type)
  return self:peek().type == token_type
end

---Consume current token and advance
---@return Token
function Parser:advance()
  local token = self.tokens[self.current]
  if token.type ~= lexer.EOF then
    self.current = self.current + 1
  end
  return token
end

---Consume token if it matches type, otherwise error
---@param token_type string
---@param message string
---@return Token?, string?
function Parser:expect(token_type, message)
  if self:check(token_type) then
    return self:advance(), nil
  end
  local current = self:peek()
  return nil, string.format("%s at position %d (got %s)", message, current.pos, current.type)
end

---Parse expression (entry point)
---@return ASTNode?, string?
function Parser:parse_expression()
  return self:parse_or()
end

---Parse logical OR expression
---@return ASTNode?, string?
function Parser:parse_or()
  local left, err = self:parse_and()
  if err then
    return nil, err
  end

  while self:check(lexer.OR) do
    local op_token = self:advance()
    local right, right_err = self:parse_and()
    if right_err then
      return nil, right_err
    end
    left = {
      type = "binary_op",
      operator = "||",
      left = left,
      right = right,
    }
  end

  return left, nil
end

---Parse logical AND expression
---@return ASTNode?, string?
function Parser:parse_and()
  local left, err = self:parse_equality()
  if err then
    return nil, err
  end

  while self:check(lexer.AND) do
    local op_token = self:advance()
    local right, right_err = self:parse_equality()
    if right_err then
      return nil, right_err
    end
    left = {
      type = "binary_op",
      operator = "&&",
      left = left,
      right = right,
    }
  end

  return left, nil
end

---Parse equality expression
---@return ASTNode?, string?
function Parser:parse_equality()
  local left, err = self:parse_relational()
  if err then
    return nil, err
  end

  while self:check(lexer.EQ) or self:check(lexer.NEQ) do
    local op_token = self:advance()
    local operator = op_token.value
    local right, right_err = self:parse_relational()
    if right_err then
      return nil, right_err
    end
    left = {
      type = "binary_op",
      operator = operator,
      left = left,
      right = right,
    }
  end

  return left, nil
end

---Parse relational expression
---@return ASTNode?, string?
function Parser:parse_relational()
  local left, err = self:parse_additive()
  if err then
    return nil, err
  end

  while self:check(lexer.LT) or self:check(lexer.GT) or self:check(lexer.LTE) or self:check(lexer.GTE) do
    local op_token = self:advance()
    local operator = op_token.value
    local right, right_err = self:parse_additive()
    if right_err then
      return nil, right_err
    end
    left = {
      type = "binary_op",
      operator = operator,
      left = left,
      right = right,
    }
  end

  return left, nil
end

---Parse additive expression
---@return ASTNode?, string?
function Parser:parse_additive()
  local left, err = self:parse_multiplicative()
  if err then
    return nil, err
  end

  while self:check(lexer.PLUS) or self:check(lexer.MINUS) do
    local op_token = self:advance()
    local operator = op_token.value
    local right, right_err = self:parse_multiplicative()
    if right_err then
      return nil, right_err
    end
    left = {
      type = "binary_op",
      operator = operator,
      left = left,
      right = right,
    }
  end

  return left, nil
end

---Parse multiplicative expression
---@return ASTNode?, string?
function Parser:parse_multiplicative()
  local left, err = self:parse_unary()
  if err then
    return nil, err
  end

  while self:check(lexer.STAR) or self:check(lexer.SLASH) or self:check(lexer.PERCENT) do
    local op_token = self:advance()
    local operator = op_token.value
    local right, right_err = self:parse_unary()
    if right_err then
      return nil, right_err
    end
    left = {
      type = "binary_op",
      operator = operator,
      left = left,
      right = right,
    }
  end

  return left, nil
end

---Parse unary expression
---@return ASTNode?, string?
function Parser:parse_unary()
  if self:check(lexer.NOT) or self:check(lexer.MINUS) then
    local op_token = self:advance()
    local operator = op_token.value
    local operand, err = self:parse_unary()
    if err then
      return nil, err
    end
    return {
      type = "unary_op",
      operator = operator,
      operand = operand,
    }, nil
  end

  return self:parse_postfix()
end

---Parse postfix expression (member access, calls, indexing)
---@return ASTNode?, string?
function Parser:parse_postfix()
  local expr, err = self:parse_primary()
  if err then
    return nil, err
  end

  while true do
    if self:check(lexer.DOT) then
      self:advance() -- consume .
      local prop_token, prop_err = self:expect(lexer.IDENTIFIER, "Expected property name after '.'")
      if prop_err then
        return nil, prop_err
      end

      expr = {
        type = "member",
        object = expr,
        property = prop_token.value,
      }

      -- Check if this is a method call
      if self:check(lexer.LPAREN) then
        local args, args_err = self:parse_args()
        if args_err then
          return nil, args_err
        end
        expr = {
          type = "call",
          callee = expr,
          args = args,
        }
      end
    elseif self:check(lexer.LBRACKET) then
      self:advance() -- consume [
      local index, index_err = self:parse_expression()
      if index_err then
        return nil, index_err
      end
      local _, bracket_err = self:expect(lexer.RBRACKET, "Expected ']' after index")
      if bracket_err then
        return nil, bracket_err
      end
      expr = {
        type = "index",
        object = expr,
        index = index,
      }
    elseif self:check(lexer.LPAREN) then
      local args, args_err = self:parse_args()
      if args_err then
        return nil, args_err
      end
      expr = {
        type = "call",
        callee = expr,
        args = args,
      }
    else
      break
    end
  end

  return expr, nil
end

---Parse function arguments
---@return ASTNode[]?, string?
function Parser:parse_args()
  local _, lparen_err = self:expect(lexer.LPAREN, "Expected '('")
  if lparen_err then
    return nil, lparen_err
  end

  local args = {}

  if not self:check(lexer.RPAREN) then
    while true do
      local arg, arg_err = self:parse_expression()
      if arg_err then
        return nil, arg_err
      end
      table.insert(args, arg)

      if not self:check(lexer.COMMA) then
        break
      end
      self:advance() -- consume comma
    end
  end

  local _, rparen_err = self:expect(lexer.RPAREN, "Expected ')' after arguments")
  if rparen_err then
    return nil, rparen_err
  end

  return args, nil
end

---Parse primary expression
---@return ASTNode?, string?
function Parser:parse_primary()
  local token = self:peek()

  -- Number literal
  if self:check(lexer.NUMBER) then
    self:advance()
    return {
      type = "literal",
      value = token.value,
      datatype = "number",
    }, nil
  end

  -- String literal
  if self:check(lexer.STRING) then
    self:advance()
    return {
      type = "literal",
      value = token.value,
      datatype = "string",
    }, nil
  end

  -- Boolean literal
  if self:check(lexer.BOOLEAN) then
    self:advance()
    return {
      type = "literal",
      value = token.value,
      datatype = "boolean",
    }, nil
  end

  -- Regex literal
  if self:check(lexer.REGEX) then
    self:advance()
    return {
      type = "literal",
      value = token.value,
      datatype = "regex",
    }, nil
  end

  -- Identifier
  if self:check(lexer.IDENTIFIER) then
    self:advance()
    return {
      type = "identifier",
      name = token.value,
    }, nil
  end

  -- Parenthesized expression
  if self:check(lexer.LPAREN) then
    self:advance() -- consume (
    local expr, expr_err = self:parse_expression()
    if expr_err then
      return nil, expr_err
    end
    local _, rparen_err = self:expect(lexer.RPAREN, "Expected ')' after expression")
    if rparen_err then
      return nil, rparen_err
    end
    return expr, nil
  end

  -- Array literal
  if self:check(lexer.LBRACKET) then
    self:advance() -- consume [
    local elements = {}

    if not self:check(lexer.RBRACKET) then
      while true do
        local elem, elem_err = self:parse_expression()
        if elem_err then
          return nil, elem_err
        end
        table.insert(elements, elem)

        if not self:check(lexer.COMMA) then
          break
        end
        self:advance() -- consume comma
      end
    end

    local _, rbracket_err = self:expect(lexer.RBRACKET, "Expected ']' after array elements")
    if rbracket_err then
      return nil, rbracket_err
    end

    return {
      type = "array",
      elements = elements,
    }, nil
  end

  -- Object literal
  if self:check(lexer.LBRACE) then
    self:advance() -- consume {
    local entries = {}

    if not self:check(lexer.RBRACE) then
      while true do
        -- Parse key (must be identifier or string)
        local key
        if self:check(lexer.IDENTIFIER) then
          key = self:advance().value
        elseif self:check(lexer.STRING) then
          key = self:advance().value
        else
          return nil, string.format("Expected property key at position %d", self:peek().pos)
        end

        -- Expect colon
        local _, colon_err = self:expect(lexer.COLON, "Expected ':' after property key")
        if colon_err then
          return nil, colon_err
        end

        -- Parse value
        local value, value_err = self:parse_expression()
        if value_err then
          return nil, value_err
        end

        table.insert(entries, { key = key, value = value })

        if not self:check(lexer.COMMA) then
          break
        end
        self:advance() -- consume comma
      end
    end

    local _, rbrace_err = self:expect(lexer.RBRACE, "Expected '}' after object entries")
    if rbrace_err then
      return nil, rbrace_err
    end

    return {
      type = "object",
      entries = entries,
    }, nil
  end

  return nil, string.format("Unexpected token %s at position %d", token.type, token.pos)
end

---Parse tokens into an AST
---@param tokens Token[]
---@return ASTNode?, string?
function M.parse(tokens)
  local parser = Parser.new(tokens)
  local ast, err = parser:parse_expression()
  if err then
    return nil, err
  end

  -- Ensure we've consumed all tokens (except EOF)
  if not parser:check(lexer.EOF) then
    local unexpected = parser:peek()
    return nil, string.format("Unexpected token %s at position %d", unexpected.type, unexpected.pos)
  end

  return ast, nil
end

---Convenience function to parse an expression string
---@param source string
---@return ASTNode?, string?
function M.parse_expression(source)
  local tokens, lex_err = lexer.tokenize(source)
  if lex_err then
    return nil, lex_err
  end

  return M.parse(tokens)
end

return M
