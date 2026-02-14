local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local render = require("bases.render")

local T = new_set()

local default_opts = {
  max_col_width = 40,
  min_col_width = 5,
  max_table_width = nil,
  alternating_rows = true,
  border_style = "rounded",
  null_char = "—",
  bool_true = "✓",
  bool_false = " ",
  list_separator = ", ",
}

local function make_result(properties, entries, opts)
  return {
    properties = properties,
    entries = entries or {},
    propertyLabels = opts and opts.propertyLabels or {},
    views = { count = 1, current = 0, names = { "default" } },
    summaries = opts and opts.summaries or nil,
  }
end

local function make_entry(name, values)
  return {
    file = { path = name .. ".md", name = name .. ".md", basename = name },
    values = values,
  }
end

-- render_serialized_value

T["render_serialized_value: null"] = function()
  local sv = { type = "null" }
  expect.equality(render.render_serialized_value(sv, default_opts), "—")
end

T["render_serialized_value: string"] = function()
  local sv = { type = "primitive", value = "hello" }
  expect.equality(render.render_serialized_value(sv, default_opts), "hello")
end

T["render_serialized_value: number integer"] = function()
  local sv = { type = "primitive", value = 42 }
  expect.equality(render.render_serialized_value(sv, default_opts), "42")
end

T["render_serialized_value: number float strips trailing zeros"] = function()
  local sv = { type = "primitive", value = 3.10 }
  expect.equality(render.render_serialized_value(sv, default_opts), "3.1")
end

T["render_serialized_value: boolean true"] = function()
  local sv = { type = "primitive", value = true }
  expect.equality(render.render_serialized_value(sv, default_opts), "✓")
end

T["render_serialized_value: boolean false"] = function()
  local sv = { type = "primitive", value = false }
  expect.equality(render.render_serialized_value(sv, default_opts), " ")
end

T["render_serialized_value: date"] = function()
  local sv = { type = "date", value = 0, iso = "1970-01-01T00:00:00" }
  expect.equality(render.render_serialized_value(sv, default_opts), "1970-01-01T00:00:00")
end

T["render_serialized_value: link"] = function()
  local sv = { type = "link", value = "[[alpha]]", path = "alpha.md" }
  expect.equality(render.render_serialized_value(sv, default_opts), "[[alpha]]")
end

T["render_serialized_value: list"] = function()
  local sv = {
    type = "list",
    value = {
      { type = "primitive", value = "a" },
      { type = "primitive", value = "b" },
    },
  }
  expect.equality(render.render_serialized_value(sv, default_opts), "a, b")
end

T["render_serialized_value: image"] = function()
  local sv = { type = "image", value = "pic.png" }
  expect.equality(render.render_serialized_value(sv, default_opts), "[image]")
end

-- get_alignment

T["get_alignment: null is center"] = function()
  expect.equality(render.get_alignment({ type = "null" }), "center")
end

T["get_alignment: number is right"] = function()
  expect.equality(render.get_alignment({ type = "primitive", value = 42 }), "right")
end

T["get_alignment: boolean is center"] = function()
  expect.equality(render.get_alignment({ type = "primitive", value = true }), "center")
end

T["get_alignment: string is left"] = function()
  expect.equality(render.get_alignment({ type = "primitive", value = "hi" }), "left")
end

T["get_alignment: link is left"] = function()
  expect.equality(render.get_alignment({ type = "link", value = "[[x]]" }), "left")
end

T["get_alignment: date is left"] = function()
  expect.equality(render.get_alignment({ type = "date", value = 0 }), "left")
end

-- render: simple table

