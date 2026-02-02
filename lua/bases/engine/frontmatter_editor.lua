---@class FrontmatterEditor
---@field update_field fun(file_path: string, field_name: string, new_value: any): boolean, string?
local M = {}

---Check if a string needs quoting in YAML
---@param str string The string to check
---@return boolean
local function needs_quoting(str)
  if type(str) ~= "string" then
    return false
  end

  -- Empty strings need quotes
  if str == "" then
    return true
  end

  -- YAML boolean-like strings
  local lower = str:lower()
  if lower == "true" or lower == "false" or lower == "yes" or lower == "no"
     or lower == "on" or lower == "off" or lower == "null" or lower == "~" then
    return true
  end

  -- Numbers (including negative and decimals)
  if str:match("^-?%d+%.?%d*$") then
    return true
  end

  -- Contains wikilink syntax
  if str:find("%[%[", 1, true) then
    return true
  end

  -- Contains colon followed by space
  if str:find(":%s") then
    return true
  end

  -- Contains hash preceded by space
  if str:find("%s#") then
    return true
  end

  -- Starts with special YAML characters
  local first_char = str:sub(1, 1)
  if first_char:match("[%[{>|*&!%%@`]") then
    return true
  end

  -- Leading or trailing whitespace
  if str:match("^%s") or str:match("%s$") then
    return true
  end

  return false
end

---Format a value for YAML frontmatter
---@param field_name string The field name
---@param value any The value to format (string, number, boolean, table, or nil)
---@return string[] lines Array of lines to insert (empty for nil value)
local function format_value(field_name, value)
  -- Handle vim.NIL (from JSON null)
  if value == vim.NIL then
    return {}
  end

  -- Handle nil (delete field)
  if value == nil then
    return {}
  end

  -- Handle boolean
  if type(value) == "boolean" then
    return { field_name .. ": " .. tostring(value) }
  end

  -- Handle number
  if type(value) == "number" then
    return { field_name .. ": " .. tostring(value) }
  end

  -- Handle string
  if type(value) == "string" then
    if needs_quoting(value) then
      -- Escape internal quotes
      local escaped = value:gsub('"', '\\"')
      return { field_name .. ': "' .. escaped .. '"' }
    else
      return { field_name .. ": " .. value }
    end
  end

  -- Handle table (list)
  if type(value) == "table" then
    -- Check if it's an array-like table
    local is_array = true
    local count = 0
    for k, _ in pairs(value) do
      count = count + 1
      if type(k) ~= "number" or k < 1 or k > count then
        is_array = false
        break
      end
    end

    if not is_array or count == 0 then
      -- Empty list or not an array
      return { field_name .. ": []" }
    end

    -- Format as block list
    local lines = { field_name .. ":" }
    for i = 1, count do
      local item = value[i]
      if type(item) == "string" then
        if needs_quoting(item) then
          local escaped = item:gsub('"', '\\"')
          table.insert(lines, '  - "' .. escaped .. '"')
        else
          table.insert(lines, "  - " .. item)
        end
      elseif type(item) == "number" or type(item) == "boolean" then
        table.insert(lines, "  - " .. tostring(item))
      else
        -- Skip unsupported item types
        table.insert(lines, "  - " .. tostring(item))
      end
    end
    return lines
  end

  -- Unsupported type
  return {}
end

---Find the frontmatter boundaries in the file
---@param lines string[] Array of file lines
---@return number? start_line Line number of opening --- (1-indexed)
---@return number? end_line Line number of closing --- or ... (1-indexed)
local function find_frontmatter_bounds(lines)
  if #lines == 0 or lines[1] ~= "---" then
    return nil, nil
  end

  for i = 2, #lines do
    if lines[i] == "---" or lines[i] == "..." then
      return 1, i
    end
  end

  -- No closing delimiter found
  return nil, nil
end

