local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local note_index = require("bases.engine.note_index")
local base_parser = require("bases.engine.base_parser")
local query_engine = require("bases.engine.query_engine")
local render = require("bases.render")

local T = new_set()

local vault_path = vim.fn.fnamemodify("tests/fixtures/vault", ":p"):gsub("/$", "")

local function build_index()
  local index = note_index.new(vault_path)
  local done = false
  local build_err = nil
  index:build(function(err)
    build_err = err
    done = true
  end)
  vim.wait(5000, function() return done end)
  assert(done, "Index build timed out")
  assert(build_err == nil, "Index build failed: " .. tostring(build_err))
  return index
end

local function parse_base_file()
  local base_path = vault_path .. "/tasks.base"
  local config, err = base_parser.parse(base_path)
  assert(config ~= nil, "Failed to parse tasks.base: " .. tostring(err))
  return config
end

-- Index building

T["index: builds successfully"] = function()
  local index = build_index()
  expect.no_equality(index, nil)
  expect.no_equality(index.notes, nil)
end

T["index: contains expected notes"] = function()
  local index = build_index()
  local all = index:all()

  -- Should have all 6 markdown files
  local count = 0
  for _ in pairs(all) do count = count + 1 end
  expect.equality(count, 6)

  -- Check specific notes exist
  expect.no_equality(index:get("projects/alpha.md"), nil)
  expect.no_equality(index:get("projects/beta.md"), nil)
  expect.no_equality(index:get("projects/gamma.md"), nil)
  expect.no_equality(index:get("people/alice.md"), nil)
  expect.no_equality(index:get("people/bob.md"), nil)
  expect.no_equality(index:get("daily/2025-01-15.md"), nil)
end

T["index: note has correct frontmatter"] = function()
  local index = build_index()
  local alpha = index:get("projects/alpha.md")
  expect.equality(alpha.frontmatter.status, "active")
  expect.equality(alpha.frontmatter.priority, 1)
  expect.equality(alpha.frontmatter.budget, 5000)
end

T["index: tag index works"] = function()
  local index = build_index()

  -- "project" tag should match alpha, beta, gamma (hierarchical expansion)
  local project_paths = index.by_tag["project"]
  expect.no_equality(project_paths, nil)

  local project_count = 0
  for _ in pairs(project_paths) do project_count = project_count + 1 end
  expect.equality(project_count, 3)

  -- "person" tag should match alice, bob
  local person_paths = index.by_tag["person"]
  expect.no_equality(person_paths, nil)
  local person_count = 0
  for _ in pairs(person_paths) do person_count = person_count + 1 end
  expect.equality(person_count, 2)
end

T["index: folder index works"] = function()
  local index = build_index()

  local projects_paths = index.by_folder["projects"]
  expect.no_equality(projects_paths, nil)
  expect.equality(projects_paths["projects/alpha.md"], true)
  expect.equality(projects_paths["projects/beta.md"], true)
  expect.equality(projects_paths["projects/gamma.md"], true)
end

T["index: hierarchical tag expansion"] = function()
  local index = build_index()

  -- "project/active" is a specific sub-tag on alpha and gamma
  local active_paths = index.by_tag["project/active"]
  expect.no_equality(active_paths, nil)
  expect.equality(active_paths["projects/alpha.md"], true)
  expect.equality(active_paths["projects/gamma.md"], true)
  -- beta has just "project", not "project/active"
  expect.equality(active_paths["projects/beta.md"] or false, false)
end

-- Base parser

