-- Forked from miller3616/bases.nvim (GPL-3.0)
-- Original: lua/bases/engine/query_engine.lua
-- Modified: replaced vim.tbl_* with compat.*, extracted serialize_value to serialize.lua

---@class SerializedEntry
---@field file {path: string, name: string, basename: string}
---@field values table<string, SerializedValue>

---@class SerializedResult
---@field properties string[] -- ordered list of column names
---@field entries SerializedEntry[]
---@field limit number|nil
---@field defaultSort {property: string, direction: string}|nil
---@field propertyLabels table<string, string>
---@field views {count: number, current: number, names: string[]}
---@field summaries table<string, SummaryEntry>|nil

local types = require('bases.engine.expr.types')
local evaluator_mod = require('bases.engine.expr.evaluator')
local compat = require('bases.compat')
local serialize = require('bases.engine.serialize')

local M = {}

local serialize_value = serialize.serialize_value

---Evaluate a filter node against an evaluator
---@param evaluator Evaluator
---@param node FilterNode|nil
---@return boolean
local function evaluate_filter_node(evaluator, node)
    if not node then
        return true
    end

    if node.type == "expression" then
        local result = evaluator:eval_string(node.expression)
        return types.is_truthy(result)
    elseif node.type == "and" then
        for _, child in ipairs(node.children) do
            if not evaluate_filter_node(evaluator, child) then
                return false
            end
        end
        return true
    elseif node.type == "or" then
        for _, child in ipairs(node.children) do
            if evaluate_filter_node(evaluator, child) then
                return true
            end
        end
        return false
    elseif node.type == "not" then
        for _, child in ipairs(node.children) do
            if evaluate_filter_node(evaluator, child) then
                return false
            end
        end
        return true
    end

    return true
end

---Extract index optimization hints from filter node
---@param node FilterNode|nil
---@return {type: "tag"|"folder", value: string}|nil
local function extract_index_hint(node)
    if not node then
        return nil
    end

    -- Check for simple expression pattern
    if node.type == "expression" then
        local expr = node.expression
        -- Match file.hasTag("tagname")
        local tag = expr:match('^file%.hasTag%("([^"]+)"%)')
        if tag then
            return { type = "tag", value = tag }
        end
        -- Match file.inFolder("foldername")
        local folder = expr:match('^file%.inFolder%("([^"]+)"%)')
        if folder then
            return { type = "folder", value = folder }
        end
    elseif node.type == "and" then
        -- Check children for simple patterns
        for _, child in ipairs(node.children) do
            local hint = extract_index_hint(child)
            if hint then
                return hint
            end
        end
    end

    return nil
end

---Collect candidate notes from the index, using optimization hints
---@param note_index NoteIndex
---@param global_filters FilterNode|nil
---@return NoteData[]
local function collect_candidates(note_index, global_filters)
    local hint = extract_index_hint(global_filters)

    if hint and hint.type == "tag" and note_index.by_tag then
        -- by_tag stores path->true sets, resolve to NoteData array
        local path_set = note_index.by_tag[hint.value] or {}
        local results = {}
        for path, _ in pairs(path_set) do
            local note = note_index:get(path)
            if note then
                table.insert(results, note)
            end
        end
        return results
    elseif hint and hint.type == "folder" and note_index.by_folder then
        -- by_folder stores path->true sets, resolve to NoteData array
        local path_set = note_index.by_folder[hint.value] or {}
        local results = {}
        for path, _ in pairs(path_set) do
            local note = note_index:get(path)
            if note then
                table.insert(results, note)
            end
        end
        return results
    else
        -- notes is path->NoteData map, convert to array
        local all = note_index:all()
        local results = {}
        for _, note in pairs(all) do
            table.insert(results, note)
        end
        return results
    end
end

---Perform topological sort on formulas to resolve dependencies
---@param formulas table<string, string>
---@return string[] -- ordered list of formula names
local function topological_sort_formulas(formulas)
    if not formulas or compat.tbl_isempty(formulas) then
        return {}
    end

    -- Build dependency graph
    local deps = {} ---@type table<string, string[]>
    for name, expr in pairs(formulas) do
        deps[name] = {}
        -- Find references to other formulas (formula.X pattern)
        for ref in expr:gmatch("formula%.([%w_]+)") do
            if formulas[ref] then
                table.insert(deps[name], ref)
            end
        end
    end

    -- Kahn's algorithm
    local in_degree = {}
    for name, _ in pairs(formulas) do
        in_degree[name] = 0
    end
    for _, dep_list in pairs(deps) do
        for _, dep in ipairs(dep_list) do
            in_degree[dep] = (in_degree[dep] or 0) + 1
        end
    end

    local queue = {}
    for name, degree in pairs(in_degree) do
        if degree == 0 then
            table.insert(queue, name)
        end
    end

    local sorted = {}
    while #queue > 0 do
        local name = table.remove(queue, 1)
        table.insert(sorted, name)

        for _, neighbor in ipairs(deps[name]) do
            in_degree[neighbor] = in_degree[neighbor] - 1
            if in_degree[neighbor] == 0 then
                table.insert(queue, neighbor)
            end
        end
    end

    -- If we haven't sorted all formulas, there's a cycle - just use arbitrary order
    if #sorted < compat.tbl_count(formulas) then
        sorted = compat.tbl_keys(formulas)
    end

    return sorted
end

