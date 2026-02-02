-- Dashboard rendering - title rendering and section composition
local M = {}

-- Unicode double-line character for title underlines
local UNDERLINE_CHAR = '═'

---Calculate display width of a string (accounting for multi-byte characters)
---@param str string
---@return number
local function display_width(str)
    return vim.fn.strdisplaywidth(str)
end

---Render a title with underline
---@param title string Title text
---@return string[] lines Two lines: title and underline
function M.render_title(title)
    local width = display_width(title)
    local underline = string.rep(UNDERLINE_CHAR, width)
    return { title, underline }
end

---@class DashboardSection
---@field base string Base name
---@field title string Section title
---@field max_rows number|nil Maximum rows to display

---@class DashboardConfig
---@field title string|nil Main dashboard title
---@field sections DashboardSection[] Sections to render
---@field spacing number|nil Lines between sections (default: 1)

---@class SectionData
---@field lines string[] Rendered table lines
---@field links table[] Link positions (with row offset applied)
---@field cells table[] Cell positions (with row offset applied)
---@field headers table[] Header positions (with row offset applied)
---@field section_index number Which section this data belongs to

---@class DashboardRenderResult
---@field lines string[] All rendered lines
---@field links table[] All link positions
---@field cells table[] All cell positions
---@field headers table[] All header positions
---@field section_starts number[] Line numbers where each section starts (1-indexed)

---Offset link/cell/header positions by a row amount
---@param items table[] Links, cells, or headers
---@param row_offset number Number of rows to add
---@param section_index number Section index to tag items with
---@return table[] New items with offset applied
local function offset_items(items, row_offset, section_index)
    local result = {}
    for _, item in ipairs(items) do
        local new_item = vim.deepcopy(item)
        new_item.row = new_item.row + row_offset
        new_item.section_index = section_index
        table.insert(result, new_item)
    end
    return result
end

---Render a complete dashboard from section data
---@param config DashboardConfig Dashboard configuration
---@param section_data table[] Array of {lines, links, cells, headers, base_name} for each section
---@param use_markdown boolean|nil Whether markdown tables are being used
---@return DashboardRenderResult
function M.render_dashboard(config, section_data, use_markdown)
    local lines = {}
    local all_links = {}
    local all_cells = {}
    local all_headers = {}
    local section_starts = {}
    local spacing = config.spacing or 1

    -- Render main title if present
    if config.title and config.title ~= '' then
        local title_lines = M.render_title(config.title)
        for _, line in ipairs(title_lines) do
            table.insert(lines, line)
        end
        -- Add blank line after main title
        table.insert(lines, '')
    end

    -- Render each section
    for i, data in ipairs(section_data) do
        local section_config = config.sections[i]
        if not section_config then
            goto continue
        end

        -- Record section start line (1-indexed)
        table.insert(section_starts, #lines + 1)

        -- Render section title
        local section_title = section_config.title or section_config.base
        local title_lines = M.render_title(section_title)
        for _, line in ipairs(title_lines) do
            table.insert(lines, line)
        end

        -- Current line count before adding table (for offset calculation)
        local row_offset = #lines

        -- Add table lines (limiting by max_rows if specified)
        -- Priority: section config max_rows > API limit from base file > show all
        local table_lines = data.lines or {}
        local max_rows = section_config.max_rows or (data.api_data and data.api_data.limit)

        if max_rows and #table_lines > 0 then
            -- Unicode tables: top_border(1) + header(1) + separator(1) = 3 header lines, bottom_border(1) = 1 footer
            -- Markdown tables: header(1) + separator(1) = 2 header lines, no footer
            -- When summaries exist: add summary_separator(1) + summary_row(1) to footer
            local header_lines = use_markdown and 2 or 3
            local has_summaries = data.has_summaries or false
            local summary_lines = has_summaries and 1 or 0
            local base_footer = use_markdown and 0 or 1
            local footer_lines = base_footer + summary_lines
            local available_data_rows = max_rows

            -- Calculate which lines to include
            local last_data_line = #table_lines - footer_lines
            local max_data_line = header_lines + available_data_rows

            if max_data_line < last_data_line then
                -- Need to truncate - include header lines, limited data, and footer
                for j = 1, header_lines do
                    table.insert(lines, table_lines[j])
                end
                for j = header_lines + 1, max_data_line do
                    table.insert(lines, table_lines[j])
                end
                -- Add footer lines (summary separator + summary row + bottom border)
                for j = #table_lines - footer_lines + 1, #table_lines do
                    table.insert(lines, table_lines[j])
                end
            else
                -- No truncation needed
                for _, line in ipairs(table_lines) do
                    table.insert(lines, line)
                end
            end
        else
            for _, line in ipairs(table_lines) do
                table.insert(lines, line)
            end
        end

        -- Offset and collect links
        local section_links = offset_items(data.links or {}, row_offset, i)
        for _, link in ipairs(section_links) do
            -- Apply max_rows filtering to links
            if not max_rows or link.row <= row_offset + 3 + max_rows + 1 then
                table.insert(all_links, link)
            end
        end

        -- Offset and collect cells
        local section_cells = offset_items(data.cells or {}, row_offset, i)
        for _, cell in ipairs(section_cells) do
            -- Apply max_rows filtering to cells
            if not max_rows or cell.row <= row_offset + 3 + max_rows + 1 then
                table.insert(all_cells, cell)
            end
        end

        -- Offset and collect headers
        local section_headers = offset_items(data.headers or {}, row_offset, i)
        for _, header in ipairs(section_headers) do
            table.insert(all_headers, header)
        end

        -- Add spacing between sections (except after last)
        if i < #section_data then
            for _ = 1, spacing do
                table.insert(lines, '')
            end
        end

        ::continue::
    end

    return {
        lines = lines,
        links = all_links,
        cells = all_cells,
        headers = all_headers,
        section_starts = section_starts,
    }
end

---Apply highlight to title lines
---@param buf number Buffer handle
---@param start_line number 0-indexed start line
---@param title_hl string Highlight group for title text
---@param underline_hl string Highlight group for underline
function M.highlight_title(buf, start_line, title_hl, underline_hl)
    local ns = vim.api.nvim_create_namespace('bases_dashboard_titles')

    -- Highlight title text
    vim.api.nvim_buf_add_highlight(buf, ns, title_hl, start_line, 0, -1)

    -- Highlight underline
    vim.api.nvim_buf_add_highlight(buf, ns, underline_hl, start_line + 1, 0, -1)
end

---Apply all dashboard highlights
---@param buf number Buffer handle
---@param config DashboardConfig Dashboard configuration
---@param section_starts number[] Line numbers where sections start (1-indexed)
function M.apply_highlights(buf, config, section_starts)
    local ns = vim.api.nvim_create_namespace('bases_dashboard_titles')
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    local line_offset = 0

    -- Highlight main title if present
    if config.title and config.title ~= '' then
        M.highlight_title(buf, 0, 'BasesDashboardTitle', 'BasesDashboardTitle')
        line_offset = 3  -- title + underline + blank line
    end

    -- Highlight section titles
    for i, start_line in ipairs(section_starts) do
        -- section_starts is 1-indexed, convert to 0-indexed for API
        M.highlight_title(buf, start_line - 1, 'BasesDashboardSectionTitle', 'BasesDashboardSectionTitle')
    end
end

return M