---Find the line range for a field in frontmatter
---@param lines string[] The frontmatter lines (excluding delimiters)
---@param field_name string The field to find
---@return number? start_line Line index in the lines array (1-indexed)
---@return number? end_line Line index in the lines array (1-indexed, inclusive)
local function find_field_range(lines, field_name)
  local pattern = "^" .. field_name .. ":"
  local start_line = nil

  -- Find the field's key line
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      start_line = i
      break
    end
  end

  if not start_line then
    return nil, nil
  end

  -- Find where the field ends
  -- It ends at the next line that starts a new top-level key (no leading whitespace before key)
  -- or at the end of the frontmatter
  local end_line = start_line

  for i = start_line + 1, #lines do
    local line = lines[i]
    -- Check if this is a new top-level key (starts with non-whitespace followed by colon)
    if line:match("^%S+:") then
      end_line = i - 1
      break
    end
    end_line = i
  end

  return start_line, end_line
end

---Update a field in the frontmatter
---@param file_path string Absolute path to the markdown file
---@param field_name string The frontmatter field name
---@param new_value any New value (string, number, boolean, nil to delete, or table for lists)
---@return boolean success True if successful
---@return string? error Error message if unsuccessful
function M.update_field(file_path, field_name, new_value)
  -- Validate inputs
  if not file_path or file_path == "" then
    return false, "file_path is required"
  end

  if not field_name or field_name == "" then
    return false, "field_name is required"
  end

  -- Validate field_name doesn't contain special characters
  if field_name:match("[:%s#]") then
    return false, "field_name cannot contain colons, spaces, or hashes"
  end

  -- Read the file
  local lines = vim.fn.readfile(file_path)
  if type(lines) ~= "table" then
    return false, "Failed to read file: " .. file_path
  end

  -- Find frontmatter bounds
  local fm_start, fm_end = find_frontmatter_bounds(lines)

  -- If no frontmatter exists and we're deleting (new_value is nil), success
  if not fm_start and (new_value == nil or new_value == vim.NIL) then
    return true
  end

  -- If no frontmatter exists and we need to create one
  if not fm_start then
    local new_lines = format_value(field_name, new_value)
    if #new_lines == 0 then
      return true -- Nothing to do
    end

    -- Create new frontmatter at the beginning
    local result = { "---" }
    for _, line in ipairs(new_lines) do
      table.insert(result, line)
    end
    table.insert(result, "---")

    -- Add original content
    for _, line in ipairs(lines) do
      table.insert(result, line)
    end

    local write_result = vim.fn.writefile(result, file_path)
    if write_result == -1 then
      return false, "Failed to write file: " .. file_path
    end
    return true
  end

  -- Extract frontmatter content (excluding delimiters)
  local fm_lines = {}
  for i = fm_start + 1, fm_end - 1 do
    table.insert(fm_lines, lines[i])
  end

  -- Find the field in frontmatter
  local field_start, field_end = find_field_range(fm_lines, field_name)

  -- Format the new value
  local new_lines = format_value(field_name, new_value)

  -- Build the new frontmatter content
  local new_fm_lines = {}

  if field_start then
    -- Field exists, replace or delete
    -- Add lines before the field
    for i = 1, field_start - 1 do
      table.insert(new_fm_lines, fm_lines[i])
    end

    -- Add new value (if not deleting)
    for _, line in ipairs(new_lines) do
      table.insert(new_fm_lines, line)
    end

    -- Add lines after the field
    for i = field_end + 1, #fm_lines do
      table.insert(new_fm_lines, fm_lines[i])
    end
  else
    -- Field doesn't exist, append if we have a value
    new_fm_lines = vim.deepcopy(fm_lines)

    if #new_lines > 0 then
      for _, line in ipairs(new_lines) do
        table.insert(new_fm_lines, line)
      end
    end
  end

  -- Rebuild the complete file
  local result = {}

  -- Add content before frontmatter (if any, though there shouldn't be)
  for i = 1, fm_start - 1 do
    table.insert(result, lines[i])
  end

  -- Add frontmatter
  table.insert(result, "---")
  for _, line in ipairs(new_fm_lines) do
    table.insert(result, line)
  end
  table.insert(result, lines[fm_end]) -- Preserve original closing delimiter

  -- Add content after frontmatter
  for i = fm_end + 1, #lines do
    table.insert(result, lines[i])
  end

  -- Write the file
  local write_result = vim.fn.writefile(result, file_path)
  if write_result == -1 then
    return false, "Failed to write file: " .. file_path
  end

  return true
end

return M
