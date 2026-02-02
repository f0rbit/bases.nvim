-- Context-aware navigation for inline base embeds
local M = {}

---Get the screen row for a given buffer line
---@param win number Window handle
---@param line number Buffer line (1-indexed)
---@return number Screen row
local function line_to_screen_row(win, line)
    local wininfo = vim.fn.getwininfo(win)[1]
    if not wininfo then
        return line
    end
    -- Account for window position and scroll
    return line - wininfo.topline + wininfo.winrow
end

---Check if a screen row is within an embed's virtual lines area
---@param embed table Embed info with line_end and data
---@param cursor_line number Current buffer line (1-indexed)
---@return boolean
local function is_in_virtual_area(embed, cursor_line)
    -- Virtual lines appear AFTER embed.line_end
    -- Cursor can only be on actual buffer lines, not virtual lines
    -- So we need a different approach: check if cursor is on the embed line itself
    return cursor_line == embed.line_end
end

---Get the embed context at the current cursor position
---@param buf number Buffer handle
---@return table|nil Embed info if cursor is in an embed area
function M.get_embed_context(buf)
    local embeds = vim.b[buf].bases_inline_embeds
    if not embeds then
        return nil
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor[1]

    -- Find embed at current line
    for _, embed in ipairs(embeds) do
        if embed.line_start <= cursor_line and cursor_line <= embed.line_end then
            return embed
        end
    end

    return nil
end

---Get link at position within an embed's virtual lines
---Note: Since virtual lines are not navigable with normal cursor,
---we track which link is "selected" within the embed
---@param embed table Embed info
---@param link_index number 1-indexed link index
---@return table|nil Link info
function M.get_link_by_index(embed, link_index)
    if not embed.links or #embed.links == 0 then
        return nil
    end

    if link_index < 1 or link_index > #embed.links then
        return nil
    end

    return embed.links[link_index]
end

---Get cell at position within an embed
---@param embed table Embed info
---@param cell_index number 1-indexed cell index
---@return table|nil Cell info
function M.get_cell_by_index(embed, cell_index)
    if not embed.cells or #embed.cells == 0 then
        return nil
    end

    if cell_index < 1 or cell_index > #embed.cells then
        return nil
    end

    return embed.cells[cell_index]
end

---Follow link in current embed
---@param buf number Buffer handle
---@return boolean true if action was handled
function M.follow_link(buf)
    local embed = M.get_embed_context(buf)
    if not embed then
        return false
    end

    -- Get current selected link index
    local link_index = embed.selected_link or 1
    local link = M.get_link_by_index(embed, link_index)

    if not link then
        vim.notify('No link selected', vim.log.levels.INFO)
        return true
    end

    local engine = require('bases.engine')
    local vault_path = engine.get_vault_path()
    if not vault_path then
        vim.notify('vault_path not configured', vim.log.levels.ERROR)
        return true
    end

    local full_path = vault_path .. '/' .. link.path

    -- Add .md extension if not present
    if not full_path:match('%.md$') then
        full_path = full_path .. '.md'
    end

    if vim.fn.filereadable(full_path) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
    else
        vim.notify('Could not resolve: ' .. link.path, vim.log.levels.WARN)
    end

    return true
end

