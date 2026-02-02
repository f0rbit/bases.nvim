-- Inline base rendering for markdown files
-- Renders ![[name.base]] embeds as virtual lines below the embed syntax
local M = {}

---Check if a file is within the configured vault
---@param file_path string Absolute file path
---@return boolean
local function is_in_vault(file_path)
    local vault_path = require('bases.engine').get_vault_path()
    if not vault_path then
        return false
    end

    return vim.startswith(file_path, vault_path)
end

---Setup buffer-local keymaps for inline navigation
---@param buf number Buffer handle
local function setup_keymaps(buf)
    local bases = require('bases')
    local config = bases.get_config()
    local nav = require('bases.inline.navigation')

    local keymaps = config.inline and config.inline.keymaps or {}
    local map_opts = { buffer = buf, silent = true }

    -- Follow link (falls through if not in embed)
    if keymaps.follow_link then
        vim.keymap.set('n', keymaps.follow_link, function()
            if not nav.follow_link(buf) then
                -- Fall through to default Enter behavior
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes('<CR>', true, false, true),
                    'n',
                    false
                )
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Follow link in inline base' }))
    end

    -- Next link
    if keymaps.next_link then
        vim.keymap.set('n', keymaps.next_link, function()
            if not nav.next_link(buf) then
                -- Fall through to default Tab behavior
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes('<Tab>', true, false, true),
                    'n',
                    false
                )
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Next link in inline base' }))
    end

    -- Previous link
    if keymaps.prev_link then
        vim.keymap.set('n', keymaps.prev_link, function()
            if not nav.prev_link(buf) then
                -- Fall through to default S-Tab behavior
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes('<S-Tab>', true, false, true),
                    'n',
                    false
                )
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Previous link in inline base' }))
    end

    -- Edit cell
    if keymaps.edit_cell then
        vim.keymap.set('n', keymaps.edit_cell, function()
            if not nav.edit_cell(buf) then
                -- Fall through to default 'c' behavior
                vim.api.nvim_feedkeys('c', 'n', false)
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Edit cell in inline base' }))
    end

    -- Edit source (for code block embeds)
    if keymaps.edit_source then
        vim.keymap.set('n', keymaps.edit_source, function()
            local embed = nav.get_embed_context(buf)
            if embed and embed.type == 'codeblock' then
                require('bases.inline.source_edit').edit_codeblock(buf, embed)
            else
                -- Fall through to default key behavior
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes(keymaps.edit_source, true, false, true),
                    'n',
                    false
                )
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Edit inline base source' }))
    end

    -- Refresh
    if keymaps.refresh then
        vim.keymap.set('n', keymaps.refresh, function()
            M.refresh_buffer(buf)
        end, vim.tbl_extend('force', map_opts, { desc = 'Refresh inline bases' }))
    end
end

---Render a single file embed (![[name.base]])
---@param buf number Buffer handle
---@param embed table Embed info
---@param callback fun(embed: table) Called when rendering is complete
local function render_single_embed(buf, embed, callback)
    local engine = require('bases.engine')
    local detect = require('bases.inline.detect')
    local render = require('bases.inline.render')

    local base_name = detect.base_name(embed.source)

    -- Show loading state
    embed.extmark_id = render.apply_loading(buf, embed, base_name)

    -- Resolve base file path within vault
    local base_file
    local vault = engine.get_vault_path()
    if vault then
        base_file = vault .. '/' .. base_name .. '.base'
    else
        embed.extmark_id = render.apply_error(buf, embed, 'Engine not initialized')
        embed.data = nil
        embed.links = {}
        embed.cells = {}
        callback(embed)
        return
    end

    -- Fetch data from engine
    engine.query(base_file, 0, function(err, data)
        if err then
            embed.extmark_id = render.apply_error(buf, embed, err)
            embed.data = nil
            embed.links = {}
            embed.cells = {}
            callback(embed)
            return
        end

        -- Render the table (pass view_state for future inline sorting support)
        local result = render.render_embed(data, embed.view or {})
        if result then
            embed.extmark_id = render.apply_virtual_lines(buf, embed, result)
            embed.data = result
            embed.links = result.links
            embed.cells = result.cells
            embed.headers = result.headers
            embed.api_data = data  -- Store full API response for re-rendering
        else
            embed.extmark_id = render.apply_error(buf, embed, 'Failed to render')
            embed.data = nil
            embed.links = {}
            embed.cells = {}
        end

        callback(embed)
    end)
end

---Render a single code block embed (```base ... ```)
---@param buf number Buffer handle
---@param embed table Embed info with type='codeblock'
---@param callback fun(embed: table) Called when rendering is complete
local function render_single_codeblock(buf, embed, callback)
    local engine = require('bases.engine')
    local render = require('bases.inline.render')

    -- Conceal the source code block first
    render.conceal_codeblock(buf, embed)

    -- Show loading state
    embed.extmark_id = render.apply_codeblock_loading(buf, embed)

    -- Compute vault-relative path for this_file
    local this_file_path = nil
    local vault = engine.get_vault_path()
    if vault then
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if vim.startswith(buf_name, vault .. '/') then
            this_file_path = buf_name:sub(#vault + 2)
        end
    end

    -- Query using the YAML string
    engine.query_string(embed.source, this_file_path, 0, function(err, data)
        if err then
            embed.extmark_id = render.apply_codeblock_error(buf, embed, err)
            embed.data = nil
            embed.links = {}
            embed.cells = {}
            callback(embed)
            return
        end

        local result = render.render_embed(data, embed.view or {})
        if result then
            embed.extmark_id = render.apply_codeblock_virtual_lines(buf, embed, result)
            embed.data = result
            embed.links = result.links
            embed.cells = result.cells
            embed.headers = result.headers
            embed.api_data = data
        else
            embed.extmark_id = render.apply_codeblock_error(buf, embed, 'Failed to render')
            embed.data = nil
            embed.links = {}
            embed.cells = {}
        end

        callback(embed)
    end)
end

---Render all embeds in a buffer
---@param buf number Buffer handle
function M.render_buffer(buf)
    buf = buf or vim.api.nvim_get_current_buf()

    -- Get file path
    local file_path = vim.api.nvim_buf_get_name(buf)
    if file_path == '' then
        return
    end

    -- Check if file is in vault
    if not is_in_vault(file_path) then
        return
    end

    -- Check if inline rendering is enabled
    local bases = require('bases')
    local config = bases.get_config()
    if not config.inline or not config.inline.enabled then
        return
    end

    local detect = require('bases.inline.detect')
    local render = require('bases.inline.render')

    -- Clear existing embeds
    render.clear_all(buf)

    -- Scan for all embeds (file + codeblock)
    local embeds = detect.scan_all(buf)
    if #embeds == 0 then
        vim.b[buf].bases_inline_embeds = nil
        return
    end

    -- Store embeds in buffer variable
    vim.b[buf].bases_inline_embeds = embeds

    -- Setup keymaps
    setup_keymaps(buf)

    -- Render each embed by type
    for _, embed in ipairs(embeds) do
        local render_fn = embed.type == 'codeblock' and render_single_codeblock or render_single_embed
        render_fn(buf, embed, function(_)
            -- Update stored embeds
            vim.b[buf].bases_inline_embeds = embeds
        end)
    end
end

---Refresh all embeds in a buffer
---@param buf number Buffer handle
---@param opts table|nil Options: { silent = boolean }
function M.refresh_buffer(buf, opts)
    buf = buf or vim.api.nvim_get_current_buf()
    opts = opts or {}

    local embeds = vim.b[buf].bases_inline_embeds
    if not embeds or #embeds == 0 then
        -- No existing embeds, do a full render
        M.render_buffer(buf)
        return
    end

    if not opts.silent then
        vim.notify('Refreshing inline bases...', vim.log.levels.INFO)
    end

    -- Re-render each embed by type
    local completed = 0
    for _, embed in ipairs(embeds) do
        local render_fn = embed.type == 'codeblock' and render_single_codeblock or render_single_embed
        render_fn(buf, embed, function(_)
            completed = completed + 1
            if completed == #embeds then
                vim.b[buf].bases_inline_embeds = embeds
                if not opts.silent then
                    vim.notify('Inline bases refreshed', vim.log.levels.INFO)
                end
            end
        end)
    end
end

---Get embed at cursor position
---@param buf number Buffer handle
---@return table|nil Embed info if cursor is on an embed line
function M.get_embed_at_cursor(buf)
    local nav = require('bases.inline.navigation')
    return nav.get_embed_context(buf)
end

---Setup autocmds for markdown files
function M.setup()
    local bases = require('bases')
    local config = bases.get_config()

    if not config.inline or not config.inline.enabled then
        return
    end

    local group = vim.api.nvim_create_augroup('BasesInline', { clear = true })

    -- Auto-render on buffer enter (if enabled)
    if config.inline.auto_render then
        vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
            group = group,
            pattern = { '*.md', '*.markdown' },
            callback = function(args)
                -- Small delay to let buffer fully load
                -- Debounce check is inside defer_fn to handle BufEnter+BufWinEnter race
                vim.defer_fn(function()
                    if not vim.api.nvim_buf_is_valid(args.buf) then
                        return
                    end
                    -- Debounce: don't re-render if we already have embeds
                    local embeds = vim.b[args.buf].bases_inline_embeds
                    if embeds then
                        return
                    end
                    M.render_buffer(args.buf)
                end, 50)
            end,
            desc = 'Render inline bases in markdown files',
        })
    end

    -- Re-scan on buffer write (in case embeds changed)
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        pattern = { '*.md', '*.markdown' },
        callback = function(args)
            -- Clear and re-render
            vim.b[args.buf].bases_inline_embeds = nil
            M.render_buffer(args.buf)
        end,
        desc = 'Re-render inline bases after save',
    })
end

return M
