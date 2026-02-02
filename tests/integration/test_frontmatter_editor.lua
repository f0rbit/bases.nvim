local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local editor = require('bases.engine.frontmatter_editor')

-- Track temp files for cleanup
local temp_files = {}

-- =======================
-- Helper Functions
-- =======================

-- Helper to create a temp file with content
local function write_temp(content)
  local path = vim.fn.tempname() .. '.md'
  local lines = {}
  for line in content:gmatch('[^\n]*') do
    table.insert(lines, line)
  end
  -- Remove trailing empty from split
  if #lines > 0 and lines[#lines] == '' then
    table.remove(lines)
  end
  vim.fn.writefile(lines, path)
  return path
end

-- Helper to read file content
local function read_file(path)
  local lines = vim.fn.readfile(path)
  return table.concat(lines, '\n')
end

-- Helper that auto-tracks for cleanup
local function make_temp(content)
  local path = write_temp(content)
  table.insert(temp_files, path)
  return path
end

-- =======================
-- Test Setup
-- =======================

local T = new_set({
  hooks = {
    post_case = function()
      for _, path in ipairs(temp_files) do
        vim.fn.delete(path)
      end
      temp_files = {}
    end,
  },
})

-- =======================
-- update_field: Update Existing Fields
-- =======================

T['update_field'] = new_set()

T['update_field']['updates existing string field'] = function()
  local path = make_temp('---\nstatus: active\npriority: 1\n---\n\n# Note')
  local ok, err = editor.update_field(path, 'status', 'complete')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  -- should contain new value
  expect.no_equality(content:find('status: complete'), nil)
  -- should not contain old value
  expect.equality(content:find('status: active'), nil)
end

T['update_field']['updates existing number field'] = function()
  local path = make_temp('---\nstatus: active\npriority: 1\n---\n\n# Note')
  local ok, err = editor.update_field(path, 'priority', 5)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('priority: 5'), nil)
  expect.equality(content:find('priority: 1'), nil)
end

-- =======================
-- update_field: Add New Fields
-- =======================

T['update_field']['adds new field to existing frontmatter'] = function()
  local path = make_temp('---\nstatus: active\n---\n\n# Note')
  local ok, err = editor.update_field(path, 'priority', 2)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('priority: 2'), nil)
  expect.no_equality(content:find('status: active'), nil)
end

-- =======================
-- update_field: Delete Fields
-- =======================

T['update_field']['deletes field with nil value'] = function()
  local path = make_temp('---\nstatus: active\npriority: 1\n---\n\n# Note')
  local ok, err = editor.update_field(path, 'priority', nil)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.equality(content:find('priority'), nil)
  expect.no_equality(content:find('status: active'), nil)
end

T['update_field']['deletes field with vim.NIL value'] = function()
  local path = make_temp('---\nstatus: active\npriority: 1\n---\n\n# Note')
  local ok, err = editor.update_field(path, 'priority', vim.NIL)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.equality(content:find('priority'), nil)
  expect.no_equality(content:find('status: active'), nil)
end

T['update_field']['delete from non-existent frontmatter is no-op success'] = function()
  local path = make_temp('# Note without frontmatter')
  local ok, err = editor.update_field(path, 'status', nil)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.equality(content, '# Note without frontmatter')
end

-- =======================
-- update_field: Create Frontmatter
-- =======================

T['update_field']['creates frontmatter on file without one'] = function()
  local path = make_temp('# Note without frontmatter\n\nSome content.')
  local ok, err = editor.update_field(path, 'status', 'active')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  -- Should have frontmatter delimiters
  expect.no_equality(content:find('^---\n'), nil)
  expect.no_equality(content:find('status: active'), nil)
  -- Should preserve original content
  expect.no_equality(content:find('# Note without frontmatter'), nil)
  expect.no_equality(content:find('Some content.'), nil)
end

T['update_field']['creates frontmatter on empty file'] = function()
  local path = make_temp('')
  local ok, err = editor.update_field(path, 'status', 'active')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('^---\n'), nil)
  expect.no_equality(content:find('status: active'), nil)
end

-- =======================
-- update_field: Boolean Values
-- =======================

T['update_field']['writes boolean true value'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'complete', true)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('complete: true'), nil)
end

