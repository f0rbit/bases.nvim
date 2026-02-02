---@class TypedValue
---@field type "string"|"number"|"boolean"|"date"|"list"|"link"|"file"|"duration"|"null"|"regex"|"image"|"object"
---@field value any
---@field path? string -- for link type
---@field flags? string -- for regex type

local M = {}

-- Constructors

---Create a string typed value
---@param s string
---@return TypedValue
function M.string(s)
  return { type = "string", value = tostring(s) }
end

---Create a number typed value
---@param n number
---@return TypedValue
function M.number(n)
  return { type = "number", value = tonumber(n) }
end

---Create a boolean typed value
---@param b boolean
---@return TypedValue
function M.boolean(b)
  return { type = "boolean", value = not not b }
end

---Create a date typed value from milliseconds since epoch
---@param ms number
---@return TypedValue
function M.date(ms)
  return { type = "date", value = ms }
end

---Create a duration typed value from milliseconds
---@param ms number
---@return TypedValue
function M.duration(ms)
  return { type = "duration", value = ms }
end

---Create a link typed value
---@param path string
---@param display? string
---@return TypedValue
function M.link(path, display)
  return { type = "link", value = display or path, path = path }
end

---Create a list typed value
---@param items TypedValue[]
---@return TypedValue
function M.list(items)
  return { type = "list", value = items }
end

---Create a file typed value
---@param note_data table
---@return TypedValue
function M.file(note_data)
  return { type = "file", value = note_data }
end

---Create a null typed value
---@return TypedValue
function M.null()
  return { type = "null", value = nil }
end

---Create an image typed value
---@param path string
---@return TypedValue
function M.image(path)
  return { type = "image", value = path }
end

---Create a regex typed value
---@param pattern string
---@param flags? string
---@return TypedValue
function M.regex(pattern, flags)
  return { type = "regex", value = pattern, flags = flags or "" }
end

---Create an object typed value
---@param entries table<string, TypedValue>
---@return TypedValue
function M.object(entries)
  return { type = "object", value = entries }
end

-- Conversion functions

