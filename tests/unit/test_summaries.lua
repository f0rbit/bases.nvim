local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- Mock bases config for date formatting
package.loaded['bases'] = {
  get_config = function()
    return { date_format = '%Y-%m-%d', date_format_relative = false }
  end,
}

local summaries = require('bases.engine.summaries')

local T = new_set()

-- =======================
-- M.compute
-- =======================

T['compute'] = new_set()

T['compute']['nil config returns nil'] = function()
  expect.equality(summaries.compute(nil, {}, {}), nil)
end

T['compute']['empty config returns nil'] = function()
  expect.equality(summaries.compute({}, {}, {}), nil)
end

T['compute']['single summary with builtin function'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 100 } } },
    { values = { budget = { type = 'primitive', value = 200 } } },
  }
  local config = { budget = 'sum' }
  local result = summaries.compute(config, entries, { 'budget' })

  expect.equality(result.budget.label, 'Sum')
  expect.equality(result.budget.value.type, 'primitive')
  expect.equality(result.budget.value.value, 300)
end

-- =======================
-- Universal Functions
-- =======================

T['empty'] = new_set()

T['empty']['counts null values'] = function()
  local entries = {
    { values = { status = { type = 'null' } } },
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'null' } } },
  }
  local result = summaries.compute({ status = 'empty' }, entries, { 'status' })

  expect.equality(result.status.label, 'Empty')
  expect.equality(result.status.value.value, 2)
end

T['empty']['counts empty strings'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = '' } } },
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'primitive', value = '' } } },
  }
  local result = summaries.compute({ status = 'empty' }, entries, { 'status' })

  expect.equality(result.status.value.value, 2)
end

T['empty']['counts empty lists'] = function()
  local entries = {
    { values = { tags = { type = 'list', value = {} } } },
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'tag1' } } } } },
    { values = { tags = { type = 'list', value = {} } } },
  }
  local result = summaries.compute({ tags = 'empty' }, entries, { 'tags' })

  expect.equality(result.tags.value.value, 2)
end

T['empty']['all empty'] = function()
  local entries = {
    { values = { status = { type = 'null' } } },
    { values = { status = { type = 'primitive', value = '' } } },
    { values = { status = { type = 'list', value = {} } } },
  }
  local result = summaries.compute({ status = 'empty' }, entries, { 'status' })

  expect.equality(result.status.value.value, 3)
end

T['empty']['none empty'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'primitive', value = 'done' } } },
  }
  local result = summaries.compute({ status = 'empty' }, entries, { 'status' })

  expect.equality(result.status.value.value, 0)
end

T['filled'] = new_set()

T['filled']['counts non-empty values'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'null' } } },
    { values = { status = { type = 'primitive', value = 'done' } } },
  }
  local result = summaries.compute({ status = 'filled' }, entries, { 'status' })

  expect.equality(result.status.label, 'Filled')
  expect.equality(result.status.value.value, 2)
end

T['filled']['excludes empty strings'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'primitive', value = '' } } },
  }
  local result = summaries.compute({ status = 'filled' }, entries, { 'status' })

  expect.equality(result.status.value.value, 1)
end

T['filled']['excludes empty lists'] = function()
  local entries = {
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'tag1' } } } } },
    { values = { tags = { type = 'list', value = {} } } },
  }
  local result = summaries.compute({ tags = 'filled' }, entries, { 'tags' })

  expect.equality(result.tags.value.value, 1)
end

T['filled']['all filled'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'primitive', value = 'done' } } },
  }
  local result = summaries.compute({ status = 'filled' }, entries, { 'status' })

  expect.equality(result.status.value.value, 2)
end

T['filled']['none filled'] = function()
  local entries = {
    { values = { status = { type = 'null' } } },
    { values = { status = { type = 'primitive', value = '' } } },
  }
  local result = summaries.compute({ status = 'filled' }, entries, { 'status' })

  expect.equality(result.status.value.value, 0)
end

T['unique'] = new_set()

T['unique']['counts unique non-null values'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'primitive', value = 'done' } } },
    { values = { status = { type = 'primitive', value = 'active' } } },
  }
  local result = summaries.compute({ status = 'unique' }, entries, { 'status' })

  expect.equality(result.status.label, 'Unique')
  expect.equality(result.status.value.value, 2)