T["parser: parses tasks.base"] = function()
  local config = parse_base_file()
  expect.no_equality(config, nil)
  expect.no_equality(config.views, nil)
  expect.equality(#config.views, 2)
end

T["parser: filters parsed correctly"] = function()
  local config = parse_base_file()
  expect.no_equality(config.filters, nil)
  expect.equality(config.filters.type, "expression")
  expect.equality(config.filters.expression, 'file.hasTag("project")')
end

T["parser: formulas parsed correctly"] = function()
  local config = parse_base_file()
  expect.no_equality(config.formulas, nil)
  expect.equality(config.formulas.double_budget, "budget * 2")
end

T["parser: view config parsed correctly"] = function()
  local config = parse_base_file()
  local view1 = config.views[1]
  expect.equality(view1.type, "table")
  expect.equality(view1.name, "All Projects")
  expect.no_equality(view1.order, nil)
  expect.equality(#view1.order, 5)

  -- Sort config
  expect.no_equality(view1.sort, nil)
  expect.equality(#view1.sort, 1)
  expect.equality(view1.sort[1].column, "note.priority")
  expect.equality(view1.sort[1].direction, "ASC")

  -- Summaries config
  expect.no_equality(view1.summaries, nil)
  expect.equality(view1.summaries["note.budget"], "sum")
end

T["parser: view order normalizes property names"] = function()
  local config = parse_base_file()
  local view1 = config.views[1]
  -- "name" -> "file.name", "status" -> "note.status", etc.
  -- "double_budget" has no prefix and is not a known file property,
  -- so normalize_property_name defaults to "note." prefix.
  -- The query engine's resolve_properties applies the formula. prefix later.
  expect.equality(view1.order[1], "file.name")
  expect.equality(view1.order[2], "note.status")
  expect.equality(view1.order[3], "note.priority")
  expect.equality(view1.order[4], "note.budget")
  expect.equality(view1.order[5], "note.double_budget")
end

T["parser: second view has limit and filters"] = function()
  local config = parse_base_file()
  local view2 = config.views[2]
  expect.equality(view2.name, "Active Only")
  expect.equality(view2.limit, 10)
  expect.no_equality(view2.filters, nil)
  expect.equality(view2.filters.expression, 'status == "active"')
end

-- Query execution

T["query: executes against index"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  expect.no_equality(result, nil)
  expect.no_equality(result.properties, nil)
  expect.no_equality(result.entries, nil)
end

T["query: returns expected properties"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  expect.equality(#result.properties, 5)
  expect.equality(result.properties[1], "file.name")
  expect.equality(result.properties[2], "note.status")
  expect.equality(result.properties[3], "note.priority")
  expect.equality(result.properties[4], "note.budget")
  expect.equality(result.properties[5], "formula.double_budget")
end

T["query: filters to project-tagged entries"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  -- Should match alpha, beta, gamma (all have "project" tag)
  expect.equality(#result.entries, 3)

  local basenames = {}
  for _, entry in ipairs(result.entries) do
    basenames[entry.file.basename] = true
  end
  expect.equality(basenames["alpha"], true)
  expect.equality(basenames["beta"], true)
  expect.equality(basenames["gamma"], true)
end

T["query: entry values are correctly serialized"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  -- Find alpha entry
  local alpha = nil
  for _, entry in ipairs(result.entries) do
    if entry.file.basename == "alpha" then
      alpha = entry
      break
    end
  end
  assert(alpha ~= nil, "Expected alpha entry")

  -- file.name is a link
  expect.equality(alpha.values["file.name"].type, "link")

  -- note.status is a primitive string
  expect.equality(alpha.values["note.status"].type, "primitive")
  expect.equality(alpha.values["note.status"].value, "active")

  -- note.priority is a primitive number
  expect.equality(alpha.values["note.priority"].type, "primitive")
  expect.equality(alpha.values["note.priority"].value, 1)

  -- note.budget is a primitive number
  expect.equality(alpha.values["note.budget"].type, "primitive")
  expect.equality(alpha.values["note.budget"].value, 5000)

  -- formula.double_budget should be budget * 2 = 10000
  expect.equality(alpha.values["formula.double_budget"].type, "primitive")
  expect.equality(alpha.values["formula.double_budget"].value, 10000)
end

T["query: summaries are computed"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  expect.no_equality(result.summaries, nil)

  local budget_summary = result.summaries["note.budget"]
  expect.no_equality(budget_summary, nil)
  expect.equality(budget_summary.label, "Sum")
  -- sum of 5000 + 2000 + 3000 = 10000
  expect.equality(budget_summary.value.type, "primitive")
  expect.equality(budget_summary.value.value, 10000)
end

T["query: view metadata is correct"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  expect.equality(result.views.count, 2)
  expect.equality(result.views.current, 0)
  expect.equality(result.views.names[1], "All Projects")
  expect.equality(result.views.names[2], "Active Only")
end

T["query: property labels are resolved"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  expect.equality(result.propertyLabels["note.status"], "Status")
  expect.equality(result.propertyLabels["note.budget"], "Budget ($)")
end

T["query: default sort is set"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  expect.no_equality(result.defaultSort, nil)
  expect.equality(result.defaultSort.property, "note.priority")
  expect.equality(result.defaultSort.direction, "asc")
end

-- Query + Render integration

T["query+render: result renders to table lines"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 0, nil)

  local lines, highlights = render.render(result, {
    max_col_width = 40,
    min_col_width = 5,
    max_table_width = 120,
    alternating_rows = true,
    border_style = "rounded",
    null_char = "—",
    bool_true = "✓",
    bool_false = " ",
    list_separator = ", ",
  })

  -- top border, header, separator, 3 data rows, double-line sep, summary, bottom = 9
  expect.equality(#lines, 9)
  assert(#highlights > 0, "Expected highlights")

  -- Header should contain column labels
  local header = lines[2]
  expect.no_equality(header:find("Status"), nil)
  expect.no_equality(header:find("Budget"), nil)
end

-- View 2: Active Only filter

T["query: view 2 filters to active only"] = function()
  local index = build_index()
  local config = parse_base_file()
  local result = query_engine.execute(config, index, 1, nil)

  -- Only alpha has status "active"
  expect.equality(#result.entries, 1)
  expect.equality(result.entries[1].file.basename, "alpha")

  -- View 2 has 3 columns
  expect.equality(#result.properties, 3)
end

return T
