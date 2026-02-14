-- bases.nvim — Health check
-- :checkhealth bases
local M = {}

function M.check()
  vim.health.start("bases.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10")
  else
    vim.health.error("Neovim >= 0.10 required (for vim.uv, extmarks features)")
  end

  -- Check vault path configured
  local config = require("bases").config
  if config.vault_path then
    vim.health.ok("vault_path: " .. config.vault_path)

    -- Check vault exists
    local stat = vim.uv.fs_stat(config.vault_path)
    if stat and stat.type == "directory" then
      vim.health.ok("vault directory exists")
    else
      vim.health.error("vault directory not found: " .. config.vault_path)
    end
  else
    vim.health.warn("vault_path not configured (call require('bases').setup())")
  end

  -- Check engine loads
  local ok, err = pcall(require, "bases.engine")
  if ok then
    vim.health.ok("engine module loads")
  else
    vim.health.error("engine module failed to load: " .. tostring(err))
  end

  -- Check expression engine
  local ok2, err2 = pcall(function()
    local lexer = require("bases.engine.expr.lexer")
    local parser = require("bases.engine.expr.parser")
    local tokens = lexer.tokenize("1 + 2")
    parser.parse(tokens)
  end)
  if ok2 then
    vim.health.ok("expression engine works (lexer → parser pipeline)")
  else
    vim.health.error("expression engine failed: " .. tostring(err2))
  end
end

return M
