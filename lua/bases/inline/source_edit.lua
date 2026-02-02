-- Floating editor for inline ```base code block YAML
local M = {}

---Open floating editor for a code block's YAML content
---@param buf number Original markdown buffer handle
---@param embed table Embed info with content_start, content_end, line_start (1-indexed)
function M.edit_codeblock(buf, embed)
    -- Extract YAML lines from the markdown buffer
    local lines = vim.api.nvim_buf_get_lines(buf, embed.content_start - 1, embed.content_end, false)

    -- Calculate window size (80% of screen)
    local ui = vim.api.nvim_list_uis()[1]
    local width = math.floor(ui.width * 0.8)
    local height = math.floor(ui.height * 0.8)

    -- Create buffer
    local edit_buf = vim.api.nvim_create_buf(false, false)

    -- Set buffer name (required for acwrite buftype)
    vim.api.nvim_buf_set_name(edit_buf, 'bases://inline-' .. embed.line_start)

    -- Set buffer options before content
    vim.bo[edit_buf].buftype = 'acwrite'
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

    -- Create floating window
    local win = vim.api.nvim_open_win(edit_buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' Edit: inline base ',
        title_pos = 'center',
        footer = ' <CR>/:w save | <Esc>/q cancel ',
        footer_pos = 'center',
    })

    -- Window options
    vim.wo[win].number = true
    vim.wo[win].cursorline = true

    -- Track initial content for unsaved changes detection
    local initial_content = table.concat(lines, '\n')

    local function has_unsaved_changes()
        local current_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
        return table.concat(current_lines, '\n') ~= initial_content
    end

    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- Save handler: write YAML back into markdown buffer and re-render
    local function save()
        local new_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
        close_window()

        -- Replace YAML content in the markdown buffer
        vim.api.nvim_buf_set_lines(buf, embed.content_start - 1, embed.content_end, false, new_lines)

        -- Invalidate cached embeds (line numbers may have changed)
        vim.b[buf].bases_inline_embeds = nil

        -- Full re-scan and re-render
        require('bases.inline').render_buffer(buf)
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
            end)
        else
            close_window()
        end
    end

    -- Keymaps
    local opts = { buffer = edit_buf, silent = true, nowait = true }

    -- Save on Enter (normal mode only)
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

return M
