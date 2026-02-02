-- HTTP client for Obsidian Bases API
local M = {}

---Build the API URL for a base
---@param config table Plugin configuration
---@param base_name string Name of the base (without extension)
---@param view_index number|nil Optional view index (0-based)
---@return string
local function build_url(config, base_name, view_index)
    local url = string.format('http://%s:%d/bases/%s', config.host, config.port, base_name)
    if view_index and view_index > 0 then
        url = url .. '?view=' .. view_index
    end
    return url
end

---Fetch base data from the API
---@param config table Plugin configuration
---@param base_name string Name of the base (without extension)
---@param callback fun(err: string|nil, data: table|nil)
---@param view_index number|nil Optional view index (0-based)
function M.fetch(config, base_name, callback, view_index)
    local url = build_url(config, base_name, view_index)
    local stdout_chunks = {}
    local stderr_chunks = {}

    local cmd = {
        'curl',
        '-s',
        '-H', 'Authorization: Bearer ' .. config.api_key,
        '-H', 'Accept: application/json',
        url,
    }

    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= '' then
                        table.insert(stdout_chunks, line)
                    end
                end
            end
        end,
        on_stderr = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= '' then
                        table.insert(stderr_chunks, line)
                    end
                end
            end
        end,
        on_exit = function(_, exit_code)
            vim.schedule(function()
                if exit_code ~= 0 then
                    local err_msg = table.concat(stderr_chunks, '\n')
                    if err_msg == '' then
                        err_msg = 'curl exited with code ' .. exit_code
                    end
                    callback(err_msg, nil)
                    return
                end

                local body = table.concat(stdout_chunks, '\n')
                if body == '' then
                    callback('Empty response from API', nil)
                    return
                end

                local ok, data = pcall(vim.json.decode, body)
                if not ok then
                    callback('Failed to parse JSON: ' .. tostring(data), nil)
                    return
                end

                if data.error then
                    callback('API error: ' .. tostring(data.error), nil)
                    return
                end

                callback(nil, data)
            end)
        end,
    })
end

---Build the API URL for updating an entry
---@param config table Plugin configuration
---@param base_name string Name of the base (without extension)
---@return string
local function build_entry_url(config, base_name)
    return string.format('http://%s:%d/bases/%s/entry', config.host, config.port, base_name)
end

---Update a property value in a note
---@param config table Plugin configuration
---@param base_name string Name of the base (without extension)
---@param file_path string Path to the note file
---@param property string Property name (e.g., "note.Person")
---@param value any New value (nil/vim.NIL to delete)
---@param callback fun(err: string|nil, data: table|nil)
function M.update_property(config, base_name, file_path, property, value, callback)
    local url = build_entry_url(config, base_name)
    local stdout_chunks = {}
    local stderr_chunks = {}

    -- Build request body
    local body = {
        file_path = file_path,
        property = property,
        value = value,
    }

    -- Handle vim.NIL for JSON null
    local json_body = vim.json.encode(body)

    local cmd = {
        'curl',
        '-s',
        '-X', 'PUT',
        '-H', 'Authorization: Bearer ' .. config.api_key,
        '-H', 'Content-Type: application/json',
        '-H', 'Accept: application/json',
        '-d', json_body,
        url,
    }

    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= '' then
                        table.insert(stdout_chunks, line)
                    end
                end
            end
        end,
        on_stderr = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= '' then
                        table.insert(stderr_chunks, line)
                    end
                end
            end
        end,
        on_exit = function(_, exit_code)
            vim.schedule(function()
                if exit_code ~= 0 then
                    local err_msg = table.concat(stderr_chunks, '\n')
                    if err_msg == '' then
                        err_msg = 'curl exited with code ' .. exit_code
                    end
                    callback(err_msg, nil)
                    return
                end

                local body_text = table.concat(stdout_chunks, '\n')
                if body_text == '' then
                    callback('Empty response from API', nil)
                    return
                end

                local ok, data = pcall(vim.json.decode, body_text)
                if not ok then
                    callback('Failed to parse JSON: ' .. tostring(data), nil)
                    return
                end

                if data.error then
                    callback('API error: ' .. tostring(data.error), nil)
                    return
                end

                callback(nil, data)
            end)
        end,
    })
end

return M
