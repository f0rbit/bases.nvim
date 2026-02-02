-- Detection of ![[*.base]] embeds and ```base code blocks in markdown files
local M = {}

---Pattern to match ![[name.base]] embeds
---Matches: optional leading whitespace, ![[, base name with .base extension, ]], optional trailing whitespace
local EMBED_PATTERN = '^%s*!%[%[([^%]]+%.base)%]%]%s*$'

---Patterns to match ```base fenced code blocks
local CODEBLOCK_OPEN_PATTERN = '^%s*```base%s*$'
local CODEBLOCK_CLOSE_PATTERN = '^%s*```%s*$'

---Scan a buffer for all ![[*.base]] embed patterns
---@param buf number Buffer handle
---@return table[] List of embed info {type='file', source='name.base', line_start, line_end}
function M.scan_buffer(buf)
    local embeds = {}
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for i, line in ipairs(lines) do
        local source = line:match(EMBED_PATTERN)
        if source then
            table.insert(embeds, {
                type = 'file',
                source = source,
                line_start = i,  -- 1-indexed
                line_end = i,    -- Single line embed
            })
        end
    end

    return embeds
end

---Scan a buffer for all ```base fenced code blocks
---@param buf number Buffer handle
---@return table[] List of embed info {type='codeblock', source=yaml_string, line_start, line_end, content_start, content_end}
function M.scan_codeblocks(buf)
    local embeds = {}
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local i = 1

    while i <= #lines do
        if lines[i]:match(CODEBLOCK_OPEN_PATTERN) then
            local open_line = i
            local j = i + 1
            local found_close = false

            while j <= #lines do
                if lines[j]:match(CODEBLOCK_CLOSE_PATTERN) then
                    -- Extract YAML content between fences
                    local content_lines = {}
                    for k = open_line + 1, j - 1 do
                        table.insert(content_lines, lines[k])
                    end
                    local yaml_string = table.concat(content_lines, '\n')

                    table.insert(embeds, {
                        type = 'codeblock',
                        source = yaml_string,
                        line_start = open_line,     -- 1-indexed
                        line_end = j,               -- 1-indexed
                        content_start = open_line + 1,  -- 1-indexed
                        content_end = j - 1,            -- 1-indexed
                    })

                    i = j + 1
                    found_close = true
                    break
                end
                j = j + 1
            end

            -- Skip unterminated fences
            if not found_close then
                i = i + 1
            end
        else
            i = i + 1
        end
    end

    return embeds
end

---Scan a buffer for all embeds (file embeds + code blocks), sorted by line_start
---@param buf number Buffer handle
---@return table[] Merged list of embeds sorted by line_start
function M.scan_all(buf)
    local file_embeds = M.scan_buffer(buf)
    local codeblock_embeds = M.scan_codeblocks(buf)

    -- Merge both lists
    local all = {}
    for _, e in ipairs(file_embeds) do
        table.insert(all, e)
    end
    for _, e in ipairs(codeblock_embeds) do
        table.insert(all, e)
    end

    -- Sort by line_start
    table.sort(all, function(a, b)
        return a.line_start < b.line_start
    end)

    return all
end

---Extract base name from source (remove .base extension)
---@param source string Source like "projects.base"
---@return string Base name like "projects"
function M.base_name(source)
    return source:gsub('%.base$', '')
end

return M