T['update_field']['writes boolean false value'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'archived', false)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('archived: false'), nil)
end

-- =======================
-- update_field: Number Values
-- =======================

T['update_field']['writes integer value'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'count', 42)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('count: 42'), nil)
end

T['update_field']['writes decimal value'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'price', 19.99)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('price: 19.99'), nil)
end

T['update_field']['writes negative number'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'delta', -5)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('delta: %-5'), nil)
end

-- =======================
-- update_field: Quoted Strings
-- =======================

T['update_field']['quotes string that looks like boolean'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'text', 'true')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('text: "true"'), nil)
end

T['update_field']['quotes string that looks like number'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'code', '123')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('code: "123"'), nil)
end

T['update_field']['quotes empty string'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'empty', '')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('empty: ""'), nil)
end

T['update_field']['quotes wikilink string'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'link', '[[Project A]]')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('link: "%[%[Project A%]%]"'), nil)
end

T['update_field']['quotes string with colon space'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'note', 'Title: Value')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('note: "Title: Value"'), nil)
end

T['update_field']['quotes string with leading whitespace'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'text', '  indented')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('text: "  indented"'), nil)
end

T['update_field']['quotes string with trailing whitespace'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'text', 'trailing  ')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('text: "trailing  "'), nil)
end

T['update_field']['handles string with internal quotes'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'quote', 'say "hello"')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  -- Internal quotes alone don't trigger quoting in YAML
  expect.no_equality(content:find('quote: say "hello"'), nil)
end

T['update_field']['does not quote plain string'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'name', 'project-alpha')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('name: project%-alpha'), nil)
  -- Should not be quoted
  expect.equality(content:find('name: "project'), nil)
end

-- =======================
-- update_field: List/Table Values
-- =======================

T['update_field']['writes list of strings'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'tags', { 'project', 'important', 'review' })
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('tags:'), nil)
  expect.no_equality(content:find('  %- project'), nil)
  expect.no_equality(content:find('  %- important'), nil)
  expect.no_equality(content:find('  %- review'), nil)
end

T['update_field']['writes list of numbers'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'values', { 1, 2, 3 })
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('values:'), nil)
  expect.no_equality(content:find('  %- 1'), nil)
  expect.no_equality(content:find('  %- 2'), nil)
  expect.no_equality(content:find('  %- 3'), nil)
end

T['update_field']['writes list of booleans'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'flags', { true, false, true })
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('flags:'), nil)
  expect.no_equality(content:find('  %- true'), nil)
  expect.no_equality(content:find('  %- false'), nil)
end

T['update_field']['writes list with quoted strings'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'links', { '[[Note A]]', '[[Note B]]' })
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('links:'), nil)
  expect.no_equality(content:find('  %- "%[%[Note A%]%]"'), nil)
  expect.no_equality(content:find('  %- "%[%[Note B%]%]"'), nil)
end

T['update_field']['writes empty list'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'empty', {})
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('empty: %[%]'), nil)
end

-- =======================
-- update_field: Validation Errors
-- =======================

T['update_field']['returns error for empty file path'] = function()
  local ok, err = editor.update_field('', 'status', 'active')
  expect.equality(ok, false)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('file_path is required'), nil)
end

T['update_field']['returns error for nil file path'] = function()
  local ok, err = editor.update_field(nil, 'status', 'active')
  expect.equality(ok, false)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('file_path is required'), nil)
end

T['update_field']['returns error for empty field name'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, '', 'active')
  expect.equality(ok, false)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('field_name is required'), nil)
end

T['update_field']['returns error for nil field name'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, nil, 'active')
  expect.equality(ok, false)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('field_name is required'), nil)
end

T['update_field']['returns error for field name with colon'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'bad:field', 'active')
  expect.equality(ok, false)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('cannot contain'), nil)
end

T['update_field']['returns error for field name with space'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'bad field', 'active')
  expect.equality(ok, false)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('cannot contain'), nil)
end

T['update_field']['returns error for field name with hash'] = function()
  local path = make_temp('---\nstatus: active\n---\n')
  local ok, err = editor.update_field(path, 'bad#field', 'active')
  expect.equality(ok, false)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('cannot contain'), nil)
end

