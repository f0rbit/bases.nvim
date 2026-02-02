-- Selective test runner: pass "unit" or "integration" as argument
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. '/deps/mini.nvim')

vim.o.swapfile = false

require('mini.test').setup()

local subset = arg and arg[1] or 'unit'
local pattern = root .. '/tests/' .. subset

MiniTest.run({ collect = { find_files = function()
  return vim.fn.globpath(pattern, '**/test_*.lua', true, true)
end } })