T["render: simple 3-column table"] = function()
  local result = make_result({ "name", "status", "count" }, {
    make_entry("alpha", {
      name = { type = "primitive", value = "alpha" },
      status = { type = "primitive", value = "active" },
      count = { type = "primitive", value = 10 },
    }),
    make_entry("beta", {
      name = { type = "primitive", value = "beta" },
      status = { type = "primitive", value = "done" },
      count = { type = "primitive", value = 5 },
    }),
  })

  local lines, highlights = render.render(result, default_opts)

  -- Should have: top border, header, separator, 2 data rows, bottom border = 6 lines
  expect.equality(#lines, 6)

  -- Top border starts with rounded corner
  expect.equality(lines[1]:sub(1, #"╭"), "╭")
  -- Bottom border ends with rounded corner
  local last = lines[#lines]
  expect.equality(last:sub(1, #"╰"), "╰")

  -- Header row contains column names
  local header = lines[2]
  expect.no_equality(header:find("name"), nil)
  expect.no_equality(header:find("status"), nil)
  expect.no_equality(header:find("count"), nil)

  -- Separator uses ├ and ┤
  expect.equality(lines[3]:sub(1, #"├"), "├")

  -- Data rows have │ borders
  expect.equality(lines[4]:sub(1, #"│"), "│")
  expect.equality(lines[5]:sub(1, #"│"), "│")

  -- Highlights exist
  expect.equality(type(highlights), "table")
  assert(#highlights > 0, "Expected at least one highlight")
end

-- render: boolean and null values

T["render: boolean and null rendering"] = function()
  local result = make_result({ "flag", "missing" }, {
    make_entry("row1", {
      flag = { type = "primitive", value = true },
      missing = { type = "null" },
    }),
  })

  local lines, _ = render.render(result, default_opts)

  -- Data row should contain checkmark and em dash
  local data_row = lines[4]
  expect.no_equality(data_row:find("✓"), nil)
  expect.no_equality(data_row:find("—"), nil)
end

-- render: number alignment

T["render: numbers are right-aligned"] = function()
  local result = make_result({ "val" }, {
    make_entry("r1", {
      val = { type = "primitive", value = 7 },
    }),
  })

  local lines, _ = render.render(result, default_opts)
  local data_row = lines[4]
  -- The number "7" should be right-padded by spaces on the left within its cell
  -- Cell format: "│ <padded_value> │"
  -- For right-alignment the value appears after leading spaces
  local cell_content = data_row:match("│ (.+) │")
  assert(cell_content ~= nil, "Expected cell content")
  -- Right-aligned: leading spaces before the digit
  expect.no_equality(cell_content:find("%s+7"), nil)
end

-- render: with summaries

T["render: table with summaries"] = function()
  local result = make_result({ "name", "budget" }, {
    make_entry("a", {
      name = { type = "primitive", value = "a" },
      budget = { type = "primitive", value = 100 },
    }),
    make_entry("b", {
      name = { type = "primitive", value = "b" },
      budget = { type = "primitive", value = 200 },
    }),
  }, {
    summaries = {
      ["budget"] = {
        label = "Sum",
        value = { type = "primitive", value = 300 },
      },
    },
  })

  local lines, highlights = render.render(result, default_opts)

  -- Should have: top, header, sep, 2 data, double-line sep, summary, bottom = 8 lines
  expect.equality(#lines, 8)

  -- Double-line separator uses ═
  local double_sep = lines[6]
  expect.no_equality(double_sep:find("═"), nil)
  expect.equality(double_sep:sub(1, #"╞"), "╞")

  -- Summary row contains the label and value
  local summary_row = lines[7]
  expect.no_equality(summary_row:find("Sum"), nil)
  expect.no_equality(summary_row:find("300"), nil)

  -- Check for summary highlight groups
  local has_summary_hl = false
  local has_summary_border_hl = false
  for _, hl in ipairs(highlights) do
    if hl.group == "BasesTableSummary" then has_summary_hl = true end
    if hl.group == "BasesTableSummaryBorder" then has_summary_border_hl = true end
  end
  assert(has_summary_hl, "Expected BasesTableSummary highlight")
  assert(has_summary_border_hl, "Expected BasesTableSummaryBorder highlight")
end

-- render: empty result

T["render: empty result (no entries)"] = function()
  local result = make_result({ "name", "status" }, {})

  local lines, _ = render.render(result, default_opts)

  -- top border, header, separator, bottom border = 4 lines
  expect.equality(#lines, 4)
end

-- render: no properties

T["render: no properties returns empty"] = function()
  local result = make_result({}, {})

  local lines, highlights = render.render(result, default_opts)

  expect.equality(#lines, 0)
  expect.equality(#highlights, 0)
end

-- render: single column

T["render: single column table"] = function()
  local result = make_result({ "name" }, {
    make_entry("only", {
      name = { type = "primitive", value = "only" },
    }),
  })

  local lines, _ = render.render(result, default_opts)

  -- top, header, sep, 1 data row, bottom = 5
  expect.equality(#lines, 5)
  expect.no_equality(lines[2]:find("name"), nil)
  expect.no_equality(lines[4]:find("only"), nil)
end

-- render: property labels

T["render: uses property labels for headers"] = function()
  local result = make_result({ "budget" }, {
    make_entry("r1", {
      budget = { type = "primitive", value = 100 },
    }),
  }, {
    propertyLabels = { budget = "Budget ($)" },
  })

  local lines, _ = render.render(result, default_opts)

  expect.no_equality(lines[2]:find("Budget"), nil)
end

-- render: sharp border style

T["render: sharp border style"] = function()
  local result = make_result({ "a" }, {
    make_entry("r", { a = { type = "primitive", value = "x" } }),
  })

  local sharp_opts = vim.tbl_extend("force", default_opts, { border_style = "sharp" })
  local lines, _ = render.render(result, sharp_opts)

  expect.equality(lines[1]:sub(1, #"┌"), "┌")
  expect.equality(lines[#lines]:sub(1, #"└"), "└")
end

-- render: highlight groups

T["render: alternating row highlights"] = function()
  local result = make_result({ "x" }, {
    make_entry("r1", { x = { type = "primitive", value = "a" } }),
    make_entry("r2", { x = { type = "primitive", value = "b" } }),
    make_entry("r3", { x = { type = "primitive", value = "c" } }),
  })

  local _, highlights = render.render(result, default_opts)

  local row_groups = {}
  for _, hl in ipairs(highlights) do
    if hl.group == "BasesTableRow" or hl.group == "BasesTableRowAlt" then
      row_groups[#row_groups + 1] = hl.group
    end
  end
  -- Row 1 = BasesTableRow, Row 2 = BasesTableRowAlt, Row 3 = BasesTableRow
  assert(vim.tbl_contains(row_groups, "BasesTableRow"), "Expected BasesTableRow")
  assert(vim.tbl_contains(row_groups, "BasesTableRowAlt"), "Expected BasesTableRowAlt")
end

-- render: type-specific highlights

T["render: null values get BasesTableNull highlight"] = function()
  local result = make_result({ "x" }, {
    make_entry("r1", { x = { type = "null" } }),
  })

  local _, highlights = render.render(result, default_opts)

  local has_null_hl = false
  for _, hl in ipairs(highlights) do
    if hl.group == "BasesTableNull" then has_null_hl = true end
  end
  assert(has_null_hl, "Expected BasesTableNull highlight for null value")
end

T["render: number values get BasesTableNumber highlight"] = function()
  local result = make_result({ "x" }, {
    make_entry("r1", { x = { type = "primitive", value = 42 } }),
  })

  local _, highlights = render.render(result, default_opts)

  local has_num_hl = false
  for _, hl in ipairs(highlights) do
    if hl.group == "BasesTableNumber" then has_num_hl = true end
  end
  assert(has_num_hl, "Expected BasesTableNumber highlight for number value")
end

T["render: link values get BasesTableLink highlight"] = function()
  local result = make_result({ "x" }, {
    make_entry("r1", { x = { type = "link", value = "[[test]]" } }),
  })

  local _, highlights = render.render(result, default_opts)

  local has_link_hl = false
  for _, hl in ipairs(highlights) do
    if hl.group == "BasesTableLink" then has_link_hl = true end
  end
  assert(has_link_hl, "Expected BasesTableLink highlight for link value")
end

return T
