-- Health check module for bases.nvim
-- Run with :checkhealth bases

local M = {}

function M.check()
  -- 1. Neovim version
  vim.health.start("Neovim version")
  local v = vim.version()
  local ver_str = string.format("%d.%d.%d", v.major, v.minor, v.patch)
  if v.major > 0 or (v.major == 0 and v.minor >= 11) then
    vim.health.ok("Neovim " .. ver_str)
  else
    vim.health.error("Neovim 0.11+ required, found " .. ver_str)
  end

  -- 2. Required built-ins
  vim.health.start("Required built-ins")
  if type(vim.uv) == "table" then
    vim.health.ok("vim.uv available")
  else
    vim.health.error("vim.uv not available")
  end
  if type(vim.mpack) == "table" then
    vim.health.ok("vim.mpack available")
  else
    vim.health.error("vim.mpack not available")
  end

  -- 3. Configuration - vault_path
  vim.health.start("Configuration - vault_path")
  local vault_path = nil
  local ok, engine = pcall(require, "bases.engine")
  if ok and engine.get_vault_path then
    vault_path = engine.get_vault_path()
  end
  if not vault_path then
    local ok_config, bases = pcall(require, "bases")
    if ok_config and bases.get_config then
      local config = bases.get_config()
      if config then
        vault_path = config.vault_path
      end
    end
  end

  if not vault_path then
    vim.health.warn("vault_path not configured")
  else
    local stat = vim.uv.fs_stat(vault_path)
    if not stat then
      vim.health.error("vault_path does not exist: " .. vault_path)
    else
      vim.health.ok("vault_path: " .. vault_path)
    end
  end

  -- 4. Optional dependency - obsidian.nvim
  vim.health.start("Optional dependency - obsidian.nvim")
  if type(Obsidian) == "table" then
    vim.health.ok("obsidian.nvim detected")
  else
    vim.health.info("obsidian.nvim not found (optional - set vault_path explicitly)")
  end

  -- 5. Engine runtime state
  vim.health.start("Engine runtime state")
  if not ok then
    vim.health.info("Engine not loaded")
  elseif engine.is_ready and engine.is_ready() then
    vim.health.ok("Engine initialized")
    if engine.get_index then
      local index = engine.get_index()
      if index and index.notes then
        local count = 0
        for _ in pairs(index.notes) do
          count = count + 1
        end
        vim.health.ok(count .. " notes indexed")
      end
    end
  else
    vim.health.info("Engine not initialized (open a .base file to trigger)")
  end

  -- 6. Cache status
  vim.health.start("Cache status")
  if not vault_path then
    vim.health.info("Cannot check cache (no vault_path)")
  else
    local cache_path = vault_path .. "/.obsidian/plugins/bases/note-cache.mpack"
    local stat = vim.uv.fs_stat(cache_path)
    if stat then
      vim.health.ok("Cache file found")
    else
      vim.health.info("No cache file yet (built on first use)")
    end
  end
end

return M