end

T['unique']['excludes null values'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'null' } } },
    { values = { status = { type = 'null' } } },
    { values = { status = { type = 'primitive', value = 'active' } } },
  }
  local result = summaries.compute({ status = 'unique' }, entries, { 'status' })

  expect.equality(result.status.value.value, 1)
end

T['unique']['all unique'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'primitive', value = 'done' } } },
    { values = { status = { type = 'primitive', value = 'pending' } } },
  }
  local result = summaries.compute({ status = 'unique' }, entries, { 'status' })

  expect.equality(result.status.value.value, 3)
end

T['unique']['all duplicates'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = { status = { type = 'primitive', value = 'active' } } },
  }
  local result = summaries.compute({ status = 'unique' }, entries, { 'status' })

  expect.equality(result.status.value.value, 1)
end

T['unique']['empty entries returns zero'] = function()
  local result = summaries.compute({ status = 'unique' }, {}, { 'status' })
  expect.equality(result.status.value.value, 0)
end

T['unique']['only nulls returns zero'] = function()
  local entries = {
    { values = { status = { type = 'null' } } },
    { values = { status = { type = 'null' } } },
  }
  local result = summaries.compute({ status = 'unique' }, entries, { 'status' })

  expect.equality(result.status.value.value, 0)
end

-- =======================
-- Numeric Functions
-- =======================

T['sum'] = new_set()

T['sum']['sums numeric values'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 100 } } },
    { values = { budget = { type = 'primitive', value = 200 } } },
    { values = { budget = { type = 'primitive', value = 300 } } },
  }
  local result = summaries.compute({ budget = 'sum' }, entries, { 'budget' })

  expect.equality(result.budget.label, 'Sum')
  expect.equality(result.budget.value.type, 'primitive')
  expect.equality(result.budget.value.value, 600)
end

T['sum']['ignores non-numeric values'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 100 } } },
    { values = { budget = { type = 'primitive', value = 'not a number' } } },
    { values = { budget = { type = 'primitive', value = 200 } } },
  }
  local result = summaries.compute({ budget = 'sum' }, entries, { 'budget' })

  expect.equality(result.budget.value.value, 300)
end

T['sum']['handles decimals'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 10.5 } } },
    { values = { budget = { type = 'primitive', value = 20.25 } } },
  }
  local result = summaries.compute({ budget = 'sum' }, entries, { 'budget' })

  expect.equality(result.budget.value.value, 30.75)
end

T['sum']['single value'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 100 } } },
  }
  local result = summaries.compute({ budget = 'sum' }, entries, { 'budget' })

  expect.equality(result.budget.value.value, 100)
end

T['sum']['no numbers returns null'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 'text' } } },
    { values = { budget = { type = 'null' } } },
  }
  local result = summaries.compute({ budget = 'sum' }, entries, { 'budget' })

  expect.equality(result.budget.value.type, 'null')
end

T['sum']['empty entries returns null'] = function()
  local result = summaries.compute({ budget = 'sum' }, {}, { 'budget' })
  expect.equality(result.budget.value.type, 'null')
end

T['average'] = new_set()

T['average']['calculates mean of numeric values'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
    { values = { score = { type = 'primitive', value = 200 } } },
    { values = { score = { type = 'primitive', value = 300 } } },
  }
  local result = summaries.compute({ score = 'average' }, entries, { 'score' })

  expect.equality(result.score.label, 'Average')
  expect.equality(result.score.value.value, 200)
end

T['average']['ignores non-numeric values'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
    { values = { score = { type = 'primitive', value = 'text' } } },
    { values = { score = { type = 'primitive', value = 300 } } },
  }
  local result = summaries.compute({ score = 'average' }, entries, { 'score' })

  expect.equality(result.score.value.value, 200)
end

T['average']['handles decimals'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 10.5 } } },
    { values = { score = { type = 'primitive', value = 20.5 } } },
  }
  local result = summaries.compute({ score = 'average' }, entries, { 'score' })

  expect.equality(result.score.value.value, 15.5)
end

T['average']['single value'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
  }
  local result = summaries.compute({ score = 'average' }, entries, { 'score' })

  expect.equality(result.score.value.value, 100)
end

