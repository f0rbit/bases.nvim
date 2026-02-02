-- Buffer management for Obsidian Bases
local M = {}

---Configure an existing buffer for use as a base viewer
---@param buf number Buffer handle
---@param base_path string Path to the .base file
function M.configure(buf, base_path)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'obsidian_base'
    vim.b[buf].bases_path = base_path
end

---Get or create a buffer for a base
---@param base_path string Path to the .base file
---@return number bufnr
function M.get_or_create(base_path)
    local buf_name = 'base://' .. base_path

    -- Check if buffer already exists
    local existing = vim.fn.bufnr(buf_name)
    if existing ~= -1 then
        return existing
    end

    -- Create new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, buf_name)

    -- Set buffer options
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'obsidian_base'

    -- Store base path for refresh
    vim.b[buf].bases_path = base_path

    return buf
end

---Set buffer content (handles modifiable state)
---@param buf number Buffer handle
---@param lines string[] Lines to set
local function set_lines(buf, lines)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

---Show loading state in buffer
---@param buf number Buffer handle
---@param name string Base name being loaded
function M.set_loading(buf, name)
    set_lines(buf, { '', '  Loading ' .. name .. '...' })
end

---Show error state in buffer
---@param buf number Buffer handle
---@param message string Error message (may contain newlines)
function M.set_error(buf, message)
    local lines = {
        '',
        '  Error loading base:',
        '',
    }
    -- Split message on newlines and indent each line
    for line in message:gmatch('[^\n]+') do
        table.insert(lines, '  ' .. line)
    end
    table.insert(lines, '')
    table.insert(lines, '  Press R to retry')
    set_lines(buf, lines)
end

---Set rendered content in buffer
---@param buf number Buffer handle
---@param lines string[] Rendered table lines
---@param filetype string|nil Filetype to set (default: 'obsidian_base')
function M.set_content(buf, lines, filetype)
    set_lines(buf, lines)
    vim.bo[buf].filetype = filetype or 'obsidian_base'
end

return M
