local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local yaml = require("bases.engine.yaml")

local T = new_set()

-- parse_value

T["parse_value: bare string"] = function()
  expect.equality(yaml.parse_value("hello"), "hello")
end

T["parse_value: number"] = function()
  expect.equality(yaml.parse_value("42"), 42)
end

T["parse_value: float"] = function()
  expect.equality(yaml.parse_value("3.14"), 3.14)
end

T["parse_value: boolean true"] = function()
  expect.equality(yaml.parse_value("true"), true)
end

T["parse_value: boolean false"] = function()
  expect.equality(yaml.parse_value("false"), false)
end

T["parse_value: boolean yes/no"] = function()
  expect.equality(yaml.parse_value("yes"), true)
  expect.equality(yaml.parse_value("no"), false)
end

T["parse_value: null"] = function()
  expect.equality(yaml.parse_value("null"), nil)
  expect.equality(yaml.parse_value("~"), nil)
  expect.equality(yaml.parse_value(""), nil)
end

T["parse_value: double-quoted string"] = function()
  expect.equality(yaml.parse_value('"hello world"'), "hello world")
end

T["parse_value: single-quoted string"] = function()
  expect.equality(yaml.parse_value("'hello world'"), "hello world")
end

T["parse_value: double-quoted escapes"] = function()
  expect.equality(yaml.parse_value('"line1\\nline2"'), "line1\nline2")
end

-- parse: basic key-value

T["parse: basic key-value"] = function()
  local result = yaml.parse("key: value")
  expect.equality(result, { key = "value" })
end

T["parse: number value"] = function()
  local result = yaml.parse("count: 42")
  expect.equality(result, { count = 42 })
end

T["parse: boolean value"] = function()
  local result = yaml.parse("active: true")
  expect.equality(result, { active = true })
end

T["parse: quoted string value"] = function()
  local result = yaml.parse('name: "hello world"')
  expect.equality(result, { name = "hello world" })
end

T["parse: empty value is nil"] = function()
  local result = yaml.parse("key:")
  expect.equality(result.key, nil)
end

-- parse: lists

T["parse: block list"] = function()
  local result = yaml.parse("tags:\n  - a\n  - b")
  expect.equality(result, { tags = { "a", "b" } })
end

T["parse: inline list"] = function()
  local result = yaml.parse("tags: [a, b, c]")
  expect.equality(result, { tags = { "a", "b", "c" } })
end

T["parse: list of numbers"] = function()
  local result = yaml.parse("nums:\n  - 1\n  - 2\n  - 3")
  expect.equality(result, { nums = { 1, 2, 3 } })
end

T["parse: empty inline list"] = function()
  local result = yaml.parse("tags: []")
  expect.equality(result, { tags = {} })
end

-- parse: nested maps

T["parse: nested map"] = function()
  local result = yaml.parse("parent:\n  child: value")
  expect.equality(result, { parent = { child = "value" } })
end

T["parse: deeply nested map"] = function()
  local input = "a:\n  b:\n    c: deep"
  local result = yaml.parse(input)
  expect.equality(result, { a = { b = { c = "deep" } } })
end

-- parse: multiple keys

T["parse: multiple keys"] = function()
  local result = yaml.parse("name: Alice\nage: 30\nactive: true")
  expect.equality(result, { name = "Alice", age = 30, active = true })
end

-- parse: frontmatter delimiters

T["parse: strips frontmatter delimiters"] = function()
  local input = "---\nname: Alice\nage: 30\n---"
  local result = yaml.parse(input)
  expect.equality(result, { name = "Alice", age = 30 })
end

T["parse: strips frontmatter with ... delimiter"] = function()
  local input = "---\nname: Bob\n..."
  local result = yaml.parse(input)
  expect.equality(result, { name = "Bob" })
end

-- parse: comments

T["parse: strips inline comments"] = function()
  local result = yaml.parse("key: value # this is a comment")
  expect.equality(result, { key = "value" })
end

-- parse: flow mappings

T["parse: inline flow mapping"] = function()
  local result = yaml.parse("meta: {a: 1, b: 2}")
  expect.equality(result, { meta = { a = 1, b = 2 } })
end

-- parse: complex frontmatter

T["parse: complex frontmatter-like content"] = function()
  local input = table.concat({
    "---",
    "tags:",
    "  - project/active",
    "status: active",
    "priority: 1",
    "budget: 5000",
    'lead: "[[people/alice]]"',
    "---",
  }, "\n")
  local result = yaml.parse(input)
  expect.equality(result.tags, { "project/active" })
  expect.equality(result.status, "active")
  expect.equality(result.priority, 1)
  expect.equality(result.budget, 5000)
  expect.equality(result.lead, "[[people/alice]]")
end

-- parse: edge cases

T["parse: empty string"] = function()
  expect.equality(yaml.parse(""), {})
end

T["parse: nil input"] = function()
  expect.equality(yaml.parse(nil), {})
end

T["parse: only frontmatter delimiters"] = function()
  expect.equality(yaml.parse("---\n---"), {})
end

return T
