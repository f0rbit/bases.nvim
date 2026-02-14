local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()
local types = require("bases.engine.expr.types")

-- Constructors

T["create string"] = function()
  local tv = types.string("hello")
  expect.equality(tv.type, "string")
  expect.equality(tv.value, "hello")
end

T["create number"] = function()
  local tv = types.number(42)
  expect.equality(tv.type, "number")
  expect.equality(tv.value, 42)
end

T["create number from string coercion"] = function()
  local tv = types.number("3.14")
  expect.equality(tv.type, "number")
  expect.equality(tv.value, 3.14)
end

T["create boolean true"] = function()
  local tv = types.boolean(true)
  expect.equality(tv.type, "boolean")
  expect.equality(tv.value, true)
end

T["create boolean false"] = function()
  local tv = types.boolean(false)
  expect.equality(tv.type, "boolean")
  expect.equality(tv.value, false)
end

T["create null"] = function()
  local tv = types.null()
  expect.equality(tv.type, "null")
  expect.equality(tv.value, nil)
end

T["create date"] = function()
  local tv = types.date(1000000)
  expect.equality(tv.type, "date")
  expect.equality(tv.value, 1000000)
end

T["create duration"] = function()
  local tv = types.duration(5000)
  expect.equality(tv.type, "duration")
  expect.equality(tv.value, 5000)
end

T["create link"] = function()
  local tv = types.link("path/to/note", "My Note")
  expect.equality(tv.type, "link")
  expect.equality(tv.path, "path/to/note")
  expect.equality(tv.value, "My Note")
end

T["create link without display"] = function()
  local tv = types.link("path/to/note")
  expect.equality(tv.type, "link")
  expect.equality(tv.value, "path/to/note")
  expect.equality(tv.path, "path/to/note")
end

