-- bases.nvim — Unicode table renderer
-- Converts SerializedResult into formatted table lines + highlight positions
local M = {}

-- Box-drawing character sets
M.borders = {
  sharp = {
    tl = "┌", tr = "┐", bl = "└", br = "┘",
    h = "─", v = "│",
    t = "┬", b = "┴", l = "├", r = "┤", x = "┼",
    sl = "╞", sr = "╡", sx = "╪", sh = "═",
  },
  rounded = {
    tl = "╭", tr = "╮", bl = "╰", br = "╯",
    h = "─", v = "│",
    t = "┬", b = "┴", l = "├", r = "┤", x = "┼",
    sl = "╞", sr = "╡", sx = "╪", sh = "═",
  },
}

local DEFAULT_OPTS = {
  max_col_width = 40,
  min_col_width = 5,
  max_table_width = nil,
  alternating_rows = true,
  border_style = "rounded",
  null_char = "—",
  bool_true = "✓",
  bool_false = " ",
  list_separator = ", ",
}

local function strwidth(s)
  if vim and vim.api and vim.api.nvim_strwidth then
    return vim.api.nvim_strwidth(s)
  end
  return #s
end

local function merge_opts(opts)
  local merged = {}
  for k, v in pairs(DEFAULT_OPTS) do merged[k] = v end
  if opts then
    for k, v in pairs(opts) do merged[k] = v end
  end
  return merged
end

