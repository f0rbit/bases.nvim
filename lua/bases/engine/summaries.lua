local types = require("bases.engine.expr.types")
local evaluator_mod = require("bases.engine.expr.evaluator")

local M = {}

---Format a summary function name as a display label
---@param s string Function name (e.g., "sum", "date_range")
---@return string Capitalized label (e.g., "Sum", "Date range")
local function format_label(s)
    local label = s:gsub("_", " ")
    return label:sub(1, 1):upper() .. label:sub(2)
end

---Convert a SerializedValue back to a TypedValue
---@param sv SerializedValue
---@return TypedValue
local function serialized_to_typed(sv)
	if sv.type == "null" then
		return types.null()
	elseif sv.type == "primitive" then
		local v = sv.value
		if type(v) == "number" then
			return types.number(v)
		elseif type(v) == "boolean" then
			return types.boolean(v)
		else
			return types.string(tostring(v))
		end
	elseif sv.type == "date" then
		return types.date(sv.value)
	elseif sv.type == "link" then
		return types.from_raw(sv.value)
	elseif sv.type == "list" then
		local items = {}
		for _, item_sv in ipairs(sv.value) do
			table.insert(items, serialized_to_typed(item_sv))
		end
		return types.list(items)
	elseif sv.type == "image" then
		return types.string(sv.value)
	else
		return types.null()
	end
end

---Collect all SerializedValues for a property from entries
---@param entries SerializedEntry[]
---@param property string
---@return SerializedValue[]
local function collect_column_values(entries, property)
	local values = {}
	for _, entry in ipairs(entries) do
		local sv = entry.values and entry.values[property]
		table.insert(values, sv or { type = "null" })
	end
	return values
end

---Extract numeric values from SerializedValues
---@param serialized_values SerializedValue[]
---@return number[]
local function extract_numbers(serialized_values)
	local numbers = {}
	for _, sv in ipairs(serialized_values) do
		if sv.type == "primitive" then
			local num = tonumber(sv.value)
			if num then
				table.insert(numbers, num)
			end
		end
	end
	return numbers
end

---Extract date values (milliseconds) from SerializedValues
---@param serialized_values SerializedValue[]
---@return number[]
local function extract_dates(serialized_values)
	local dates = {}
	for _, sv in ipairs(serialized_values) do
		if sv.type == "date" then
			table.insert(dates, sv.value)
		end
	end
	return dates
end

---Check if a SerializedValue is empty
---@param sv SerializedValue
---@return boolean
local function is_empty_value(sv)
	if sv.type == "null" then
		return true
	elseif sv.type == "primitive" then
		return sv.value == nil or sv.value == ""
	elseif sv.type == "list" then
		return #sv.value == 0
	end
	return false
end

---Serialize a value to string for uniqueness comparison
---@param sv SerializedValue
---@return string
local function serialize_for_comparison(sv)
	if sv.type == "null" then
		return "null"
	elseif sv.type == "primitive" then
		return tostring(sv.value)
	elseif sv.type == "date" then
		return "date:" .. tostring(sv.value)
	elseif sv.type == "link" then
		return "link:" .. tostring(sv.value)
	elseif sv.type == "image" then
		return "image:" .. tostring(sv.value)
	elseif sv.type == "list" then
		local parts = {}
		for _, item in ipairs(sv.value) do
			table.insert(parts, serialize_for_comparison(item))
		end
		return "list:[" .. table.concat(parts, ",") .. "]"
	end
	return ""
end

