-- bases.nvim — Inline block detection + extmark rendering
-- Finds ```base``` blocks in markdown and renders them as virtual lines
local M = {}

local ns_id = vim.api.nvim_create_namespace("bases_inline")

--- Exported so init.lua toggle_current can check for existing extmarks
M.ns_id = ns_id

--- Track pending async queries per buffer to avoid stale renders
---@type table<integer, integer>
local render_generation = {}

--- Find all ```base``` code blocks in a buffer
--- Returns 0-indexed line numbers matching nvim API conventions
---@param bufnr integer
---@return { start_line: integer, end_line: integer, content: string }[]
function M.find_blocks(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local in_block = false
  local current = nil
  local fence_depth = 0

  for i, line in ipairs(lines) do
    if not in_block then
      -- Match opening ```base fence (allow leading whitespace)
      if line:match("^%s*```base%s*$") then
        in_block = true
        fence_depth = 1
        current = { start_line = i - 1, content_lines = {} }
      end
    else
      -- Track nested fences to avoid false close on inner ``` blocks
      if line:match("^%s*```%w") then
        fence_depth = fence_depth + 1
      elseif line:match("^%s*```%s*$") then
        fence_depth = fence_depth - 1
        if fence_depth == 0 then
          in_block = false
          current.end_line = i - 1
          current.content = table.concat(current.content_lines, "\n")
          current.content_lines = nil
          blocks[#blocks + 1] = current
          current = nil
        end
      else
        current.content_lines[#current.content_lines + 1] = line
      end
    end
  end

  return blocks
end

--- Resolve the vault-relative path for a buffer
---@param bufnr integer
---@return string|nil
local function resolve_this_file(bufnr)
  local engine = require("bases.engine")
  local vault_path = engine.get_vault_path()
  if not vault_path then
    return nil
  end

  local abs = vim.api.nvim_buf_get_name(bufnr)
  if abs == "" then
    return nil
  end

  -- Normalize both paths for comparison
  vault_path = vim.fs.normalize(vault_path)
  abs = vim.fs.normalize(abs)

  -- Strip vault prefix to get relative path
  if abs:sub(1, #vault_path) == vault_path then
    local rel = abs:sub(#vault_path + 2) -- skip trailing /
    return rel
  end

  return nil
end

--- Build virtual line chunks from a rendered line
--- For v1: single chunk per line with BasesTableBorder highlight
---@param line string
---@return table[] chunks Array of {text, hl_group}
local function line_to_chunks(line)
  return { { line, "BasesTableBorder" } }
end

--- Build error virtual lines
---@param msg string
---@return table[][] virt_lines
local function error_virt_lines(msg)
  return { { { "bases.nvim: " .. msg, "ErrorMsg" } } }
end

--- Render a single block result as extmarks
---@param bufnr integer
---@param block { start_line: integer, end_line: integer, content: string }
---@param generation integer
---@param result SerializedResult
local function render_block_result(bufnr, block, generation, result)
  vim.schedule(function()
    -- Stale check: another render was triggered since this query started
    if render_generation[bufnr] ~= generation then
      return
    end

    -- Buffer may have been deleted while the async query ran
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local ok, render_mod = pcall(require, "bases.render")
    if not ok then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.end_line, 0, {
        virt_lines = error_virt_lines("render module not available"),
      })
      return
    end

    -- Get render config (may not exist yet if init.lua hasn't been set up)
    local config = {}
    local bases_ok, bases = pcall(require, "bases")
    if bases_ok and bases.config and bases.config.render then
      config = bases.config.render
    end

    local lines, _ = render_mod.render(result, config)
    if not lines or #lines == 0 then
      -- Empty result — show a note
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.end_line, 0, {
        virt_lines = { { { "bases.nvim: (no results)", "Comment" } } },
      })
      return
    end

    local virt_lines = {}
    for _, line in ipairs(lines) do
      virt_lines[#virt_lines + 1] = line_to_chunks(line)
    end

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.end_line, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
  end)
end

--- Render a single block error as extmarks
---@param bufnr integer
---@param block { start_line: integer, end_line: integer, content: string }
---@param generation integer
---@param err string
local function render_block_error(bufnr, block, generation, err)
  vim.schedule(function()
    if render_generation[bufnr] ~= generation then
      return
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.end_line, 0, {
      virt_lines = error_virt_lines(err),
    })
  end)
end

--- Render all inline ```base``` blocks in a buffer
--- Clears previous renders, finds blocks, queries the engine asynchronously,
--- and places virtual lines below each closing ``` fence.
---@param bufnr integer
function M.render(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Bump generation to invalidate any in-flight async queries
  local gen = (render_generation[bufnr] or 0) + 1
  render_generation[bufnr] = gen

  -- Clear previous extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local engine = require("bases.engine")

  if not engine.is_ready() then
    -- Engine not initialized yet — queue render for when it's ready
    engine.on_ready(function(err)
      if err then
        vim.notify("bases.nvim: engine init failed: " .. err, vim.log.levels.WARN)
        return
      end
      -- Re-trigger render once engine is ready (if generation still matches)
      if render_generation[bufnr] == gen then
        M.render(bufnr)
      end
    end)
    return
  end

  local blocks = M.find_blocks(bufnr)
  if #blocks == 0 then
    return
  end

  local this_file = resolve_this_file(bufnr)

  for _, block in ipairs(blocks) do
    if block.content == "" then
      render_block_error(bufnr, block, gen, "empty base block")
    else
      engine.query_string(block.content, this_file, 0, function(err, result)
        if result then
          render_block_result(bufnr, block, gen, result)
        else
          render_block_error(bufnr, block, gen, err or "query failed")
        end
      end)
    end
  end
end

--- Clear all inline renders in a buffer
---@param bufnr integer
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Bump generation so any in-flight queries are discarded
  render_generation[bufnr] = (render_generation[bufnr] or 0) + 1

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

--- Check if a buffer has any inline renders
---@param bufnr integer
---@return boolean
function M.has_renders(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
  return #marks > 0
end

--- Toggle inline renders for a buffer
---@param bufnr integer|nil
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if M.has_renders(bufnr) then
    M.clear(bufnr)
  else
    M.render(bufnr)
  end
end

--- Clean up generation tracking when a buffer is wiped
---@param bufnr integer
function M.on_buf_delete(bufnr)
  render_generation[bufnr] = nil
end

return M