-- =======================
-- update_field: Content Preservation
-- =======================

T['update_field']['preserves content after frontmatter'] = function()
  local path = make_temp('---\nstatus: active\n---\n\n# My Note\n\nContent here.')
  local ok, err = editor.update_field(path, 'priority', 1)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('# My Note'), nil)
  expect.no_equality(content:find('Content here.'), nil)
  expect.no_equality(content:find('priority: 1'), nil)
end

T['update_field']['preserves closing delimiter type'] = function()
  local path = make_temp('---\nstatus: active\n...\n\n# Note')
  local ok, err = editor.update_field(path, 'priority', 1)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  -- Should preserve ... delimiter
  expect.no_equality(content:find('%.%.%.'), nil)
end

T['update_field']['preserves multiple fields order when updating one'] = function()
  local path = make_temp('---\ntitle: Test\nstatus: active\npriority: 1\nauthor: Alice\n---\n')
  local ok, err = editor.update_field(path, 'status', 'complete')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  local lines = vim.split(content, '\n')
  -- Check order is preserved
  local title_idx = nil
  local status_idx = nil
  local priority_idx = nil
  local author_idx = nil
  for i, line in ipairs(lines) do
    if line:match('^title:') then
      title_idx = i
    elseif line:match('^status:') then
      status_idx = i
    elseif line:match('^priority:') then
      priority_idx = i
    elseif line:match('^author:') then
      author_idx = i
    end
  end
  expect.no_equality(title_idx, nil)
  expect.no_equality(status_idx, nil)
  expect.no_equality(priority_idx, nil)
  expect.no_equality(author_idx, nil)
  -- Order should be title < status < priority < author
  expect.equality(title_idx < status_idx, true)
  expect.equality(status_idx < priority_idx, true)
  expect.equality(priority_idx < author_idx, true)
end

-- =======================
-- update_field: Multi-line Field Replacement
-- =======================

T['update_field']['replaces multi-line list field with scalar'] = function()
  local path = make_temp('---\nstatus: active\ntags:\n  - project\n  - important\npriority: 1\n---\n')
  local ok, err = editor.update_field(path, 'tags', 'single-tag')
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('tags: single%-tag'), nil)
  -- Old list items should be gone
  expect.equality(content:find('  %- project'), nil)
  expect.equality(content:find('  %- important'), nil)
  -- Other fields should be preserved
  expect.no_equality(content:find('status: active'), nil)
  expect.no_equality(content:find('priority: 1'), nil)
end

T['update_field']['replaces scalar field with multi-line list'] = function()
  local path = make_temp('---\nstatus: active\ntag: project\npriority: 1\n---\n')
  local ok, err = editor.update_field(path, 'tag', { 'project', 'important', 'review' })
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('tag:'), nil)
  expect.no_equality(content:find('  %- project'), nil)
  expect.no_equality(content:find('  %- important'), nil)
  expect.no_equality(content:find('  %- review'), nil)
  -- Old scalar should be gone
  expect.equality(content:find('tag: project'), nil)
end

T['update_field']['replaces list field with another list'] = function()
  local path = make_temp('---\ntags:\n  - old1\n  - old2\n---\n')
  local ok, err = editor.update_field(path, 'tags', { 'new1', 'new2', 'new3' })
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.no_equality(content:find('  %- new1'), nil)
  expect.no_equality(content:find('  %- new2'), nil)
  expect.no_equality(content:find('  %- new3'), nil)
  -- Old items should be gone
  expect.equality(content:find('old1'), nil)
  expect.equality(content:find('old2'), nil)
end

T['update_field']['deletes multi-line list field'] = function()
  local path = make_temp('---\nstatus: active\ntags:\n  - project\n  - important\npriority: 1\n---\n')
  local ok, err = editor.update_field(path, 'tags', nil)
  expect.equality(ok, true)
  expect.equality(err, nil)
  local content = read_file(path)
  expect.equality(content:find('tags:'), nil)
  expect.equality(content:find('  %- project'), nil)
  expect.equality(content:find('  %- important'), nil)
  -- Other fields should be preserved
  expect.no_equality(content:find('status: active'), nil)
  expect.no_equality(content:find('priority: 1'), nil)
end

return T