---Resolve visible properties for the view
---@param view ViewConfig
---@param candidates NoteData[]
---@param formulas table<string, string>
---@return string[]
local function resolve_properties(view, candidates, formulas)
    if view.order and #view.order > 0 then
        -- Use explicit order from view config
        local props = {}
        for _, prop in ipairs(view.order) do
            -- Normalize property names to have prefixes
            if not prop:match("^[^.]+%.") then
                -- No prefix - assume note.* for frontmatter properties
                table.insert(props, "note." .. prop)
            else
                table.insert(props, prop)
            end
        end
        return props
    end

    -- Auto-discover properties
    local prop_set = { ["file.name"] = true }
    local props = { "file.name" } -- file.name always first

    -- Collect from frontmatter
    for _, note in ipairs(candidates) do
        if note.frontmatter then
            for key, _ in pairs(note.frontmatter) do
                local prop = "note." .. key
                if not prop_set[prop] then
                    prop_set[prop] = true
                    table.insert(props, prop)
                end
            end
        end
    end

    -- Add formulas
    if formulas then
        for name, _ in pairs(formulas) do
            local prop = "formula." .. name
            if not prop_set[prop] then
                prop_set[prop] = true
                table.insert(props, prop)
            end
        end
    end

    return props
end

---Build a SerializedEntry for a note
---@param note NoteData
---@param properties string[]
---@param evaluator Evaluator
---@return SerializedEntry
local function build_entry(note, properties, evaluator)
    local entry = {
        file = {
            path = note.path,
            name = note.name,
            basename = note.basename,
        },
        values = {},
    }

    for _, prop in ipairs(properties) do
        local prefix, name = prop:match("^([^.]+)%.(.+)$")

        if prefix == "file" then
            if name == "name" then
                -- Special case: file.name is always a link
                entry.values[prop] = {
                    type = "link",
                    value = "[[" .. note.basename .. "]]",
                    path = note.path,
                }
            else
                -- Evaluate via evaluator's file namespace
                local result = evaluator:eval_string("file." .. name)
                entry.values[prop] = serialize_value(result)
            end
        elseif prefix == "note" then
            -- Get from frontmatter
            local raw_value = note.frontmatter and note.frontmatter[name] or nil
            local typed_value = types.from_raw(raw_value)
            entry.values[prop] = serialize_value(typed_value)
        elseif prefix == "formula" then
            -- Evaluate formula
            local result = evaluator:eval_string("formula." .. name)
            entry.values[prop] = serialize_value(result)
        else
            -- Unknown prefix - treat as null
            entry.values[prop] = { type = "null" }
        end
    end

    return entry
end

---Execute a query against the note index
---@param query_config QueryConfig
---@param note_index NoteIndex
---@param view_index number -- 0-based index
---@param this_file string|nil -- path to the current file (for context)
---@return SerializedResult
function M.execute(query_config, note_index, view_index, this_file)
    -- 1. Select view
    view_index = view_index or 0
    local view = query_config.views and query_config.views[view_index + 1] or query_config.views[1]
    if not view then
        error("No views defined in query config")
    end

    -- 2. Collect candidates
    local candidates = collect_candidates(note_index, query_config.filters)

    -- 3. Resolve visible properties
    local properties = resolve_properties(view, candidates, query_config.formulas)

    -- 4. Topological sort formulas
    local formula_order = topological_sort_formulas(query_config.formulas)

    -- 5 & 6. Filter and build entries
    local entries = {}
    for _, note in ipairs(candidates) do
        -- Create evaluator for this note
        local evaluator = evaluator_mod.new(note, query_config.formulas, note_index, this_file)

        -- Evaluate global filters
        local passes_global = evaluate_filter_node(evaluator, query_config.filters)
        if not passes_global then
            goto continue
        end

        -- Evaluate view-specific filters
        local passes_view = evaluate_filter_node(evaluator, view.filters)
        if not passes_view then
            goto continue
        end

        -- Build entry
        local entry = build_entry(note, properties, evaluator)
        table.insert(entries, entry)

        ::continue::
    end

    -- 8. Compute summaries (on all filtered entries, before limit)
    local summaries_result = nil
    if view.summaries then
        local summaries_mod = require('bases.engine.summaries')
        summaries_result = summaries_mod.compute(view.summaries, entries, properties)
    end

    -- 9. Build metadata
    local default_sort = nil
    if view.sort and #view.sort > 0 then
        default_sort = {
            property = view.sort[1].column,
            direction = view.sort[1].direction:lower(),
        }
    end

    local property_labels = {}
    if query_config.properties then
        for name, prop_config in pairs(query_config.properties) do
            if prop_config.display_name then
                -- Normalize property name
                local full_name = name:match("^[^.]+%.") and name or ("note." .. name)
                property_labels[full_name] = prop_config.display_name
            end
        end
    end

    local view_names = {}
    if query_config.views then
        for _, v in ipairs(query_config.views) do
            table.insert(view_names, v.name or "Unnamed View")
        end
    end

    local views_meta = {
        count = query_config.views and #query_config.views or 0,
        current = view_index,
        names = view_names,
    }

    -- 10. Return SerializedResult
    return {
        properties = properties,
        entries = entries,
        limit = view.limit,
        defaultSort = default_sort,
        propertyLabels = property_labels,
        views = views_meta,
        summaries = summaries_result,
    }
end

M.serialize_value = serialize_value

return M