T['average']['no numbers returns null'] = function()
  local entries = {
    { values = { score = { type = 'null' } } },
  }
  local result = summaries.compute({ score = 'average' }, entries, { 'score' })

  expect.equality(result.score.value.type, 'null')
end

T['median'] = new_set()

T['median']['odd count returns middle value'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
    { values = { score = { type = 'primitive', value = 300 } } },
    { values = { score = { type = 'primitive', value = 200 } } },
  }
  local result = summaries.compute({ score = 'median' }, entries, { 'score' })

  expect.equality(result.score.label, 'Median')
  expect.equality(result.score.value.value, 200)
end

T['median']['even count returns average of middle two'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
    { values = { score = { type = 'primitive', value = 200 } } },
    { values = { score = { type = 'primitive', value = 300 } } },
    { values = { score = { type = 'primitive', value = 400 } } },
  }
  local result = summaries.compute({ score = 'median' }, entries, { 'score' })

  expect.equality(result.score.value.value, 250)
end

T['median']['single value'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
  }
  local result = summaries.compute({ score = 'median' }, entries, { 'score' })

  expect.equality(result.score.value.value, 100)
end

T['median']['no numbers returns null'] = function()
  local entries = {
    { values = { score = { type = 'null' } } },
  }
  local result = summaries.compute({ score = 'median' }, entries, { 'score' })

  expect.equality(result.score.value.type, 'null')
end

T['min'] = new_set()

T['min']['finds minimum value'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 300 } } },
    { values = { score = { type = 'primitive', value = 100 } } },
    { values = { score = { type = 'primitive', value = 200 } } },
  }
  local result = summaries.compute({ score = 'min' }, entries, { 'score' })

  expect.equality(result.score.label, 'Min')
  expect.equality(result.score.value.value, 100)
end

T['min']['handles negative values'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 10 } } },
    { values = { score = { type = 'primitive', value = -5 } } },
    { values = { score = { type = 'primitive', value = 20 } } },
  }
  local result = summaries.compute({ score = 'min' }, entries, { 'score' })

  expect.equality(result.score.value.value, -5)
end

T['min']['single value'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
  }
  local result = summaries.compute({ score = 'min' }, entries, { 'score' })

  expect.equality(result.score.value.value, 100)
end

T['min']['no numbers returns null'] = function()
  local entries = {
    { values = { score = { type = 'null' } } },
  }
  local result = summaries.compute({ score = 'min' }, entries, { 'score' })

  expect.equality(result.score.value.type, 'null')
end

T['max'] = new_set()

T['max']['finds maximum value'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
    { values = { score = { type = 'primitive', value = 300 } } },
    { values = { score = { type = 'primitive', value = 200 } } },
  }
  local result = summaries.compute({ score = 'max' }, entries, { 'score' })

  expect.equality(result.score.label, 'Max')
  expect.equality(result.score.value.value, 300)
end

T['max']['handles negative values'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = -10 } } },
    { values = { score = { type = 'primitive', value = -5 } } },
    { values = { score = { type = 'primitive', value = -20 } } },
  }
  local result = summaries.compute({ score = 'max' }, entries, { 'score' })

  expect.equality(result.score.value.value, -5)
end

T['max']['single value'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
  }
  local result = summaries.compute({ score = 'max' }, entries, { 'score' })

  expect.equality(result.score.value.value, 100)
end

T['max']['no numbers returns null'] = function()
  local entries = {
    { values = { score = { type = 'null' } } },
  }
  local result = summaries.compute({ score = 'max' }, entries, { 'score' })

  expect.equality(result.score.value.type, 'null')
end

T['range'] = new_set()

T['range']['calculates difference between max and min'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
    { values = { score = { type = 'primitive', value = 300 } } },
    { values = { score = { type = 'primitive', value = 200 } } },
  }
  local result = summaries.compute({ score = 'range' }, entries, { 'score' })

  expect.equality(result.score.label, 'Range')
  expect.equality(result.score.value.value, 200)
end

T['range']['handles negative values'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = -10 } } },
    { values = { score = { type = 'primitive', value = 10 } } },
  }
  local result = summaries.compute({ score = 'range' }, entries, { 'score' })

  expect.equality(result.score.value.value, 20)
end

T['range']['single value returns zero'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
  }
  local result = summaries.compute({ score = 'range' }, entries, { 'score' })

  expect.equality(result.score.value.value, 0)
