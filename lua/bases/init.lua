-- bases.nvim - Obsidian Bases viewer for Neovim
local M = {}

---@class BasesKeymaps
---@field follow_link string|false Keymap to follow link (default: '<CR>')
---@field next_link string|false Keymap to jump to next link (default: '<Tab>')
---@field prev_link string|false Keymap to jump to previous link (default: '<S-Tab>')
---@field refresh string|false Keymap to refresh base data (default: 'R')
---@field edit_cell string|false Keymap to edit cell under cursor (default: 'c')
---@field edit_source string|false Keymap to edit base source file (default: 'E')
---@field select_view string|false Keymap to select view (default: 'v')
---@field debug string|false Keymap to show debug info (default: '?')

---@class BasesInlineKeymaps
---@field follow_link string|false Keymap to follow link in inline base (default: '<CR>')
---@field next_link string|false Keymap to jump to next link in inline base (default: '<Tab>')
---@field prev_link string|false Keymap to jump to previous link in inline base (default: '<S-Tab>')
---@field refresh string|false Keymap to refresh inline bases (default: '<leader>br')
---@field edit_cell string|false Keymap to edit cell in inline base (default: 'c')
---@field edit_source string|false Keymap to edit inline base source (default: 'E')

---@class BasesInlineConfig
---@field enabled boolean Enable inline rendering (default: true)
---@field auto_render boolean Auto-render on BufEnter (default: true)
---@field keymaps BasesInlineKeymaps Keymap configuration for inline bases

---@class BasesDashboardSection
---@field base string Base name (without .base extension)
---@field title string|nil Section title (defaults to base name)
---@field max_rows number|nil Maximum data rows to display

---@class BasesDashboardConfig
---@field title string|nil Main dashboard title
---@field sections BasesDashboardSection[] Sections to display
---@field spacing number|nil Lines between sections (default: 1)

---@class BasesConfig
---@field vault_path string|nil Vault path (auto-detected from obsidian.nvim if available)
---@field render_markdown boolean Use markdown tables for render-markdown.nvim (default: false)
---@field date_format string Date format string (default: '%Y-%m-%d')
---@field date_format_relative boolean Use relative dates (default: false)
---@field keymaps BasesKeymaps Keymap configuration
---@field inline BasesInlineConfig Inline base rendering configuration
---@field dashboards table<string, BasesDashboardConfig>|nil Named dashboard configurations

---@type BasesConfig
local config = {
    vault_path = nil,
    render_markdown = false,
    date_format = '%Y-%m-%d',
    date_format_relative = false,
    keymaps = {
        follow_link = '<CR>',
        next_link = '<Tab>',
        prev_link = '<S-Tab>',
        refresh = 'R',
        edit_cell = 'c',
        edit_source = 'E',
        select_view = 'v',
        debug = '?',
    },
    inline = {
        enabled = true,
        auto_render = true,
        keymaps = {
            follow_link = '<CR>',
            next_link = '<Tab>',
            prev_link = '<S-Tab>',
            refresh = '<leader>br',
            edit_cell = 'c',
            edit_source = 'E',
        },
    },
    dashboards = nil,
}

