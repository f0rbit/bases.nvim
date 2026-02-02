-- Data transformation layer for unified rendering
-- Ensures consistent sort-before-limit ordering across all contexts
local M = {}

---Prepare raw data for rendering by applying sort and limit transformations
---@param raw_data table API response data with properties, entries, and optional limit/defaultSort
---@param view_state table|nil View state with optional sort {property, direction}
---@return table DisplayData with properties, entries, sort_state
function M.prepare(raw_data, view_state)
    local render = require('bases.render')
    local entries = raw_data.entries or {}
    local view = view_state or {}

    -- Compute effective sort: user override OR default from API response
    local effective_sort = view.sort or raw_data.defaultSort

    -- 1. Sort first (if effective sort exists)
    if effective_sort and effective_sort.property then
        entries = render.sort_entries(entries, effective_sort.property, effective_sort.direction)
    end

    -- 2. Limit after sort
    local limit = view.limit or raw_data.limit
    if limit and limit > 0 and #entries > limit then
        local limited = {}
        for i = 1, limit do
            limited[i] = entries[i]
        end
        entries = limited
    end

    return {
        properties = raw_data.properties or {},
        entries = entries,
        sort_state = effective_sort,
        property_labels = raw_data.propertyLabels,  -- Custom column labels from API
        summaries = raw_data.summaries,  -- Column summaries from query engine
    }
end

---Validate display data before rendering
---@param display_data table DisplayData from prepare()
---@return boolean valid True if data can be rendered
---@return string|nil error Error message if invalid
function M.validate(display_data)
    if #display_data.properties == 0 then
        return false, 'No properties defined in this base'
    end
    if #display_data.entries == 0 then
        return false, 'No entries found'
    end
    return true, nil
end

return M