---Built-in summary function dispatch table
---@type table<string, fun(serialized_values: SerializedValue[]): SerializedValue>
local BUILTIN_SUMMARIES = {
	-- Universal
	["empty"] = function(serialized_values)
		local count = 0
		for _, sv in ipairs(serialized_values) do
			if is_empty_value(sv) then
				count = count + 1
			end
		end
		return { type = "primitive", value = count }
	end,

	["filled"] = function(serialized_values)
		local count = 0
		for _, sv in ipairs(serialized_values) do
			if not is_empty_value(sv) then
				count = count + 1
			end
		end
		return { type = "primitive", value = count }
	end,

	["unique"] = function(serialized_values)
		local seen = {}
		local count = 0
		for _, sv in ipairs(serialized_values) do
			if sv.type ~= "null" then
				local key = serialize_for_comparison(sv)
				if not seen[key] then
					seen[key] = true
					count = count + 1
				end
			end
		end
		return { type = "primitive", value = count }
	end,

	-- Numeric
	["sum"] = function(serialized_values)
		local numbers = extract_numbers(serialized_values)
		if #numbers == 0 then
			return { type = "null" }
		end
		local sum = 0
		for _, n in ipairs(numbers) do
			sum = sum + n
		end
		return { type = "primitive", value = sum }
	end,

	["average"] = function(serialized_values)
		local numbers = extract_numbers(serialized_values)
		if #numbers == 0 then
			return { type = "null" }
		end
		local sum = 0
		for _, n in ipairs(numbers) do
			sum = sum + n
		end
		return { type = "primitive", value = sum / #numbers }
	end,

	["median"] = function(serialized_values)
		local numbers = extract_numbers(serialized_values)
		if #numbers == 0 then
			return { type = "null" }
		end
		table.sort(numbers)
		local mid = math.floor(#numbers / 2)
		local median
		if #numbers % 2 == 0 then
			median = (numbers[mid] + numbers[mid + 1]) / 2
		else
			median = numbers[mid + 1]
		end
		return { type = "primitive", value = median }
	end,

	["min"] = function(serialized_values)
		local numbers = extract_numbers(serialized_values)
		if #numbers == 0 then
			return { type = "null" }
		end
		local min_val = numbers[1]
		for i = 2, #numbers do
			if numbers[i] < min_val then
				min_val = numbers[i]
			end
		end
		return { type = "primitive", value = min_val }
	end,

	["max"] = function(serialized_values)
		local numbers = extract_numbers(serialized_values)
		if #numbers == 0 then
			return { type = "null" }
		end
		local max_val = numbers[1]
		for i = 2, #numbers do
			if numbers[i] > max_val then
				max_val = numbers[i]
			end
		end
		return { type = "primitive", value = max_val }
	end,

	["range"] = function(serialized_values)
		local numbers = extract_numbers(serialized_values)
		if #numbers == 0 then
			return { type = "null" }
		end
		local min_val = numbers[1]
		local max_val = numbers[1]
		for i = 2, #numbers do
			if numbers[i] < min_val then
				min_val = numbers[i]
			end
			if numbers[i] > max_val then
				max_val = numbers[i]
			end
		end
		return { type = "primitive", value = max_val - min_val }
	end,

	["stddev"] = function(serialized_values)
		local numbers = extract_numbers(serialized_values)
		if #numbers < 2 then
			return { type = "null" }
		end
		local sum = 0
		for _, n in ipairs(numbers) do
			sum = sum + n
		end
		local mean = sum / #numbers
		local variance_sum = 0
		for _, n in ipairs(numbers) do
			local diff = n - mean
			variance_sum = variance_sum + (diff * diff)
		end
		return { type = "primitive", value = math.sqrt(variance_sum / #numbers) }
	end,

	-- Date
	["earliest"] = function(serialized_values)
		local earliest_sv = nil
		for _, sv in ipairs(serialized_values) do
			if sv.type == "date" then
				if not earliest_sv or sv.value < earliest_sv.value then
					earliest_sv = sv
				end
			end
		end
		return earliest_sv or { type = "null" }
	end,

	["latest"] = function(serialized_values)
		local latest_sv = nil
		for _, sv in ipairs(serialized_values) do
			if sv.type == "date" then
				if not latest_sv or sv.value > latest_sv.value then
					latest_sv = sv
				end
			end
		end
		return latest_sv or { type = "null" }
	end,

	["date_range"] = function(serialized_values)
		local dates = extract_dates(serialized_values)
		if #dates < 2 then
			return { type = "null" }
		end
		local min_date = dates[1]
		local max_date = dates[1]
		for i = 2, #dates do
			if dates[i] < min_date then
				min_date = dates[i]
			end
			if dates[i] > max_date then
				max_date = dates[i]
			end
		end
		local diff_days = (max_date - min_date) / (1000 * 60 * 60 * 24)
		return { type = "primitive", value = math.floor(diff_days * 10 + 0.5) / 10 }
	end,

	-- Checkbox
	["checked"] = function(serialized_values)
		local count = 0
		for _, sv in ipairs(serialized_values) do
			if sv.type == "primitive" and sv.value == true then
				count = count + 1
			end
		end
		return { type = "primitive", value = count }
	end,

	["unchecked"] = function(serialized_values)
		local count = 0
		for _, sv in ipairs(serialized_values) do
			if sv.type == "primitive" and sv.value == false then
				count = count + 1
			end
		end
		return { type = "primitive", value = count }
	end,
}

---Evaluate a custom formula expression with values bound
---@param expression string
---@param serialized_values SerializedValue[]
---@return SerializedValue
local function eval_custom_formula(expression, serialized_values)
	local query_engine = require("bases.engine.query_engine")

	local typed_items = {}
	for _, sv in ipairs(serialized_values) do
		table.insert(typed_items, serialized_to_typed(sv))
	end

	local typed_list = types.list(typed_items)
	local evaluator = evaluator_mod.new({ frontmatter = {} }, {}, nil, nil)
	evaluator.values_binding = typed_list

	local result = evaluator:eval_string(expression)
	return query_engine.serialize_value(result)
end

---@class SummaryEntry
---@field label string Display label (e.g., "Sum", "Date range", "Formula")
---@field value SerializedValue

---Compute summary values for configured columns
---@param summaries_config table<string, string>
---@param entries SerializedEntry[]
---@param properties string[]
---@return table<string, SummaryEntry>|nil
function M.compute(summaries_config, entries, properties)
	if not summaries_config or vim.tbl_isempty(summaries_config) then
		return nil
	end

	local results = {}

	for property, func_or_expr in pairs(summaries_config) do
		local column_values = collect_column_values(entries, property)
		local func_lower = func_or_expr:lower()

		if BUILTIN_SUMMARIES[func_lower] then
			results[property] = {
				label = format_label(func_or_expr),
				value = BUILTIN_SUMMARIES[func_lower](column_values),
			}
		else
			results[property] = {
				label = "Formula",
				value = eval_custom_formula(func_or_expr, column_values),
			}
		end
	end

	return results
end

return M
