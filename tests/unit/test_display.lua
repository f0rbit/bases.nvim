local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- Mock bases config (needed by render.lua which display.lua requires)
package.loaded['bases'] = {
  get_config = function()
    return { date_format = '%Y-%m-%d', date_format_relative = false }
  end,
}

local display = require('bases.display')

local T = new_set()

-- =======================
-- Helper: Sample Raw Data
-- =======================

local function make_raw_data()
  return {
    properties = { 'file.name', 'note.status', 'note.priority' },
    entries = {
      {
        file = { path = 'a.md', name = 'a.md', basename = 'a' },
        values = { ['note.priority'] = { type = 'primitive', value = 2 } },
      },
      {
        file = { path = 'b.md', name = 'b.md', basename = 'b' },
        values = { ['note.priority'] = { type = 'primitive', value = 1 } },
      },
      {
        file = { path = 'c.md', name = 'c.md', basename = 'c' },
        values = { ['note.priority'] = { type = 'primitive', value = 3 } },
      },
    },
    propertyLabels = { ['note.status'] = 'Status' },
    summaries = { ['note.priority'] = { label = 'Sum', value = { type = 'primitive', value = 6 } } },
  }
end

-- =======================
-- M.prepare
-- =======================

T['prepare'] = new_set()

T['prepare']['passthrough no sort no limit'] = function()
  local raw_data = make_raw_data()
  local result = display.prepare(raw_data, {})

  expect.equality(#result.entries, 3)
  expect.equality(result.entries[1].file.path, 'a.md')
  expect.equality(result.entries[2].file.path, 'b.md')
  expect.equality(result.entries[3].file.path, 'c.md')
  expect.equality(result.sort_state, nil)
end

T['prepare']['user sort applied'] = function()
  local raw_data = make_raw_data()
  local view_state = { sort = { property = 'note.priority', direction = 'asc' } }
  local result = display.prepare(raw_data, view_state)

  expect.equality(#result.entries, 3)
  -- Sorted ascending by priority: 1, 2, 3
  expect.equality(result.entries[1].file.path, 'b.md')
  expect.equality(result.entries[2].file.path, 'a.md')
  expect.equality(result.entries[3].file.path, 'c.md')
  expect.equality(result.sort_state.property, 'note.priority')
  expect.equality(result.sort_state.direction, 'asc')
end

T['prepare']['user sort descending'] = function()
  local raw_data = make_raw_data()
  local view_state = { sort = { property = 'note.priority', direction = 'desc' } }
  local result = display.prepare(raw_data, view_state)

  expect.equality(#result.entries, 3)
  -- Sorted descending by priority: 3, 2, 1
  expect.equality(result.entries[1].file.path, 'c.md')
  expect.equality(result.entries[2].file.path, 'a.md')
  expect.equality(result.entries[3].file.path, 'b.md')
  expect.equality(result.sort_state.property, 'note.priority')
  expect.equality(result.sort_state.direction, 'desc')
end

T['prepare']['default sort fallback'] = function()
  local raw_data = make_raw_data()
  raw_data.defaultSort = { property = 'note.priority', direction = 'asc' }
  local result = display.prepare(raw_data, {})

  expect.equality(#result.entries, 3)
  -- Sorted ascending by priority: 1, 2, 3
  expect.equality(result.entries[1].file.path, 'b.md')
  expect.equality(result.entries[2].file.path, 'a.md')
  expect.equality(result.entries[3].file.path, 'c.md')
  expect.equality(result.sort_state.property, 'note.priority')
  expect.equality(result.sort_state.direction, 'asc')
end

T['prepare']['user sort overrides default'] = function()
  local raw_data = make_raw_data()
  raw_data.defaultSort = { property = 'note.priority', direction = 'asc' }
  local view_state = { sort = { property = 'note.priority', direction = 'desc' } }
  local result = display.prepare(raw_data, view_state)

  expect.equality(#result.entries, 3)
  -- User sort (desc) wins: 3, 2, 1
  expect.equality(result.entries[1].file.path, 'c.md')
  expect.equality(result.entries[2].file.path, 'a.md')
  expect.equality(result.entries[3].file.path, 'b.md')
  expect.equality(result.sort_state.property, 'note.priority')
  expect.equality(result.sort_state.direction, 'desc')
end

T['prepare']['limit after sort'] = function()
  local raw_data = make_raw_data()
  raw_data.defaultSort = { property = 'note.priority', direction = 'asc' }
  raw_data.limit = 2
  local result = display.prepare(raw_data, {})

  -- First 2 entries after ascending sort: priority 1, 2
  expect.equality(#result.entries, 2)
  expect.equality(result.entries[1].file.path, 'b.md')
  expect.equality(result.entries[2].file.path, 'a.md')
end

T['prepare']['view state limit overrides raw data limit'] = function()
  local raw_data = make_raw_data()
  raw_data.limit = 3
  local view_state = { limit = 1 }
  local result = display.prepare(raw_data, view_state)

  expect.equality(#result.entries, 1)
  expect.equality(result.entries[1].file.path, 'a.md')
end

T['prepare']['limit with no sort preserves order'] = function()
  local raw_data = make_raw_data()
  raw_data.limit = 2
  local result = display.prepare(raw_data, {})

  -- First 2 entries in original order
  expect.equality(#result.entries, 2)
  expect.equality(result.entries[1].file.path, 'a.md')
  expect.equality(result.entries[2].file.path, 'b.md')
end

T['prepare']['no entries'] = function()
  local raw_data = make_raw_data()
  raw_data.entries = {}
  local result = display.prepare(raw_data, {})

  expect.equality(#result.entries, 0)
  expect.equality(result.properties[1], 'file.name')
  expect.equality(result.sort_state, nil)
end

T['prepare']['empty sort property does not sort'] = function()
  local raw_data = make_raw_data()
  local view_state = { sort = { property = '', direction = 'asc' } }
  local result = display.prepare(raw_data, view_state)

  -- No sort applied, original order preserved
  expect.equality(#result.entries, 3)
  expect.equality(result.entries[1].file.path, 'a.md')
  expect.equality(result.entries[2].file.path, 'b.md')
  expect.equality(result.entries[3].file.path, 'c.md')
end

T['prepare']['nil view state'] = function()
  local raw_data = make_raw_data()
  local result = display.prepare(raw_data, nil)

  expect.equality(#result.entries, 3)
  expect.equality(result.entries[1].file.path, 'a.md')
  expect.equality(result.sort_state, nil)
end

T['prepare']['sort state forwarded'] = function()
  local raw_data = make_raw_data()
  raw_data.defaultSort = { property = 'note.priority', direction = 'desc' }
  local result = display.prepare(raw_data, {})

  expect.equality(result.sort_state.property, 'note.priority')
  expect.equality(result.sort_state.direction, 'desc')
end

T['prepare']['property labels forwarded'] = function()
  local raw_data = make_raw_data()
  local result = display.prepare(raw_data, {})

  expect.equality(result.property_labels['note.status'], 'Status')
end

T['prepare']['summaries forwarded'] = function()
  local raw_data = make_raw_data()
  local result = display.prepare(raw_data, {})

  expect.equality(result.summaries['note.priority'].label, 'Sum')
  expect.equality(result.summaries['note.priority'].value.value, 6)
end

T['prepare']['properties forwarded'] = function()
  local raw_data = make_raw_data()
  local result = display.prepare(raw_data, {})

  expect.equality(#result.properties, 3)
  expect.equality(result.properties[1], 'file.name')
  expect.equality(result.properties[2], 'note.status')
  expect.equality(result.properties[3], 'note.priority')
end

T['prepare']['limit zero does not truncate'] = function()
  local raw_data = make_raw_data()
  raw_data.limit = 0
  local result = display.prepare(raw_data, {})

  expect.equality(#result.entries, 3)
end

T['prepare']['limit negative does not truncate'] = function()
  local raw_data = make_raw_data()
  raw_data.limit = -1
  local result = display.prepare(raw_data, {})

  expect.equality(#result.entries, 3)
end

T['prepare']['limit greater than entries count'] = function()
  local raw_data = make_raw_data()
  raw_data.limit = 10
  local result = display.prepare(raw_data, {})

  expect.equality(#result.entries, 3)
end

T['prepare']['limit exactly matches entries count'] = function()
  local raw_data = make_raw_data()
  raw_data.limit = 3
  local result = display.prepare(raw_data, {})

  expect.equality(#result.entries, 3)
end

T['prepare']['missing entries field'] = function()
  local raw_data = make_raw_data()
  raw_data.entries = nil
  local result = display.prepare(raw_data, {})

  expect.equality(#result.entries, 0)
end

T['prepare']['missing properties field'] = function()
  local raw_data = make_raw_data()
  raw_data.properties = nil
  local result = display.prepare(raw_data, {})

  expect.equality(#result.properties, 0)
end

T['prepare']['nil property labels'] = function()
  local raw_data = make_raw_data()
  raw_data.propertyLabels = nil
  local result = display.prepare(raw_data, {})

  expect.equality(result.property_labels, nil)
end

T['prepare']['nil summaries'] = function()
  local raw_data = make_raw_data()
  raw_data.summaries = nil
  local result = display.prepare(raw_data, {})

  expect.equality(result.summaries, nil)
end

T['prepare']['sort by non-existent property'] = function()
  local raw_data = make_raw_data()
  local view_state = { sort = { property = 'note.nonexistent', direction = 'asc' } }
  local result = display.prepare(raw_data, view_state)

  -- Should not crash, entries should be sorted (all nil values)
  expect.equality(#result.entries, 3)
  expect.equality(result.sort_state.property, 'note.nonexistent')
end

T['prepare']['sort with mixed values'] = function()
  local raw_data = {
    properties = { 'file.name', 'note.priority' },
    entries = {
      { file = { path = 'a.md' }, values = { ['note.priority'] = { type = 'primitive', value = 2 } } },
      { file = { path = 'b.md' }, values = {} }, -- No priority value
      { file = { path = 'c.md' }, values = { ['note.priority'] = { type = 'primitive', value = 1 } } },
    },
  }
  local view_state = { sort = { property = 'note.priority', direction = 'asc' } }
  local result = display.prepare(raw_data, view_state)

  -- Nulls should sort to end: 1, 2, null
  expect.equality(#result.entries, 3)
  expect.equality(result.entries[1].file.path, 'c.md')
  expect.equality(result.entries[2].file.path, 'a.md')
  expect.equality(result.entries[3].file.path, 'b.md')
end

-- =======================
-- M.validate
-- =======================

T['validate'] = new_set()

T['validate']['valid display data'] = function()
  local display_data = {
    properties = { 'file.name', 'note.status' },
    entries = {
      { file = { path = 'a.md' }, values = {} },
    },
  }
  local valid, err = display.validate(display_data)

  expect.equality(valid, true)
  expect.equality(err, nil)
end

T['validate']['no properties'] = function()
  local display_data = {
    properties = {},
    entries = {
      { file = { path = 'a.md' }, values = {} },
    },
  }
  local valid, err = display.validate(display_data)

  expect.equality(valid, false)
  expect.equality(err, 'No properties defined in this base')
end

T['validate']['no entries'] = function()
  local display_data = {
    properties = { 'file.name', 'note.status' },
    entries = {},
  }
  local valid, err = display.validate(display_data)

  expect.equality(valid, false)
  expect.equality(err, 'No entries found')
end

T['validate']['both properties and entries empty'] = function()
  local display_data = {
    properties = {},
    entries = {},
  }
  local valid, err = display.validate(display_data)

  -- Properties check happens first
  expect.equality(valid, false)
  expect.equality(err, 'No properties defined in this base')
end

T['validate']['single property single entry'] = function()
  local display_data = {
    properties = { 'file.name' },
    entries = {
      { file = { path = 'a.md' }, values = {} },
    },
  }
  local valid, err = display.validate(display_data)

  expect.equality(valid, true)
  expect.equality(err, nil)
end

T['validate']['multiple properties multiple entries'] = function()
  local display_data = {
    properties = { 'file.name', 'note.status', 'note.priority' },
    entries = {
      { file = { path = 'a.md' }, values = {} },
      { file = { path = 'b.md' }, values = {} },
      { file = { path = 'c.md' }, values = {} },
    },
  }
  local valid, err = display.validate(display_data)

  expect.equality(valid, true)
  expect.equality(err, nil)
end

return T
