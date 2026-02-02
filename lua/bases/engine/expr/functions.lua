---Global function implementations for the expression engine
local types = require("bases.engine.expr.types")

local M = {}

---Call a global function
---@param name string The function name
---@param args TypedValue[] The evaluated arguments
---@param evaluator Evaluator The evaluator instance (for context if needed)
---@return TypedValue
function M.call(name, args, evaluator)
	if name == "date" then
		return M.fn_date(args)
	elseif name == "today" then
		return M.fn_today(args)
	elseif name == "now" then
		return M.fn_now(args)
	elseif name == "if" then
		return M.fn_if(args)
	elseif name == "image" then
		return M.fn_image(args)
	elseif name == "max" then
		return M.fn_max(args)
	elseif name == "min" then
		return M.fn_min(args)
	elseif name == "link" then
		return M.fn_link(args)
	elseif name == "list" then
		return M.fn_list(args)
	elseif name == "number" then
		return M.fn_number(args)
	elseif name == "duration" then
		return M.fn_duration(args)
	else
		-- Unknown function
		return types.null()
	end
end

---Parse a string to a date
---@param args TypedValue[]
---@return TypedValue
function M.fn_date(args)
	if #args < 1 then
		return types.null()
	end

	local str = types.to_string(args[1])
	local result = types.date_from_iso(str)
	if result then
		return result
	end

	return types.null()
end

---Get current date at midnight
---@param args TypedValue[]
---@return TypedValue
function M.fn_today(args)
	local now = os.date("*t")
	local midnight = os.time({
		year = now.year,
		month = now.month,
		day = now.day,
		hour = 0,
		min = 0,
		sec = 0,
	})
	return types.date(midnight * 1000)
end

---Get current datetime
---@param args TypedValue[]
---@return TypedValue
function M.fn_now(args)
	return types.date(os.time() * 1000)
end

---Conditional expression
---@param args TypedValue[]
---@return TypedValue
function M.fn_if(args)
	if #args < 2 then
		return types.null()
	end

	local condition = args[1]
	local true_val = args[2]
	local false_val = args[3] or types.null()

	if types.is_truthy(condition) then
		return true_val
	else
		return false_val
	end
end

---Create an image typed value
---@param args TypedValue[]
---@return TypedValue
function M.fn_image(args)
	if #args < 1 then
		return types.null()
	end

	local path = types.to_string(args[1])
	return types.image(path)
end

---Get maximum of numbers
---@param args TypedValue[]
---@return TypedValue
function M.fn_max(args)
	if #args == 0 then
		return types.null()
	end

	local max_val = nil
	for _, arg in ipairs(args) do
		local n = types.to_number(arg)
		if n then
			if max_val == nil or n > max_val then
				max_val = n
			end
		end
	end

	if max_val then
		return types.number(max_val)
	end

	return types.null()
end

---Get minimum of numbers
---@param args TypedValue[]
---@return TypedValue
function M.fn_min(args)
	if #args == 0 then
		return types.null()
	end

	local min_val = nil
	for _, arg in ipairs(args) do
		local n = types.to_number(arg)
		if n then
			if min_val == nil or n < min_val then
				min_val = n
			end
		end
	end

	if min_val then
		return types.number(min_val)
	end

	return types.null()
end

---Create a link typed value
---@param args TypedValue[]
---@return TypedValue
function M.fn_link(args)
	if #args < 1 then
		return types.null()
	end

	local path = types.to_string(args[1])
	local display = nil
	if #args >= 2 then
		display = types.to_string(args[2])
	end

	return types.link(path, display)
end

---Wrap value in a list (or return if already a list)
---@param args TypedValue[]
---@return TypedValue
function M.fn_list(args)
	if #args == 0 then
		return types.list({})
	end

	local arg = args[1]
	if arg.type == "list" then
		return arg
	end

	return types.list({ arg })
end

---Convert value to number
---@param args TypedValue[]
---@return TypedValue
function M.fn_number(args)
	if #args == 0 then
		return types.null()
	end

	local n = types.to_number(args[1])
	if n then
		return types.number(n)
	end

	return types.null()
end

---Parse duration string
---@param args TypedValue[]
---@return TypedValue
function M.fn_duration(args)
	if #args == 0 then
		return types.null()
	end

	local str = types.to_string(args[1])
	local ms = types.parse_duration(str)
	if ms then
		return types.duration(ms)
	end

	return types.duration(0)
end

return M
