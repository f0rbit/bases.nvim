-- Autocommand to handle .base files
if vim.g.loaded_bases then
    return
end
vim.g.loaded_bases = true

vim.api.nvim_create_autocmd('BufReadCmd', {
    pattern = '*.base',
    callback = function(args)
        require('bases').open(args.file, args.buf)
    end,
    desc = 'Open Obsidian Base files with bases.nvim',
})

-- Dashboard command with completion
vim.api.nvim_create_user_command('BasesDashboard', function(opts)
    local name = opts.args
    if name == '' then
        local dashboards = require('bases').list_dashboards()
        if #dashboards == 0 then
            vim.notify('No dashboards configured. Add dashboards to require("bases").setup()', vim.log.levels.WARN)
        else
            vim.notify('Available dashboards: ' .. table.concat(dashboards, ', '), vim.log.levels.INFO)
        end
        return
    end
    require('bases').open_dashboard(name)
end, {
    nargs = '?',
    complete = function(_, _, _)
        return require('bases').list_dashboards()
    end,
    desc = 'Open a bases dashboard',
})

-- Save cache and stop file watcher on exit
vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
        require('bases.engine').shutdown()
    end,
    desc = 'Save bases cache and stop file watcher on exit',
})

-- Auto-refresh bases when any file is saved
vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*',
    callback = function(ev)
        local engine = require('bases.engine')
        if not engine.is_ready() then
            return
        end

        local vault = engine.get_vault_path()
        if not vault then
            return
        end

        local abs_path = vim.api.nvim_buf_get_name(ev.buf)
        local prefix = vault .. '/'

        if vim.startswith(abs_path, prefix) then
            -- Re-index the saved file, then refresh all base buffers
            local rel_path = abs_path:sub(#prefix + 1)
            engine.update_file(rel_path, function()
                require('bases').refresh_all_buffers()
            end)
        else
            -- File outside vault — still refresh in case views changed
            require('bases').refresh_all_buffers()
        end
    end,
    desc = 'Re-index and refresh bases on file save',
})
