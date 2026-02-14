-- Run a subset of tests: nvim --headless -u NONE -l tests/run_subset.lua unit
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(plugin_dir)
vim.opt.runtimepath:prepend(plugin_dir .. "/deps/mini.nvim")

local subset = arg and arg[1] or "unit"
local MiniTest = require("mini.test")
MiniTest.setup()

local test_files = vim.fn.glob(plugin_dir .. "/tests/" .. subset .. "/test_*.lua", true, true)
for _, test_file in ipairs(test_files) do
  dofile(test_file)
end

MiniTest.run()