---Convert a SerializedValue to a display string
---@param sv SerializedValue
---@param opts table
---@return string
function M.render_serialized_value(sv, opts)
  if sv.type == "null" then
    return opts.null_char
  elseif sv.type == "primitive" then
    if type(sv.value) == "boolean" then
      return sv.value and opts.bool_true or opts.bool_false
    elseif type(sv.value) == "number" then
      local formatted = tostring(sv.value)
      if formatted:match("%.") then
        formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
      end
      return formatted
    else
      return tostring(sv.value)
    end
  elseif sv.type == "date" then
    return sv.iso or tostring(sv.value)
  elseif sv.type == "link" then
    return sv.value or ""
  elseif sv.type == "list" then
    local parts = {}
    for _, item in ipairs(sv.value or {}) do
      parts[#parts + 1] = M.render_serialized_value(item, opts)
    end
    return table.concat(parts, opts.list_separator)
  elseif sv.type == "image" then
    return "[image]"
  end
  return tostring(sv.value or "")
end

---Determine alignment for a SerializedValue
---@param sv SerializedValue
---@return "left"|"right"|"center"
function M.get_alignment(sv)
  if sv.type == "null" then return "center" end
  if sv.type == "primitive" then
    if type(sv.value) == "number" then return "right" end
    if type(sv.value) == "boolean" then return "center" end
  end
  return "left"
end

---Pad string to width with given alignment
---@param value string
---@param width integer
---@param alignment "left"|"right"|"center"
---@return string
local function pad(value, width, alignment)
  local vw = strwidth(value)
  if vw >= width then return value end
  local gap = width - vw
  if alignment == "right" then
    return string.rep(" ", gap) .. value
  elseif alignment == "center" then
    local left = math.floor(gap / 2)
    local right = gap - left
    return string.rep(" ", left) .. value .. string.rep(" ", right)
  end
  return value .. string.rep(" ", gap)
end

---Format a cell: render value, truncate to width, pad with alignment
---@param sv SerializedValue
---@param width integer
---@param opts table
---@return string
local function format_cell(sv, width, opts)
  local text = M.render_serialized_value(sv, opts)
  local alignment = M.get_alignment(sv)
  local tw = strwidth(text)
  if tw > width then
    local truncated = ""
    for i = 1, #text do
      local candidate = text:sub(1, i)
      if strwidth(candidate) > width - 1 then break end
      truncated = candidate
    end
    text = truncated .. "…"
    tw = strwidth(text)
    if tw > width then
      text = text:sub(1, width)
    end
  end
  return pad(text, width, alignment)
end

---Get header label for a property
---@param prop string
---@param labels table<string, string>|nil
---@return string
local function header_label(prop, labels)
  if labels and labels[prop] then return labels[prop] end
  return prop
end

---Calculate column widths from result data
---@param result SerializedResult
---@param opts table
---@return integer[]
local function calc_col_widths(result, opts)
  local props = result.properties or {}
  local n = #props
  if n == 0 then return {} end

  local widths = {}
  for i, prop in ipairs(props) do
    widths[i] = strwidth(header_label(prop, result.propertyLabels))
  end

  for _, entry in ipairs(result.entries or {}) do
    for i, prop in ipairs(props) do
      local sv = entry.values and entry.values[prop] or { type = "null" }
      local text = M.render_serialized_value(sv, opts)
      local tw = strwidth(text)
      if tw > widths[i] then widths[i] = tw end
    end
  end

  if result.summaries then
    for i, prop in ipairs(props) do
      local summary = result.summaries[prop]
      if summary then
        local label_text = summary.label .. ": "
        local val_text = M.render_serialized_value(summary.value, opts)
        local sw = strwidth(label_text .. val_text)
        if sw > widths[i] then widths[i] = sw end
      end
    end
  end

  for i = 1, n do
    widths[i] = math.max(widths[i], opts.min_col_width)
    widths[i] = math.min(widths[i], opts.max_col_width)
  end

  local max_w = opts.max_table_width
  if not max_w and vim and vim.o then
    max_w = vim.o.columns
  end
  if max_w then
    local border_overhead = n + 1 + n * 2
    local total = border_overhead
    for i = 1, n do total = total + widths[i] end

    if total > max_w then
      local avail = max_w - border_overhead
      if avail < n * opts.min_col_width then
        avail = n * opts.min_col_width
      end
      local content_total = 0
      for i = 1, n do content_total = content_total + widths[i] end

      local new_widths = {}
      local assigned = 0
      for i = 1, n do
        local w = math.floor(widths[i] / content_total * avail)
        w = math.max(w, opts.min_col_width)
        new_widths[i] = w
        assigned = assigned + w
      end
      local remainder = avail - assigned
      local sorted_indices = {}
      for i = 1, n do sorted_indices[i] = i end
      table.sort(sorted_indices, function(a, b) return new_widths[a] > new_widths[b] end)
      for j = 1, math.max(0, remainder) do
        local idx = sorted_indices[((j - 1) % n) + 1]
        new_widths[idx] = new_widths[idx] + 1
      end
      widths = new_widths
    end
  end

  return widths
end

---Render a horizontal border line
---@param widths integer[]
---@param b table Border character set
---@param left string Left corner/junction
---@param mid string Middle junction
---@param right string Right corner/junction
---@param fill string|nil Horizontal fill character (defaults to b.h)
---@return string
local function render_border(widths, b, left, mid, right, fill)
  fill = fill or b.h
  local parts = { left }
  for i, w in ipairs(widths) do
    parts[#parts + 1] = string.rep(fill, w + 2)
    if i < #widths then
      parts[#parts + 1] = mid
    end
  end
  parts[#parts + 1] = right
  return table.concat(parts)
end

---Render a data row from pre-formatted cell strings
---@param cells string[]
---@param b table Border character set
---@return string
local function render_row(cells, b)
  local parts = { b.v }
  for _, cell in ipairs(cells) do
    parts[#parts + 1] = " " .. cell .. " "
    parts[#parts + 1] = b.v
  end
  return table.concat(parts)
end

---Determine the highlight group for a SerializedValue type
---@param sv SerializedValue
---@return string
local function hl_group_for(sv)
  if sv.type == "null" then return "BasesTableNull" end
  if sv.type == "primitive" then
    if type(sv.value) == "boolean" then return "BasesTableBoolean" end
    if type(sv.value) == "number" then return "BasesTableNumber" end
  end
  if sv.type == "link" then return "BasesTableLink" end
  return "BasesTableRow"
end

---@param result SerializedResult
---@param opts table Render config from setup()
---@return string[] lines
---@return table[] highlights Array of {line, col_start, col_end, group}
function M.render(result, opts)
  opts = merge_opts(opts)
  local lines = {}
  local highlights = {}
  local props = result.properties or {}

  if #props == 0 then return lines, highlights end

  local b = M.borders[opts.border_style] or M.borders.rounded
  local widths = calc_col_widths(result, opts)

  local function add_line(line)
    lines[#lines + 1] = line
  end

  local function add_hl(line_idx, col_start, col_end, group)
    highlights[#highlights + 1] = {
      line = line_idx,
      col_start = col_start,
      col_end = col_end,
      group = group,
    }
  end

  local function add_full_line_hl(line_idx, group)
    add_hl(line_idx, 0, #lines[line_idx + 1], group)
  end

  -- 1. Top border
  add_line(render_border(widths, b, b.tl, b.t, b.tr))
  add_full_line_hl(#lines - 1, "BasesTableBorder")

  -- 2. Header row
  local header_cells = {}
  for i, prop in ipairs(props) do
    local label = header_label(prop, result.propertyLabels)
    header_cells[i] = pad(label, widths[i], "left")
  end
  local header_line = render_row(header_cells, b)
  add_line(header_line)
  local hdr_line_idx = #lines - 1

  -- Header highlights: borders + each header cell
  local byte_pos = 0
  for i, prop in ipairs(props) do
    local sep_len = #b.v
    add_hl(hdr_line_idx, byte_pos, byte_pos + sep_len, "BasesTableBorder")
    byte_pos = byte_pos + sep_len
    local cell_start = byte_pos + 1
    local label = header_label(prop, result.propertyLabels)
    local cell_text = pad(label, widths[i], "left")
    local cell_end = cell_start + #cell_text
    add_hl(hdr_line_idx, cell_start, cell_end, "BasesTableHeader")
    byte_pos = cell_end + 1
  end
  local sep_len = #b.v
  add_hl(hdr_line_idx, byte_pos, byte_pos + sep_len, "BasesTableBorder")

  -- 3. Header separator
  add_line(render_border(widths, b, b.l, b.x, b.r))
  add_full_line_hl(#lines - 1, "BasesTableBorder")

  -- 4. Data rows
  local entries = result.entries or {}
  for row_idx, entry in ipairs(entries) do
    local cells = {}
    local cell_svs = {}
    for i, prop in ipairs(props) do
      local sv = entry.values and entry.values[prop] or { type = "null" }
      cell_svs[i] = sv
      cells[i] = format_cell(sv, widths[i], opts)
    end
    local row_line = render_row(cells, b)
    add_line(row_line)
    local line_idx = #lines - 1

    local row_group = "BasesTableRow"
    if opts.alternating_rows and row_idx % 2 == 0 then
      row_group = "BasesTableRowAlt"
    end
    add_full_line_hl(line_idx, row_group)

    -- Per-cell highlights
    byte_pos = 0
    for i = 1, #props do
      local sv = cell_svs[i]
      sep_len = #b.v
      add_hl(line_idx, byte_pos, byte_pos + sep_len, "BasesTableBorder")
      byte_pos = byte_pos + sep_len
      local cell_start = byte_pos + 1
      local cell_text = cells[i]
      local cell_end = cell_start + #cell_text
      local group = hl_group_for(sv)
      if group ~= "BasesTableRow" then
        add_hl(line_idx, cell_start, cell_end, group)
      end
      byte_pos = cell_end + 1
    end
    sep_len = #b.v
    add_hl(line_idx, byte_pos, byte_pos + sep_len, "BasesTableBorder")
  end

  -- 5. Summary section
  if result.summaries then
    local has_summary = false
    for _ in pairs(result.summaries) do has_summary = true; break end

    if has_summary then
      add_line(render_border(widths, b, b.sl, b.sx, b.sr, b.sh))
      add_full_line_hl(#lines - 1, "BasesTableSummaryBorder")

      local summary_cells = {}
      local summary_svs = {}
      for i, prop in ipairs(props) do
        local summary = result.summaries[prop]
        if summary then
          local label_text = summary.label .. ": "
          local val_text = M.render_serialized_value(summary.value, opts)
          local combined = label_text .. val_text
          local cw = strwidth(combined)
          if cw > widths[i] then
            local truncated = ""
            for j = 1, #combined do
              local candidate = combined:sub(1, j)
              if strwidth(candidate) > widths[i] - 1 then break end
              truncated = candidate
            end
            combined = truncated .. "…"
          end
          summary_cells[i] = pad(combined, widths[i], "left")
          summary_svs[i] = summary.value
        else
          summary_cells[i] = pad("", widths[i], "left")
          summary_svs[i] = { type = "null" }
        end
      end

      local summary_line = render_row(summary_cells, b)
      add_line(summary_line)
      local line_idx = #lines - 1
      add_full_line_hl(line_idx, "BasesTableSummary")

      byte_pos = 0
      for i = 1, #props do
        sep_len = #b.v
        add_hl(line_idx, byte_pos, byte_pos + sep_len, "BasesTableBorder")
        byte_pos = byte_pos + sep_len + 1
        local cell_text = summary_cells[i]
        byte_pos = byte_pos + #cell_text + 1
      end
      sep_len = #b.v
      add_hl(line_idx, byte_pos, byte_pos + sep_len, "BasesTableBorder")
    end
  end

  -- 6. Bottom border
  add_line(render_border(widths, b, b.bl, b.b, b.br))
  add_full_line_hl(#lines - 1, "BasesTableBorder")

  return lines, highlights
end

---Setup highlight groups (called once during plugin setup)
function M.setup_highlights()
  local links = {
    BasesTableBorder = "FloatBorder",
    BasesTableHeader = "@markup.heading",
    BasesTableRow = "Normal",
    BasesTableRowAlt = "CursorLine",
    BasesTableNull = "Comment",
    BasesTableBoolean = "@boolean",
    BasesTableNumber = "@number",
    BasesTableLink = "@markup.link",
    BasesTableGroupHeader = "@markup.heading",
    BasesTableSummary = "@markup.italic",
    BasesTableSummaryBorder = "FloatBorder",
  }
  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end
end

return M