end

T['range']['no numbers returns null'] = function()
  local entries = {
    { values = { score = { type = 'null' } } },
  }
  local result = summaries.compute({ score = 'range' }, entries, { 'score' })

  expect.equality(result.score.value.type, 'null')
end

T['stddev'] = new_set()

T['stddev']['calculates population standard deviation'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 2 } } },
    { values = { score = { type = 'primitive', value = 4 } } },
    { values = { score = { type = 'primitive', value = 4 } } },
    { values = { score = { type = 'primitive', value = 4 } } },
    { values = { score = { type = 'primitive', value = 5 } } },
    { values = { score = { type = 'primitive', value = 5 } } },
    { values = { score = { type = 'primitive', value = 7 } } },
    { values = { score = { type = 'primitive', value = 9 } } },
  }
  local result = summaries.compute({ score = 'stddev' }, entries, { 'score' })

  expect.equality(result.score.label, 'Stddev')
  -- Expected stddev is 2 for this dataset
  local expected = 2
  local tolerance = 0.01
  expect.no_error(function()
    if math.abs(result.score.value.value - expected) > tolerance then
      error(string.format('Expected ~%f, got %f', expected, result.score.value.value))
    end
  end)
end

T['stddev']['two values'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 10 } } },
    { values = { score = { type = 'primitive', value = 20 } } },
  }
  local result = summaries.compute({ score = 'stddev' }, entries, { 'score' })

  -- stddev of [10, 20] is 5
  expect.equality(result.score.value.value, 5)
end

T['stddev']['less than two numbers returns null'] = function()
  local entries = {
    { values = { score = { type = 'primitive', value = 100 } } },
  }
  local result = summaries.compute({ score = 'stddev' }, entries, { 'score' })

  expect.equality(result.score.value.type, 'null')
end

T['stddev']['no numbers returns null'] = function()
  local entries = {
    { values = { score = { type = 'null' } } },
  }
  local result = summaries.compute({ score = 'stddev' }, entries, { 'score' })

  expect.equality(result.score.value.type, 'null')
end

-- =======================
-- Date Functions
-- =======================

T['earliest'] = new_set()

T['earliest']['finds earliest date'] = function()
  -- January 1, 2024
  local date1 = 1704067200000
  -- February 1, 2024
  local date2 = 1706745600000
  -- March 1, 2024
  local date3 = 1709251200000

  local entries = {
    { values = { created = { type = 'date', value = date2 } } },
    { values = { created = { type = 'date', value = date1 } } },
    { values = { created = { type = 'date', value = date3 } } },
  }
  local result = summaries.compute({ created = 'earliest' }, entries, { 'created' })

  expect.equality(result.created.label, 'Earliest')
  expect.equality(result.created.value.type, 'date')
  expect.equality(result.created.value.value, date1)
end

T['earliest']['single date'] = function()
  local date1 = 1704067200000
  local entries = {
    { values = { created = { type = 'date', value = date1 } } },
  }
  local result = summaries.compute({ created = 'earliest' }, entries, { 'created' })

  expect.equality(result.created.value.value, date1)
end

T['earliest']['no dates returns null'] = function()
  local entries = {
    { values = { created = { type = 'null' } } },
    { values = { created = { type = 'primitive', value = 'not a date' } } },
  }
  local result = summaries.compute({ created = 'earliest' }, entries, { 'created' })

  expect.equality(result.created.value.type, 'null')
end

T['latest'] = new_set()

T['latest']['finds latest date'] = function()
  -- January 1, 2024
  local date1 = 1704067200000
  -- February 1, 2024
  local date2 = 1706745600000
  -- March 1, 2024
  local date3 = 1709251200000

  local entries = {
    { values = { created = { type = 'date', value = date2 } } },
    { values = { created = { type = 'date', value = date1 } } },
    { values = { created = { type = 'date', value = date3 } } },
  }
  local result = summaries.compute({ created = 'latest' }, entries, { 'created' })

  expect.equality(result.created.label, 'Latest')
  expect.equality(result.created.value.type, 'date')
  expect.equality(result.created.value.value, date3)
end

T['latest']['single date'] = function()
  local date1 = 1704067200000
  local entries = {
    { values = { created = { type = 'date', value = date1 } } },
  }
  local result = summaries.compute({ created = 'latest' }, entries, { 'created' })

  expect.equality(result.created.value.value, date1)
