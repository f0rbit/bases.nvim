-- bases.nvim — Buffer management for .base files
-- Scratch buffer creation and content management
local M = {}

--- Create or get a scratch buffer for a .base file
---@param source_path string Path to the .base file
---@return integer bufnr
function M.create(source_path)
  local bufnr = vim.api.nvim_get_current_buf()

  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "base"

  -- Store source path as buffer variable for re-rendering
  vim.b[bufnr].bases_source = source_path

  return bufnr
end

--- Set lines in a buffer (temporarily makes it modifiable)
---@param bufnr integer
---@param lines string[]
function M.set_lines(bufnr, lines)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

--- Apply highlights to a buffer
---@param bufnr integer
---@param highlights table[] Array of {line, col_start, col_end, group}
---@param ns_id integer Namespace ID
function M.apply_highlights(bufnr, highlights, ns_id)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
  end
end

--- Set up keymaps for a base buffer
---@param bufnr integer
function M.set_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "r", function()
    require("bases").render_current()
  end, vim.tbl_extend("force", opts, { desc = "Re-render base" }))
  vim.keymap.set("n", "q", function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end, vim.tbl_extend("force", opts, { desc = "Close base view" }))
end

return M
