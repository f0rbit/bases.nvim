local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local buffer = require('bases.buffer')

-- Track buffers for cleanup
local test_bufs = {}

-- =======================
-- Helper Functions
-- =======================

local function track(buf)
  table.insert(test_bufs, buf)
  return buf
end

-- =======================
-- Test Setup
-- =======================

local T = new_set({
  hooks = {
    post_case = function()
      for _, buf in ipairs(test_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      test_bufs = {}
    end,
  },
})

-- =======================
-- get_or_create: Creates Buffer
-- =======================

T['get_or_create'] = new_set()

T['get_or_create']['creates buffer'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  expect.equality(type(buf), 'number')
  expect.equality(vim.api.nvim_buf_is_valid(buf), true)
end

T['get_or_create']['sets buffer name'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  local name = vim.api.nvim_buf_get_name(buf)
  expect.equality(name, 'base://test/path.base')
end

T['get_or_create']['sets buftype to nofile'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  expect.equality(vim.bo[buf].buftype, 'nofile')
end

T['get_or_create']['sets bufhidden to hide'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  expect.equality(vim.bo[buf].bufhidden, 'hide')
end

T['get_or_create']['sets swapfile to false'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  expect.equality(vim.bo[buf].swapfile, false)
end

T['get_or_create']['sets modifiable to false'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  expect.equality(vim.bo[buf].modifiable, false)
end

T['get_or_create']['sets filetype to obsidian_base'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  expect.equality(vim.bo[buf].filetype, 'obsidian_base')
end

T['get_or_create']['sets bases_path buffer variable'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  expect.equality(vim.b[buf].bases_path, 'test/path.base')
end

-- =======================
-- get_or_create: Idempotent
-- =======================

T['get_or_create']['returns same buffer on second call'] = function()
  local buf1 = track(buffer.get_or_create('test/same-path.base'))
  local buf2 = buffer.get_or_create('test/same-path.base')
  expect.equality(buf1, buf2)
end

T['get_or_create']['creates different buffers for different paths'] = function()
  local buf1 = track(buffer.get_or_create('test/path1.base'))
  local buf2 = track(buffer.get_or_create('test/path2.base'))
  expect.no_equality(buf1, buf2)
end

-- =======================
-- configure: Sets Buffer Options
-- =======================

T['configure'] = new_set()

T['configure']['sets buftype on existing buffer'] = function()
  local buf = track(vim.api.nvim_create_buf(false, false))
  buffer.configure(buf, 'test/path.base')
  expect.equality(vim.bo[buf].buftype, 'nofile')
end

T['configure']['sets bufhidden on existing buffer'] = function()
  local buf = track(vim.api.nvim_create_buf(false, false))
  buffer.configure(buf, 'test/path.base')
  expect.equality(vim.bo[buf].bufhidden, 'hide')
end

T['configure']['sets swapfile on existing buffer'] = function()
  local buf = track(vim.api.nvim_create_buf(false, false))
  buffer.configure(buf, 'test/path.base')
  expect.equality(vim.bo[buf].swapfile, false)
end

T['configure']['sets modifiable on existing buffer'] = function()
  local buf = track(vim.api.nvim_create_buf(false, false))
  buffer.configure(buf, 'test/path.base')
  expect.equality(vim.bo[buf].modifiable, false)
end

T['configure']['sets filetype on existing buffer'] = function()
  local buf = track(vim.api.nvim_create_buf(false, false))
  buffer.configure(buf, 'test/path.base')
  expect.equality(vim.bo[buf].filetype, 'obsidian_base')
end

T['configure']['sets bases_path on existing buffer'] = function()
  local buf = track(vim.api.nvim_create_buf(false, false))
  buffer.configure(buf, 'test/path.base')
  expect.equality(vim.b[buf].bases_path, 'test/path.base')
end

-- =======================
-- set_loading: Loading Message
-- =======================

T['set_loading'] = new_set()

T['set_loading']['sets loading message'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_loading(buf, 'My Base')
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(#lines, 2)
  expect.equality(lines[1], '')
  expect.equality(lines[2], '  Loading My Base...')
end

T['set_loading']['buffer remains unmodifiable'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_loading(buf, 'My Base')
  expect.equality(vim.bo[buf].modifiable, false)
end

-- =======================
-- set_error: Error Message
-- =======================

T['set_error'] = new_set()

T['set_error']['sets error header and footer'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_error(buf, 'Something went wrong')
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(lines[1], '')
  expect.equality(lines[2], '  Error loading base:')
  expect.equality(lines[3], '')
  expect.equality(lines[4], '  Something went wrong')
  expect.equality(lines[5], '')
  expect.equality(lines[6], '  Press R to retry')
end

T['set_error']['handles multiline error messages'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_error(buf, 'Line 1\nLine 2\nLine 3')
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(lines[2], '  Error loading base:')
  expect.equality(lines[4], '  Line 1')
  expect.equality(lines[5], '  Line 2')
  expect.equality(lines[6], '  Line 3')
  local last_line = lines[#lines]
  expect.equality(last_line, '  Press R to retry')
end

T['set_error']['buffer remains unmodifiable'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_error(buf, 'Error message')
  expect.equality(vim.bo[buf].modifiable, false)
end

-- =======================
-- set_content: Sets Lines and Filetype
-- =======================

T['set_content'] = new_set()

T['set_content']['sets buffer lines'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_content(buf, { 'Line 1', 'Line 2', 'Line 3' })
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(#lines, 3)
  expect.equality(lines[1], 'Line 1')
  expect.equality(lines[2], 'Line 2')
  expect.equality(lines[3], 'Line 3')
end

T['set_content']['sets default filetype to obsidian_base'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_content(buf, { 'content' })
  expect.equality(vim.bo[buf].filetype, 'obsidian_base')
end

T['set_content']['sets custom filetype when provided'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_content(buf, { 'content' }, 'markdown')
  expect.equality(vim.bo[buf].filetype, 'markdown')
end

T['set_content']['buffer remains unmodifiable'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_content(buf, { 'content' })
  expect.equality(vim.bo[buf].modifiable, false)
end

T['set_content']['can set empty content'] = function()
  local buf = track(buffer.get_or_create('test/path.base'))
  buffer.set_content(buf, {})
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(#lines, 1)
  expect.equality(lines[1], '')
end

return T