end

T['latest']['no dates returns null'] = function()
  local entries = {
    { values = { created = { type = 'null' } } },
  }
  local result = summaries.compute({ created = 'latest' }, entries, { 'created' })

  expect.equality(result.created.value.type, 'null')
end

T['date_range'] = new_set()

T['date_range']['calculates difference in days'] = function()
  -- January 1, 2024
  local date1 = 1704067200000
  -- January 11, 2024 (10 days later)
  local date2 = 1704931200000

  local entries = {
    { values = { created = { type = 'date', value = date1 } } },
    { values = { created = { type = 'date', value = date2 } } },
  }
  local result = summaries.compute({ created = 'date_range' }, entries, { 'created' })

  expect.equality(result.created.label, 'Date range')
  expect.equality(result.created.value.type, 'primitive')
  expect.equality(result.created.value.value, 10)
end

T['date_range']['rounds to one decimal'] = function()
  -- January 1, 2024
  local date1 = 1704067200000
  -- 1.55 days later
  local date2 = date1 + (1.55 * 24 * 60 * 60 * 1000)

  local entries = {
    { values = { created = { type = 'date', value = date1 } } },
    { values = { created = { type = 'date', value = date2 } } },
  }
  local result = summaries.compute({ created = 'date_range' }, entries, { 'created' })

  expect.equality(result.created.value.value, 1.6)
end

T['date_range']['less than two dates returns null'] = function()
  local date1 = 1704067200000
  local entries = {
    { values = { created = { type = 'date', value = date1 } } },
  }
  local result = summaries.compute({ created = 'date_range' }, entries, { 'created' })

  expect.equality(result.created.value.type, 'null')
end

T['date_range']['no dates returns null'] = function()
  local entries = {
    { values = { created = { type = 'null' } } },
  }
  local result = summaries.compute({ created = 'date_range' }, entries, { 'created' })

  expect.equality(result.created.value.type, 'null')
end

-- =======================
-- Checkbox Functions
-- =======================

T['checked'] = new_set()

T['checked']['counts true boolean values'] = function()
  local entries = {
    { values = { done = { type = 'primitive', value = true } } },
    { values = { done = { type = 'primitive', value = false } } },
    { values = { done = { type = 'primitive', value = true } } },
  }
  local result = summaries.compute({ done = 'checked' }, entries, { 'done' })

  expect.equality(result.done.label, 'Checked')
  expect.equality(result.done.value.value, 2)
end

T['checked']['ignores non-boolean values'] = function()
  local entries = {
    { values = { done = { type = 'primitive', value = true } } },
    { values = { done = { type = 'primitive', value = 'yes' } } },
    { values = { done = { type = 'primitive', value = 1 } } },
  }
  local result = summaries.compute({ done = 'checked' }, entries, { 'done' })

  expect.equality(result.done.value.value, 1)
end

T['checked']['all checked'] = function()
  local entries = {
    { values = { done = { type = 'primitive', value = true } } },
    { values = { done = { type = 'primitive', value = true } } },
  }
  local result = summaries.compute({ done = 'checked' }, entries, { 'done' })

  expect.equality(result.done.value.value, 2)
end

T['checked']['none checked'] = function()
  local entries = {
    { values = { done = { type = 'primitive', value = false } } },
    { values = { done = { type = 'null' } } },
  }
  local result = summaries.compute({ done = 'checked' }, entries, { 'done' })

  expect.equality(result.done.value.value, 0)
end

T['unchecked'] = new_set()

T['unchecked']['counts false boolean values'] = function()
  local entries = {
    { values = { done = { type = 'primitive', value = false } } },
    { values = { done = { type = 'primitive', value = true } } },
    { values = { done = { type = 'primitive', value = false } } },
  }
  local result = summaries.compute({ done = 'unchecked' }, entries, { 'done' })

  expect.equality(result.done.label, 'Unchecked')
  expect.equality(result.done.value.value, 2)
end

T['unchecked']['ignores non-boolean values'] = function()
  local entries = {
    { values = { done = { type = 'primitive', value = false } } },
    { values = { done = { type = 'primitive', value = 'no' } } },
    { values = { done = { type = 'primitive', value = 0 } } },
  }
  local result = summaries.compute({ done = 'unchecked' }, entries, { 'done' })

  expect.equality(result.done.value.value, 1)
