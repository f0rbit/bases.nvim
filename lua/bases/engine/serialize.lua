-- Forked from miller3616/bases.nvim (GPL-3.0)
-- Extracted from query_engine.lua to break circular dependency between query_engine and summaries

---@class SerializedValue
---@field type "null"|"primitive"|"date"|"link"|"list"|"image"
---@field value any
---@field path string|nil -- for links
---@field iso string|nil -- for dates

local types = require("bases.engine.expr.types")

local M = {}

---Serialize a TypedValue to SerializedValue format
---@param tv TypedValue
---@return SerializedValue
function M.serialize_value(tv)
    if tv.type == "null" then
        return { type = "null" }
    elseif tv.type == "string" then
        return { type = "primitive", value = tv.value }
    elseif tv.type == "number" then
        return { type = "primitive", value = tv.value }
    elseif tv.type == "boolean" then
        return { type = "primitive", value = tv.value }
    elseif tv.type == "date" then
        return { type = "date", value = tv.value, iso = types.date_to_iso(tv.value) }
    elseif tv.type == "link" then
        local display = tv.value or tv.path
        return { type = "link", value = "[[" .. display .. "]]", path = tv.path }
    elseif tv.type == "list" then
        local items = {}
        for _, item in ipairs(tv.value) do
            table.insert(items, M.serialize_value(item))
        end
        return { type = "list", value = items }
    elseif tv.type == "image" then
        return { type = "image", value = tv.value }
    else
        return { type = "primitive", value = types.to_string(tv) }
    end
end

return M