---Move to next link in current embed
---@param buf number Buffer handle
---@return boolean true if action was handled
function M.next_link(buf)
    local embeds = vim.b[buf].bases_inline_embeds
    if not embeds or #embeds == 0 then
        return false
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor[1]

    -- Find current or next embed
    local current_embed = nil
    local current_embed_idx = nil

    for i, embed in ipairs(embeds) do
        if embed.line_start <= cursor_line and cursor_line <= embed.line_end then
            current_embed = embed
            current_embed_idx = i
            break
        elseif embed.line_start > cursor_line then
            -- Cursor is before this embed, jump to it
            vim.api.nvim_win_set_cursor(0, { embed.line_start, 0 })
            embed.selected_link = 1
            M.show_selection_indicator(buf, embed)
            return true
        end
    end

    if not current_embed then
        -- No embed at or after cursor, wrap to first
        if #embeds > 0 then
            local embed = embeds[1]
            vim.api.nvim_win_set_cursor(0, { embed.line_start, 0 })
            embed.selected_link = 1
            M.show_selection_indicator(buf, embed)
            return true
        end
        return false
    end

    -- Within an embed, cycle through links
    if not current_embed.links or #current_embed.links == 0 then
        -- No links in this embed, move to next embed
        local next_idx = (current_embed_idx % #embeds) + 1
        local next_embed = embeds[next_idx]
        vim.api.nvim_win_set_cursor(0, { next_embed.line_start, 0 })
        next_embed.selected_link = 1
        M.show_selection_indicator(buf, next_embed)
        return true
    end

    local current_link = current_embed.selected_link or 0
    local next_link = current_link + 1

    if next_link > #current_embed.links then
        -- Move to next embed
        local next_idx = (current_embed_idx % #embeds) + 1
        local next_embed = embeds[next_idx]
        vim.api.nvim_win_set_cursor(0, { next_embed.line_start, 0 })
        next_embed.selected_link = 1
        M.show_selection_indicator(buf, next_embed)
    else
        current_embed.selected_link = next_link
        M.show_selection_indicator(buf, current_embed)
    end

    return true
end

---Move to previous link in current embed
---@param buf number Buffer handle
---@return boolean true if action was handled
function M.prev_link(buf)
    local embeds = vim.b[buf].bases_inline_embeds
    if not embeds or #embeds == 0 then
        return false
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor[1]

    -- Find current or previous embed
    local current_embed = nil
    local current_embed_idx = nil

    for i = #embeds, 1, -1 do
        local embed = embeds[i]
        if embed.line_start <= cursor_line and cursor_line <= embed.line_end then
            current_embed = embed
            current_embed_idx = i
            break
        elseif embed.line_end < cursor_line then
            -- Cursor is after this embed, jump to it
            vim.api.nvim_win_set_cursor(0, { embed.line_start, 0 })
            embed.selected_link = embed.links and #embed.links or 0
            M.show_selection_indicator(buf, embed)
            return true
        end
    end

    if not current_embed then
        -- No embed at or before cursor, wrap to last
        if #embeds > 0 then
            local embed = embeds[#embeds]
            vim.api.nvim_win_set_cursor(0, { embed.line_start, 0 })
            embed.selected_link = embed.links and #embed.links or 0
            M.show_selection_indicator(buf, embed)
            return true
        end
        return false
    end

    -- Within an embed, cycle through links
    if not current_embed.links or #current_embed.links == 0 then
        -- No links in this embed, move to previous embed
        local prev_idx = ((current_embed_idx - 2) % #embeds) + 1
        local prev_embed = embeds[prev_idx]
        vim.api.nvim_win_set_cursor(0, { prev_embed.line_start, 0 })
        prev_embed.selected_link = prev_embed.links and #prev_embed.links or 0
        M.show_selection_indicator(buf, prev_embed)
        return true
    end

    local current_link = current_embed.selected_link or (#current_embed.links + 1)
    local prev_link = current_link - 1

    if prev_link < 1 then
        -- Move to previous embed
        local prev_idx = ((current_embed_idx - 2) % #embeds) + 1
        local prev_embed = embeds[prev_idx]
        vim.api.nvim_win_set_cursor(0, { prev_embed.line_start, 0 })
        prev_embed.selected_link = prev_embed.links and #prev_embed.links or 0
        M.show_selection_indicator(buf, prev_embed)
    else
        current_embed.selected_link = prev_link
        M.show_selection_indicator(buf, current_embed)
    end

    return true
end

---Show selection indicator for current link
---@param buf number Buffer handle
---@param embed table Embed info
function M.show_selection_indicator(buf, embed)
    if not embed.links or #embed.links == 0 then
        vim.notify('No links in this base', vim.log.levels.INFO)
        return
    end

    local link_index = embed.selected_link or 1
    local link = embed.links[link_index]
    if link then
        vim.notify(
            string.format('Link %d/%d: %s', link_index, #embed.links, link.text or link.path),
            vim.log.levels.INFO
        )
    end
end

---Edit cell in current embed
---@param buf number Buffer handle
---@return boolean true if action was handled
function M.edit_cell(buf)
    local embed = M.get_embed_context(buf)
    if not embed then
        return false
    end

    -- Find editable cell at selected link position, or first editable cell
    local link_index = embed.selected_link or 1
    local target_cell = nil

    -- Try to find cell at same position as selected link
    if embed.links and embed.cells then
        local link = embed.links[link_index]
        if link then
            for _, cell in ipairs(embed.cells) do
                if cell.row == link.row and cell.editable then
                    target_cell = cell
                    break
                end
            end
        end
    end

    -- Fall back to first editable cell
    if not target_cell and embed.cells then
        for _, cell in ipairs(embed.cells) do
            if cell.editable then
                target_cell = cell
                break
            end
        end
    end

    if not target_cell then
        vim.notify('No editable cell found', vim.log.levels.WARN)
        return true
    end

    -- Open edit popup
    M.open_edit_popup(buf, embed, target_cell)
    return true
end

---Open edit popup for a cell
---@param buf number Buffer handle
---@param embed table Embed info
---@param cell table Cell info
function M.open_edit_popup(buf, embed, cell)
    local edit = require('bases.edit')

    -- Get current value
    local current_value = ''
    if cell.raw_value then
        if cell.raw_value.type == 'primitive' then
            local v = cell.raw_value.value
            if v ~= nil then
                current_value = tostring(v)
            end
        elseif cell.raw_value.type == 'link' then
            local text = cell.raw_value.value or ''
            current_value = text:match('%[%[([^%]]+)%]%]') or text
        end
    end

    local prop_name = cell.property:match('%.([^%.]+)$') or cell.property

    -- Calculate window size
    local width = math.max(30, #current_value + 4)
    local height = 1

    -- Create buffer
    local edit_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, { current_value })

    -- Window position (centered)
    local ui = vim.api.nvim_list_uis()[1]
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
        title = ' Edit: ' .. prop_name .. ' ',
        title_pos = 'center',
    })

    -- Buffer options
    vim.bo[edit_buf].buftype = 'nofile'
    vim.bo[edit_buf].bufhidden = 'wipe'
    vim.bo[edit_buf].modifiable = true

    -- Window options
    vim.wo[win].cursorline = false
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false

    -- Position cursor at end of text
    vim.api.nvim_win_set_cursor(win, { 1, #current_value })

    -- Close window helper
    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- Save handler
    local function save()
        local lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
        local new_value = lines[1] or ''
        close_window()

        -- Submit edit via API
        M.submit_inline_edit(buf, embed, cell, new_value)
    end

    -- Cancel handler
    local function cancel()
        close_window()
    end

    -- Keymaps
    local opts = { buffer = edit_buf, silent = true, nowait = true }

    vim.keymap.set('n', '<CR>', save, opts)
    vim.keymap.set('i', '<CR>', function()
        vim.cmd('stopinsert')
        save()
    end, opts)

    vim.keymap.set('n', '<Esc>', cancel, opts)
    vim.keymap.set('n', 'q', cancel, opts)
    vim.keymap.set('i', '<Esc>', function()
        vim.cmd('stopinsert')
        cancel()
    end, opts)

    vim.cmd('startinsert!')
end

---Submit inline edit via direct frontmatter modification
---@param buf number Buffer handle
---@param embed table Embed info
---@param cell table Cell info
---@param new_value string New value
function M.submit_inline_edit(buf, embed, cell, new_value)
    local engine = require('bases.engine')
    local frontmatter_editor = require('bases.engine.frontmatter_editor')

    -- Resolve absolute file path
    local vault = engine.get_vault_path()
    if not vault then
        vim.notify('Engine not initialized', vim.log.levels.ERROR)
        return
    end
    local abs_path = vault .. '/' .. cell.file_path

    -- Extract bare field name from qualified property name
    local field_name = cell.property:match('%.([^%.]+)$') or cell.property

    -- Convert empty string to nil for deletion
    local value = new_value
    if value == '' then
        value = nil
    end

    -- Update frontmatter directly
    local success, err = frontmatter_editor.update_field(abs_path, field_name, value)
    if not success then
        vim.notify('Edit failed: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
        return
    end

    vim.notify('Updated ' .. field_name, vim.log.levels.INFO)

    -- Re-index the modified file
    engine.update_file(cell.file_path, function(index_err)
        if index_err then
            vim.notify('Warning: re-index failed: ' .. index_err, vim.log.levels.WARN)
        end
        -- Refresh the embed
        local inline = require('bases.inline')
        inline.refresh_buffer(buf)
    end)
end

return M