end

T['unchecked']['all unchecked'] = function()
  local entries = {
    { values = { done = { type = 'primitive', value = false } } },
    { values = { done = { type = 'primitive', value = false } } },
  }
  local result = summaries.compute({ done = 'unchecked' }, entries, { 'done' })

  expect.equality(result.done.value.value, 2)
end

T['unchecked']['none unchecked'] = function()
  local entries = {
    { values = { done = { type = 'primitive', value = true } } },
    { values = { done = { type = 'null' } } },
  }
  local result = summaries.compute({ done = 'unchecked' }, entries, { 'done' })

  expect.equality(result.done.value.value, 0)
end

-- =======================
-- Case Insensitivity
-- =======================

T['case_insensitive'] = new_set()

T['case_insensitive']['uppercase function name'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 100 } } },
    { values = { budget = { type = 'primitive', value = 200 } } },
  }
  local result = summaries.compute({ budget = 'SUM' }, entries, { 'budget' })

  expect.equality(result.budget.label, 'SUM')
  expect.equality(result.budget.value.value, 300)
end

T['case_insensitive']['mixed case function name'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 100 } } },
    { values = { budget = { type = 'primitive', value = 200 } } },
  }
  local result = summaries.compute({ budget = 'AvErAgE' }, entries, { 'budget' })

  expect.equality(result.budget.label, 'AvErAgE')
  expect.equality(result.budget.value.value, 150)
end

-- =======================
-- Label Formatting
-- =======================

T['labels'] = new_set()

T['labels']['underscore becomes space'] = function()
  local entries = {
    { values = { created = { type = 'date', value = 1704067200000 } } },
    { values = { created = { type = 'date', value = 1704931200000 } } },
  }
  local result = summaries.compute({ created = 'date_range' }, entries, { 'created' })

  expect.equality(result.created.label, 'Date range')
end

T['labels']['first letter capitalized'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 100 } } },
  }
  local result = summaries.compute({ budget = 'sum' }, entries, { 'budget' })

  expect.equality(result.budget.label, 'Sum')
end

-- =======================
-- Multiple Properties
-- =======================

T['multiple_properties'] = new_set()

T['multiple_properties']['different functions on different columns'] = function()
  local entries = {
    { values = {
      budget = { type = 'primitive', value = 100 },
      score = { type = 'primitive', value = 80 },
    } },
    { values = {
      budget = { type = 'primitive', value = 200 },
      score = { type = 'primitive', value = 90 },
    } },
  }
  local config = {
    budget = 'sum',
    score = 'average',
  }
  local result = summaries.compute(config, entries, { 'budget', 'score' })

  expect.equality(result.budget.label, 'Sum')
  expect.equality(result.budget.value.value, 300)
  expect.equality(result.score.label, 'Average')
  expect.equality(result.score.value.value, 85)
end

-- =======================
-- Missing Values
-- =======================

T['missing_values'] = new_set()

T['missing_values']['entry without property treated as null'] = function()
  local entries = {
    { values = { budget = { type = 'primitive', value = 100 } } },
    { values = {} },
    { values = { budget = { type = 'primitive', value = 200 } } },
  }
  local result = summaries.compute({ budget = 'sum' }, entries, { 'budget' })

  expect.equality(result.budget.value.value, 300)
end

T['missing_values']['missing values count as empty'] = function()
  local entries = {
    { values = { status = { type = 'primitive', value = 'active' } } },
    { values = {} },
    { values = { status = { type = 'null' } } },
  }
  local result = summaries.compute({ status = 'empty' }, entries, { 'status' })

  expect.equality(result.status.value.value, 2)
end

-- =======================
-- Custom Formulas
-- =======================

T['custom_formula'] = new_set()

T['custom_formula']['simple expression uses values binding'] = function()
  local entries = {
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'tag1' } } } } },
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'tag2' } } } } },
    { values = { tags = { type = 'null' } } },
  }
  local result = summaries.compute({ tags = 'values.length' }, entries, { 'tags' })

  expect.equality(result.tags.label, 'Formula')
  expect.equality(result.tags.value.type, 'primitive')
  expect.equality(result.tags.value.value, 3)
end

return T
