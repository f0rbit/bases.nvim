-- Test bootstrap: add plugin and mini.nvim to runtimepath
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. '/deps/mini.nvim')

-- Disable swap files for test buffers
vim.o.swapfile = false

require('mini.test').setup()

-- Discover and run all test files
MiniTest.run({ collect = { find_files = function()
  return vim.fn.globpath(root .. '/tests', '**/test_*.lua', true, true)
end } })
