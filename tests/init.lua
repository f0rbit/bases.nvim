-- Test bootstrap for bases.nvim
-- Run with: nvim --headless -u tests/init.lua -c "qa"
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(plugin_dir)
