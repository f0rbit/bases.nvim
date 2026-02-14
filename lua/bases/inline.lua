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
---@param line string
---@return table[] chunks Array of {text, hl_group}
local function line_to_chunks(line)
  -- Use Normal for content visibility, keep border chars subtle
  return { { line, "Normal" } }
end

--- Build error virtual lines
---@param msg string
---@return table[][] virt_lines
local function error_virt_lines(msg)
  return { { { "bases.nvim: " .. msg, "ErrorMsg" } } }
end

--- Track which blocks we've rendered (for mode switching)
---@type table<integer, { start_line: integer, end_line: integer }[]>
local rendered_blocks = {}

--- Fold a code block to completely hide it (no vertical space)
---@param bufnr integer
---@param block { start_line: integer, end_line: integer }
local function fold_block(bufnr, block)
  -- Use nvim_win_call to ensure we're operating on the right window
  local wins = vim.fn.win_findbuf(bufnr)
  if #wins == 0 then
    return
  end
  
  vim.api.nvim_win_call(wins[1], function()
    -- Create a closed fold over the block lines (1-indexed for vim commands)
    local start_line = block.start_line + 1
    local end_line = block.end_line + 1
    
    -- Use manual folding
    vim.wo.foldmethod = "manual"
    vim.wo.foldenable = true
    vim.wo.foldtext = "" -- Empty fold text (no "X lines folded" message)
    
    -- Create and close the fold
    vim.cmd(start_line .. "," .. end_line .. "fold")
  end)
end

--- Unfold a code block to reveal it
---@param bufnr integer
---@param block { start_line: integer, end_line: integer }
local function unfold_block(bufnr, block)
  local wins = vim.fn.win_findbuf(bufnr)
  if #wins == 0 then
    return
  end
  
  vim.api.nvim_win_call(wins[1], function()
    local start_line = block.start_line + 1
    -- Open fold at this line (silent to avoid errors if no fold exists)
    pcall(vim.cmd, start_line .. "foldopen")
  end)
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
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.start_line, 0, {
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
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.start_line, 0, {
        virt_lines = { { { "(no results)", "Comment" } } },
        virt_lines_above = true,
      })
      return
    end

    -- Build virtual lines for the rendered table
    local virt_lines = {}
    for _, line in ipairs(lines) do
      virt_lines[#virt_lines + 1] = line_to_chunks(line)
    end

    -- Track this block for mode-based show/hide
    rendered_blocks[bufnr] = rendered_blocks[bufnr] or {}
    table.insert(rendered_blocks[bufnr], { start_line = block.start_line, end_line = block.end_line })

    -- Fold the code block to hide it completely (no vertical space)
    fold_block(bufnr, block)

    -- Place the table BELOW the line before the fold (so it's visible when folded)
    -- If block starts at line 0, place above line 0; otherwise place below the previous line
    local anchor_line = block.start_line > 0 and block.start_line - 1 or 0
    local above = block.start_line == 0
    
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, anchor_line, 0, {
      virt_lines = virt_lines,
      virt_lines_above = above,
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

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.start_line, 0, {
      virt_lines = error_virt_lines(err),
      virt_lines_above = true,
    })
  end)
end

--- Render all inline ```base``` blocks in a buffer
--- Clears previous renders, finds blocks, queries the engine asynchronously,
--- and places virtual lines above each code block (hiding the raw YAML).
---@param bufnr integer
function M.render(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Bump generation to invalidate any in-flight async queries
  local gen = (render_generation[bufnr] or 0) + 1
  render_generation[bufnr] = gen

  -- Unfold any existing folded blocks before clearing
  if rendered_blocks[bufnr] then
    for _, block in ipairs(rendered_blocks[bufnr]) do
      unfold_block(bufnr, block)
    end
  end

  -- Clear previous extmarks and block tracking
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  rendered_blocks[bufnr] = {}

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

  -- Setup mode autocmds for this buffer (only once)
  M.setup_mode_autocmds(bufnr)

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

  -- Unfold any folded blocks
  if rendered_blocks[bufnr] then
    for _, block in ipairs(rendered_blocks[bufnr]) do
      unfold_block(bufnr, block)
    end
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  rendered_blocks[bufnr] = nil
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

--- Show the raw code blocks (unfold them for editing)
---@param bufnr integer
function M.show_blocks(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local blocks = rendered_blocks[bufnr]
  if not blocks then
    return
  end
  for _, block in ipairs(blocks) do
    unfold_block(bufnr, block)
  end
end

--- Hide the raw code blocks (fold them)
---@param bufnr integer
function M.hide_blocks(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local blocks = rendered_blocks[bufnr]
  if not blocks then
    return
  end
  for _, block in ipairs(blocks) do
    fold_block(bufnr, block)
  end
end

--- Check if cursor is inside any rendered block
---@param bufnr integer
---@return boolean
function M.cursor_in_block(bufnr)
  local blocks = rendered_blocks[bufnr]
  if not blocks then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed
  for _, block in ipairs(blocks) do
    if row >= block.start_line and row <= block.end_line then
      return true
    end
  end
  return false
end

--- Setup autocmds for mode-based show/hide of code blocks
---@param bufnr integer
function M.setup_mode_autocmds(bufnr)
  local group = vim.api.nvim_create_augroup("bases_inline_mode_" .. bufnr, { clear = true })

  -- Show blocks when entering insert mode (if cursor is in a block)
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    buffer = bufnr,
    callback = function()
      if M.cursor_in_block(bufnr) then
        M.show_blocks(bufnr)
      end
    end,
  })

  -- Hide blocks when leaving insert mode
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    buffer = bufnr,
    callback = function()
      M.hide_blocks(bufnr)
    end,
  })

  -- Also handle CursorMoved in normal mode to show block when cursor enters
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = bufnr,
    callback = function()
      -- In normal mode, if cursor moves into a block, show it temporarily
      -- This is optional - remove if you only want insert mode reveal
    end,
  })
end

--- Clean up generation tracking when a buffer is wiped
---@param bufnr integer
function M.on_buf_delete(bufnr)
  render_generation[bufnr] = nil
  rendered_blocks[bufnr] = nil
  pcall(vim.api.nvim_del_augroup_by_name, "bases_inline_mode_" .. bufnr)
end

return M
