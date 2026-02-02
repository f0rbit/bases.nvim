-- View selection for Obsidian Bases
local M = {}

---Get views information from buffer data
---@param buf number Buffer handle
---@return table|nil Views data with count and current index
function M.get_views(buf)
    local data = vim.b[buf].bases_data
    if not data or not data.views then return nil end
    return data.views
end

---Open view selection floating picker
---@param buf number Buffer handle
function M.select_view(buf)
    local views = M.get_views(buf)
    if not views or views.count <= 1 then
        vim.notify('No alternate views available', vim.log.levels.INFO)
        return
    end

    -- Build picker items using view names from API
    local items = {}
    local names = views.names or {}
    for i = 1, views.count do
        local name = names[i] or ('View ' .. i)
        local prefix = (i - 1 == views.current) and '● ' or '  '
        table.insert(items, prefix .. name)
    end

    -- Create buffer for picker
    local picker_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(picker_buf, 0, -1, false, items)

    -- Calculate dimensions
    local width = 0
    for _, item in ipairs(items) do
        width = math.max(width, #item)
    end
    width = width + 4 -- Padding
    local height = #items

    -- Create floating window
    local picker_win = vim.api.nvim_open_win(picker_buf, true, {
        relative = 'cursor',
        row = 1,
        col = 0,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        title = ' Select View ',
        title_pos = 'center',
    })

    -- Buffer options
    vim.bo[picker_buf].buftype = 'nofile'
    vim.bo[picker_buf].bufhidden = 'wipe'
    vim.bo[picker_buf].modifiable = false

    -- Window options
    vim.wo[picker_win].cursorline = true

    -- Position cursor on current view
    vim.api.nvim_win_set_cursor(picker_win, { views.current + 1, 0 })

    -- Helper to close picker
    local function close_picker()
        if vim.api.nvim_win_is_valid(picker_win) then
            vim.api.nvim_win_close(picker_win, true)
        end
    end

    -- Keymaps for picker
    local opts = { buffer = picker_buf, nowait = true }

    vim.keymap.set('n', '<CR>', function()
        local selected = vim.api.nvim_win_get_cursor(picker_win)[1] - 1
        close_picker()
        if selected ~= views.current then
            M.switch_view(buf, selected)
        end
    end, opts)

    vim.keymap.set('n', '<Esc>', close_picker, opts)
    vim.keymap.set('n', 'q', close_picker, opts)

    -- j/k navigation (explicit for clarity)
    vim.keymap.set('n', 'j', 'j', opts)
    vim.keymap.set('n', 'k', 'k', opts)
end

---Switch to a different view
---@param buf number Buffer handle
---@param view_index number View index (0-based)
function M.switch_view(buf, view_index)
    local engine = require('bases.engine')
    local buffer = require('bases.buffer')
    local render = require('bases.render')
    local bases = require('bases')
    local config = bases.get_config()

    local base_path = vim.b[buf].bases_path
    if not base_path then return end

    local base_name = base_path:match('([^/\\]+)$'):gsub('%.base$', '')

    -- Store view index and clear client-side sort
    vim.b[buf].bases_view_index = view_index
    vim.b[buf].bases_sort = nil

    -- Resolve base file path
    local base_file = base_path
    if not base_file:match('^/') then
        local vault = engine.get_vault_path()
        if vault then
            base_file = vault .. '/' .. base_path
        end
    end

    engine.query(base_file, view_index, function(err, data)
        if err then
            buffer.set_error(buf, err)
            return
        end
        render.render(buf, data, config.render_markdown)
    end)
end

return M