T["create list"] = function()
  local items = { types.number(1), types.number(2) }
  local tv = types.list(items)
  expect.equality(tv.type, "list")
  expect.equality(#tv.value, 2)
  expect.equality(tv.value[1].value, 1)
end

T["create regex"] = function()
  local tv = types.regex("test", "g")
  expect.equality(tv.type, "regex")
  expect.equality(tv.value, "test")
  expect.equality(tv.flags, "g")
end

T["create object"] = function()
  local tv = types.object({ name = types.string("hi") })
  expect.equality(tv.type, "object")
  expect.equality(tv.value.name.value, "hi")
end

T["create image"] = function()
  local tv = types.image("img.png")
  expect.equality(tv.type, "image")
  expect.equality(tv.value, "img.png")
end

-- from_raw

T["from_raw nil"] = function()
  local tv = types.from_raw(nil)
  expect.equality(tv.type, "null")
end

T["from_raw string"] = function()
  local tv = types.from_raw("hello")
  expect.equality(tv.type, "string")
  expect.equality(tv.value, "hello")
end

T["from_raw number"] = function()
  local tv = types.from_raw(42)
  expect.equality(tv.type, "number")
  expect.equality(tv.value, 42)
end

T["from_raw boolean"] = function()
  local tv = types.from_raw(true)
  expect.equality(tv.type, "boolean")
  expect.equality(tv.value, true)
end

T["from_raw list table"] = function()
  local tv = types.from_raw({ 1, 2, 3 })
  expect.equality(tv.type, "list")
  expect.equality(#tv.value, 3)
  expect.equality(tv.value[1].type, "number")
end

T["from_raw object table"] = function()
  local tv = types.from_raw({ key = "val" })
  expect.equality(tv.type, "object")
  expect.equality(tv.value.key.type, "string")
  expect.equality(tv.value.key.value, "val")
end

T["from_raw link pattern"] = function()
  local tv = types.from_raw("[[my/note]]")
  expect.equality(tv.type, "link")
  expect.equality(tv.path, "my/note")
end

T["from_raw link with display"] = function()
  local tv = types.from_raw("[[path|Display Text]]")
  expect.equality(tv.type, "link")
  expect.equality(tv.path, "path")
  expect.equality(tv.value, "Display Text")
end

-- is_truthy / to_boolean

T["is_truthy boolean true"] = function()
  expect.equality(types.is_truthy(types.boolean(true)), true)
end

T["is_truthy boolean false"] = function()
  expect.equality(types.is_truthy(types.boolean(false)), false)
end

T["is_truthy null"] = function()
  expect.equality(types.is_truthy(types.null()), false)
end

T["is_truthy non-empty string"] = function()
  expect.equality(types.is_truthy(types.string("hi")), true)
end

T["is_truthy empty string"] = function()
  expect.equality(types.is_truthy(types.string("")), false)
end

T["is_truthy non-zero number"] = function()
  expect.equality(types.is_truthy(types.number(1)), true)
end

T["is_truthy zero"] = function()
  expect.equality(types.is_truthy(types.number(0)), false)
end

T["is_truthy non-empty list"] = function()
  expect.equality(types.is_truthy(types.list({ types.number(1) })), true)
end

T["is_truthy empty list"] = function()
  expect.equality(types.is_truthy(types.list({})), false)
end

T["is_truthy link is true"] = function()
  expect.equality(types.is_truthy(types.link("path")), true)
end

-- to_number

T["to_number from number"] = function()
  expect.equality(types.to_number(types.number(42)), 42)
end

T["to_number from numeric string"] = function()
  expect.equality(types.to_number(types.string("3.14")), 3.14)
end

T["to_number from non-numeric string"] = function()
  expect.equality(types.to_number(types.string("abc")), nil)
end

T["to_number from boolean true"] = function()
  expect.equality(types.to_number(types.boolean(true)), 1)
end

T["to_number from boolean false"] = function()
  expect.equality(types.to_number(types.boolean(false)), 0)
end

T["to_number from null"] = function()
  expect.equality(types.to_number(types.null()), nil)
end

T["to_number from date"] = function()
  expect.equality(types.to_number(types.date(1000)), 1000)
end

T["to_number from duration"] = function()
  expect.equality(types.to_number(types.duration(5000)), 5000)
end

-- to_string

T["to_string from string"] = function()
  expect.equality(types.to_string(types.string("hello")), "hello")
end

T["to_string from number"] = function()
  expect.equality(types.to_string(types.number(42)), "42")
end

T["to_string from boolean true"] = function()
  expect.equality(types.to_string(types.boolean(true)), "true")
end

T["to_string from boolean false"] = function()
  expect.equality(types.to_string(types.boolean(false)), "false")
end

T["to_string from null"] = function()
  expect.equality(types.to_string(types.null()), "")
end

T["to_string from list"] = function()
  local tv = types.list({ types.string("a"), types.string("b") })
  expect.equality(types.to_string(tv), "a, b")
end

T["to_string from link"] = function()
  local tv = types.link("path", "Display")
  expect.equality(types.to_string(tv), "Display")
end

T["to_string from regex"] = function()
  local tv = types.regex("test", "g")
  expect.equality(types.to_string(tv), "/test/g")
end

T["to_string from object"] = function()
  local tv = types.object({ a = types.number(1) })
  expect.equality(types.to_string(tv), "[object]")
end

-- parse_duration

T["parse_duration seconds"] = function()
  expect.equality(types.parse_duration("5s"), 5000)
end

T["parse_duration minutes"] = function()
  expect.equality(types.parse_duration("2m"), 120000)
end

T["parse_duration hours"] = function()
  expect.equality(types.parse_duration("1h"), 3600000)
end

T["parse_duration days"] = function()
  expect.equality(types.parse_duration("3d"), 3 * 86400000)
end

T["parse_duration weeks"] = function()
  expect.equality(types.parse_duration("1w"), 7 * 86400000)
end

T["parse_duration negative"] = function()
  expect.equality(types.parse_duration("-2d"), -2 * 86400000)
end

T["parse_duration invalid returns nil"] = function()
  expect.equality(types.parse_duration("abc"), nil)
end

T["parse_duration long unit names"] = function()
  expect.equality(types.parse_duration("2 hours"), 7200000)
end

-- date helpers

T["date_from_iso basic date"] = function()
  local tv = types.date_from_iso("2024-01-15")
  assert(tv ~= nil, "date_from_iso returned nil")
  expect.equality(tv.type, "date")
  assert(tv.value > 0, "date value should be positive ms")
end

T["date_from_iso invalid returns nil"] = function()
  local tv = types.date_from_iso("not-a-date")
  expect.equality(tv, nil)
end

T["date roundtrip iso"] = function()
  local tv = types.date_from_iso("2024-06-15T12:30:00")
  assert(tv ~= nil)
  local iso = types.date_to_iso(tv.value)
  assert(iso:find("2024%-06%-15"), "Expected date string to contain 2024-06-15, got: " .. iso)
end

return T