---Check if a table is a list (has sequential numeric keys starting from 1)
---@param t table
---@return boolean
local function is_list(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  for i = 1, count do
    if t[i] == nil then
      return false
    end
  end
  return true
end

---Convert a raw Lua value to a TypedValue
---@param value any
---@return TypedValue
function M.from_raw(value)
  if value == nil then
    return M.null()
  end

  local value_type = type(value)

  if value_type == "string" then
    -- Check for link pattern [[...]]
    local link_match = value:match("^%[%[(.+)%]%]$")
    if link_match then
      -- Parse optional display text: [[path|display]]
      local path, display = link_match:match("^(.+)|(.+)$")
      if path then
        return M.link(path, display)
      else
        return M.link(link_match)
      end
    end
    return M.string(value)
  elseif value_type == "number" then
    return M.number(value)
  elseif value_type == "boolean" then
    return M.boolean(value)
  elseif value_type == "table" then
    if is_list(value) then
      local items = {}
      for i, v in ipairs(value) do
        items[i] = M.from_raw(v)
      end
      return M.list(items)
    else
      local entries = {}
      for k, v in pairs(value) do
        entries[tostring(k)] = M.from_raw(v)
      end
      return M.object(entries)
    end
  end

  -- Fallback: convert unknown types to string
  return M.string(tostring(value))
end

---Convert TypedValue to number, returns nil for NaN
---@param tv TypedValue
---@return number?
function M.to_number(tv)
  if tv.type == "number" then
    return tv.value
  elseif tv.type == "string" then
    return tonumber(tv.value)
  elseif tv.type == "boolean" then
    return tv.value and 1 or 0
  elseif tv.type == "date" then
    return tv.value
  elseif tv.type == "duration" then
    return tv.value
  else
    return nil
  end
end

---Convert TypedValue to string
---@param tv TypedValue
---@return string
function M.to_string(tv)
  if tv.type == "string" then
    return tv.value
  elseif tv.type == "number" then
    return tostring(tv.value)
  elseif tv.type == "boolean" then
    return tv.value and "true" or "false"
  elseif tv.type == "date" then
    return M.date_to_iso(tv.value)
  elseif tv.type == "duration" then
    return tostring(tv.value)
  elseif tv.type == "list" then
    local parts = {}
    for i, item in ipairs(tv.value) do
      parts[i] = M.to_string(item)
    end
    return table.concat(parts, ", ")
  elseif tv.type == "null" then
    return ""
  elseif tv.type == "link" then
    return tv.value -- display text
  elseif tv.type == "file" then
    -- Return basename
    local note = tv.value
    if note and note.path then
      local basename = note.path:match("([^/]+)$")
      return basename or note.path
    end
    return ""
  elseif tv.type == "image" then
    return tv.value
  elseif tv.type == "regex" then
    return "/" .. tv.value .. "/" .. (tv.flags or "")
  elseif tv.type == "object" then
    return "[object]"
  end
  return tostring(tv.value)
end

---Convert TypedValue to boolean
---@param tv TypedValue
---@return boolean
function M.to_boolean(tv)
  if tv.type == "boolean" then
    return tv.value
  elseif tv.type == "string" then
    return tv.value ~= ""
  elseif tv.type == "number" then
    return tv.value ~= 0
  elseif tv.type == "list" then
    return #tv.value > 0
  elseif tv.type == "null" then
    return false
  else
    return true
  end
end

---Check if TypedValue is truthy
---@param tv TypedValue
---@return boolean
function M.is_truthy(tv)
  return M.to_boolean(tv)
end

-- Duration parsing

---Parse duration string to milliseconds
---@param str string
---@return number?
function M.parse_duration(str)
  -- Trim whitespace
  str = str:match("^%s*(.-)%s*$")

  -- Check for negative sign
  local sign = 1
  if str:sub(1, 1) == "-" then
    sign = -1
    str = str:sub(2)
  end

  -- Pattern: number followed by unit
  local num_str, unit = str:match("^(%d+%.?%d*)%s*(%a+)$")
  if not num_str then
    return nil
  end

  local num = tonumber(num_str)
  if not num then
    return nil
  end

  -- Unit conversion to milliseconds
  local ms_per_unit = {
    s = 1000,
    second = 1000,
    seconds = 1000,
    m = 60 * 1000,
    minute = 60 * 1000,
    minutes = 60 * 1000,
    h = 60 * 60 * 1000,
    hour = 60 * 60 * 1000,
    hours = 60 * 60 * 1000,
    d = 24 * 60 * 60 * 1000,
    day = 24 * 60 * 60 * 1000,
    days = 24 * 60 * 60 * 1000,
    w = 7 * 24 * 60 * 60 * 1000,
    week = 7 * 24 * 60 * 60 * 1000,
    weeks = 7 * 24 * 60 * 60 * 1000,
    M = 30 * 24 * 60 * 60 * 1000,
    month = 30 * 24 * 60 * 60 * 1000,
    months = 30 * 24 * 60 * 60 * 1000,
    y = 365 * 24 * 60 * 60 * 1000,
    year = 365 * 24 * 60 * 60 * 1000,
    years = 365 * 24 * 60 * 60 * 1000,
  }

  local multiplier = ms_per_unit[unit]
  if not multiplier then
    return nil
  end

  return sign * num * multiplier
end

-- Date helpers

---Parse ISO date string to TypedValue
---@param str string
---@return TypedValue?
function M.date_from_iso(str)
  -- Parse YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS
  local year, month, day, hour, min, sec =
    str:match("^(%d%d%d%d)-(%d%d)-(%d%d)T?(%d?%d?):?(%d?%d?):?(%d?%d?)$")

  if not year then
    return nil
  end

  local time_table = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour) or 0,
    min = tonumber(min) or 0,
    sec = tonumber(sec) or 0,
  }

  local timestamp = os.time(time_table)
  if not timestamp then
    return nil
  end

  -- Convert to milliseconds
  return M.date(timestamp * 1000)
end

---Format milliseconds to ISO date string
---@param ms number
---@return string
function M.date_to_iso(ms)
  local timestamp = math.floor(ms / 1000)
  return os.date("%Y-%m-%dT%H:%M:%S", timestamp)
end

return M