---Setup the plugin
---@param opts BasesConfig|nil User configuration
function M.setup(opts)
    opts = opts or {}

    -- Merge user config
    if opts.host or opts.port or opts.api_key then
        vim.notify('bases.nvim: host/port/api_key config is deprecated. The native engine reads vault files directly.', vim.log.levels.WARN)
    end

    config.vault_path = opts.vault_path
    if opts.render_markdown ~= nil then
        config.render_markdown = opts.render_markdown
    end
    if opts.date_format ~= nil then
        config.date_format = opts.date_format
    end
    if opts.date_format_relative ~= nil then
        config.date_format_relative = opts.date_format_relative
    end

    -- Merge keymap config
    if opts.keymaps then
        for action, _ in pairs(config.keymaps) do
            local user_key = opts.keymaps[action]
            if user_key == false then
                config.keymaps[action] = false
            elseif user_key ~= nil then
                config.keymaps[action] = user_key
            end
        end
    end

    -- Merge inline config
    if opts.inline then
        if opts.inline.enabled ~= nil then
            config.inline.enabled = opts.inline.enabled
        end
        if opts.inline.auto_render ~= nil then
            config.inline.auto_render = opts.inline.auto_render
        end
        if opts.inline.keymaps then
            for action, _ in pairs(config.inline.keymaps) do
                local user_key = opts.inline.keymaps[action]
                if user_key == false then
                    config.inline.keymaps[action] = false
                elseif user_key ~= nil then
                    config.inline.keymaps[action] = user_key
                end
            end
        end
    end

    -- Merge dashboard config
    if opts.dashboards then
        config.dashboards = opts.dashboards
    end

    -- Create highlight groups
    vim.api.nvim_set_hl(0, 'BasesLink', { link = 'Underlined', default = true })
    vim.api.nvim_set_hl(0, 'BasesHeader', { link = 'Title', default = true })
    vim.api.nvim_set_hl(0, 'BasesBorder', { link = 'Comment', default = true })
    vim.api.nvim_set_hl(0, 'BasesEditable', { link = 'String', default = true })
    vim.api.nvim_set_hl(0, 'BasesSortedHeader', { link = 'Special', default = true })
    vim.api.nvim_set_hl(0, 'BasesDashboardTitle', { link = 'Title', default = true })
    vim.api.nvim_set_hl(0, 'BasesDashboardSectionTitle', { link = 'Label', default = true })
    vim.api.nvim_set_hl(0, 'BasesSummary', { link = 'Comment', default = true })

    -- Setup inline rendering
    if config.inline.enabled then
        require('bases.inline').setup()
    end

    -- Resolve vault path but defer engine initialization to first use
    local vault = config.vault_path
    if not vault then
        -- Auto-detect from obsidian.nvim
        if Obsidian and Obsidian.dir then
            vault = tostring(Obsidian.dir)
        end
    end
    if vault then
        local engine = require('bases.engine')
        engine.set_vault_path(vault)
    else
        vim.notify('bases.nvim: vault_path not configured. Set vault_path in require("bases").setup()', vim.log.levels.WARN)
    end
end

---Extract base name from file path
---@param base_path string Path to .base file
---@return string Base name without extension
local function extract_base_name(base_path)
    -- Get filename from path
    local filename = base_path:match('([^/\\]+)$') or base_path
    -- Remove .base extension
    return filename:gsub('%.base$', '')
end

---Setup buffer-local keymaps
---@param buf number Buffer handle
function M.setup_keymaps(buf)
    local nav = require('bases.navigation')
    local edit = require('bases.edit')

    local keymaps = config.keymaps
    local map_opts = { buffer = buf, silent = true }

    -- Follow link under cursor
    if keymaps.follow_link then
        vim.keymap.set('n', keymaps.follow_link, function()
            nav.follow_link(buf)
        end, map_opts)
    end

    -- Navigate between links
    if keymaps.next_link then
        vim.keymap.set('n', keymaps.next_link, function()
            nav.next_link(buf)
        end, map_opts)
    end

    if keymaps.prev_link then
        vim.keymap.set('n', keymaps.prev_link, function()
            nav.prev_link(buf)
        end, map_opts)
    end

    -- Refresh
    if keymaps.refresh then
        vim.keymap.set('n', keymaps.refresh, function()
            M.refresh(buf)
        end, map_opts)
    end

    -- Edit cell under cursor
    if keymaps.edit_cell then
        vim.keymap.set('n', keymaps.edit_cell, function()
            edit.edit_cell(buf)
        end, map_opts)
    end

    -- Edit source file
    if keymaps.edit_source then
        vim.keymap.set('n', keymaps.edit_source, function()
            require('bases.source_edit').edit_source(buf)
        end, map_opts)
    end

    -- Select view
    if keymaps.select_view then
        vim.keymap.set('n', keymaps.select_view, function()
            require('bases.views').select_view(buf)
        end, map_opts)
    end

    -- Debug info
    if keymaps.debug then
        vim.keymap.set('n', keymaps.debug, function()
            require('bases.debug').show(buf)
        end, map_opts)
    end
