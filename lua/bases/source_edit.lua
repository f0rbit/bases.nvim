-- Source file editing for Obsidian Bases
local M = {}

---Open floating editor for the raw .base source file
---@param buf number Original buffer handle
---@param base_path string Path to the .base file
---@param on_save_callback fun() Callback after successful save
local function open_source_editor(buf, base_path, on_save_callback)
    -- Read the file content
    local lines = vim.fn.readfile(base_path)
    if not lines then
        vim.notify('Failed to read ' .. base_path, vim.log.levels.ERROR)
        return
    end

    -- Calculate window size (80% of screen)
    local ui = vim.api.nvim_list_uis()[1]
    local width = math.floor(ui.width * 0.8)
    local height = math.floor(ui.height * 0.8)

    -- Create buffer (not scratch, so it's fully editable)
    local edit_buf = vim.api.nvim_create_buf(false, false)

    -- Set buffer name (required for acwrite buftype)
    vim.api.nvim_buf_set_name(edit_buf, 'bases://' .. base_path)

    -- Set buffer options before content
    vim.bo[edit_buf].buftype = 'acwrite'  -- Allow :w but handle it ourselves
    vim.bo[edit_buf].bufhidden = 'wipe'
    vim.bo[edit_buf].swapfile = false

    -- Set content
    vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, lines)

    -- Set filetype for syntax highlighting, then ensure modifiable
    vim.bo[edit_buf].filetype = 'yaml'
    vim.bo[edit_buf].modifiable = true
    vim.bo[edit_buf].readonly = false

    -- Window position (centered)
    local row = math.floor((ui.height - height) / 2) - 1
    local col = math.floor((ui.width - width) / 2)

    -- Extract filename for title
    local filename = base_path:match('([^/\\]+)$') or base_path

    -- Create floating window
    local win = vim.api.nvim_open_win(edit_buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' Edit: ' .. filename .. ' ',
        title_pos = 'center',
        footer = ' <CR>/:w save | <Esc>/q cancel ',
        footer_pos = 'center',
    })

    -- Window options
    vim.wo[win].number = true
    vim.wo[win].cursorline = true

    -- Track if buffer has been modified
    local initial_content = table.concat(lines, '\n')

    -- Helper to check for unsaved changes
    local function has_unsaved_changes()
        local current_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
        local current_content = table.concat(current_lines, '\n')
        return current_content ~= initial_content
    end

    -- Close window helper
    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- Save handler
    local function save()
        local current_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
        local write_result = vim.fn.writefile(current_lines, base_path)
        if write_result == -1 then
            vim.notify('Failed to write ' .. base_path, vim.log.levels.ERROR)
            return
        end
        close_window()
        -- Don't notify here - let the refresh callback handle the message
        on_save_callback()
    end

    -- Cancel handler with unsaved changes prompt
    local function cancel()
        if has_unsaved_changes() then
            vim.ui.select({ 'Discard changes', 'Continue editing' }, {
                prompt = 'You have unsaved changes:',
            }, function(choice)
                if choice == 'Discard changes' then
                    close_window()
                end
                -- 'Continue editing' or nil (cancelled) - do nothing, stay in editor
            end)
        else
            close_window()
        end
    end

    -- Keymaps
    local opts = { buffer = edit_buf, silent = true, nowait = true }

    -- Save on Enter (normal mode only, to allow multiline editing)
    vim.keymap.set('n', '<CR>', save, opts)

    -- Save on :w
    vim.api.nvim_create_autocmd('BufWriteCmd', {
        buffer = edit_buf,
        callback = function()
            save()
        end,
    })

    -- Cancel on Escape or q (normal mode)
    vim.keymap.set('n', '<Esc>', cancel, opts)
    vim.keymap.set('n', 'q', cancel, opts)
end

---Main entry point - edit source for current base buffer
---@param buf number Buffer handle
function M.edit_source(buf)
    local base_path = vim.b[buf].bases_path
    if not base_path then
        vim.notify('Not a bases buffer', vim.log.levels.WARN)
        return
    end

    -- Check if file exists
    if vim.fn.filereadable(base_path) ~= 1 then
        vim.notify('Source file not found: ' .. base_path, vim.log.levels.ERROR)
        return
    end

    open_source_editor(buf, base_path, function()
        -- Refresh the base view after save (silent to avoid "Press ENTER" prompt)
        local bases = require('bases')
        bases.refresh(buf, { silent = true })
    end)
end

return M
