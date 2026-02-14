-- Test bootstrap for bases.nvim
-- Run with: make test
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(plugin_dir)

-- Add mini.nvim for test framework
vim.opt.runtimepath:prepend(plugin_dir .. "/deps/mini.nvim")

-- Discover and run all test files
local MiniTest = require("mini.test")
MiniTest.setup()

-- Collect and run tests
local test_files = vim.fn.glob(plugin_dir .. "/tests/unit/test_*.lua", true, true)
for _, f in ipairs(vim.fn.glob(plugin_dir .. "/tests/integration/test_*.lua", true, true)) do
  table.insert(test_files, f)
end

for _, test_file in ipairs(test_files) do
  dofile(test_file)
end

MiniTest.run()