end

---Open and render a base file
---@param base_path string Path to .base file
---@param existing_buf number|nil Pre-existing buffer to render into (from BufReadCmd)
function M.open(base_path, existing_buf)
    local engine = require('bases.engine')
    local buffer = require('bases.buffer')
    local render = require('bases.render')

    local base_name = extract_base_name(base_path)
    local buf
    if existing_buf and vim.api.nvim_buf_is_valid(existing_buf) then
        buf = existing_buf
        buffer.configure(buf, base_path)
    else
        buf = buffer.get_or_create(base_path)
    end

    -- Switch to the buffer
    vim.api.nvim_set_current_buf(buf)

    -- Setup keymaps
    M.setup_keymaps(buf)

    -- Show loading state
    buffer.set_loading(buf, base_name)

    -- Defer query until engine is ready
    engine.on_ready(function(init_err)
        if init_err then
            buffer.set_error(buf, init_err)
            return
        end

        -- Get stored view index
        local view_index = vim.b[buf].bases_view_index or 0

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
    end)
end

---Refresh the current base buffer
---@param buf number|nil Buffer handle (default: current buffer)
---@param opts table|nil Options: { silent = boolean }
function M.refresh(buf, opts)
    buf = buf or vim.api.nvim_get_current_buf()
    opts = opts or {}

    local base_path = vim.b[buf].bases_path
    if not base_path then
        vim.notify('Not a bases buffer', vim.log.levels.WARN)
        return
    end

    local engine = require('bases.engine')
    local buffer = require('bases.buffer')
    local render = require('bases.render')

    local base_name = extract_base_name(base_path)

    -- Notify user refresh is starting (keep old content visible)
    if not opts.silent then
        vim.notify('Refreshing ' .. base_name .. '...', vim.log.levels.INFO)
    end

    -- Get stored view index
    local view_index = vim.b[buf].bases_view_index or 0

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
        if not opts.silent then
            vim.notify(base_name .. ' refreshed', vim.log.levels.INFO)
        end
    end)
end

---Get the current configuration
---@return BasesConfig
function M.get_config()
    return vim.deepcopy(config)
end

---Enable inline rendering (if not already enabled)
function M.enable_inline()
    if not config.inline.enabled then
        config.inline.enabled = true
        require('bases.inline').setup()
    end
end

---Render inline bases in a buffer
---@param buf number|nil Buffer handle (default: current buffer)
function M.render_inline(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    require('bases.inline').render_buffer(buf)
end

---Refresh inline bases in a buffer
---@param buf number|nil Buffer handle (default: current buffer)
---@param opts table|nil Options: { silent = boolean }
function M.refresh_inline(buf, opts)
    buf = buf or vim.api.nvim_get_current_buf()
    require('bases.inline').refresh_buffer(buf, opts)
end

---Open a named dashboard
---@param name string Dashboard name from setup() config
function M.open_dashboard(name)
    require('bases.dashboard').open(name)
end

---Refresh the current dashboard buffer
---@param buf number|nil Buffer handle (default: current buffer)
---@param opts table|nil Options: { silent = boolean }
function M.refresh_dashboard(buf, opts)
    require('bases.dashboard').refresh(buf, opts)
end

---Refresh all open base-related buffers (standalone, dashboard, inline)
---@param opts table|nil Options forwarded to each refresh call
function M.refresh_all_buffers(opts)
    local engine = require('bases.engine')
    if not engine.is_ready() then
        return
    end

    opts = opts or { silent = true }

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            if vim.b[buf].bases_path then
                M.refresh(buf, opts)
            elseif vim.b[buf].bases_dashboard_name then
                M.refresh_dashboard(buf, opts)
            elseif vim.b[buf].bases_inline_embeds then
                M.refresh_inline(buf, opts)
            end
        end
    end
end

---List available dashboard names
---@return string[] Dashboard names
function M.list_dashboards()
    local dashboards = config.dashboards or {}
    local names = {}
    for name, _ in pairs(dashboards) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

return M
