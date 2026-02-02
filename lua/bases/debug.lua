local M = {}

---Format a filter tree recursively with indentation
---@param node FilterNode
---@param indent number
---@return string[]
local function format_filter_tree(node, indent)
  local lines = {}
  local prefix = string.rep(" ", indent)

  if node.type == "expression" then
    table.insert(lines, prefix .. node.expression)
  elseif node.type == "and" or node.type == "or" or node.type == "not" then
    table.insert(lines, prefix .. string.upper(node.type))
    if node.children then
      for _, child in ipairs(node.children) do
        local child_lines = format_filter_tree(child, indent + 2)
        for _, line in ipairs(child_lines) do
          table.insert(lines, line)
        end
      end
    end
  end

  return lines
end

---Format a table with counts, sorted by count descending
---@param items table<string, table<string, boolean>>
---@param max_count number
---@return string[]
local function format_counted_table(items, max_count)
  local lines = {}

  -- Convert to array with counts
  local entries = {}
  for key, set in pairs(items) do
    local count = 0
    for _ in pairs(set) do
      count = count + 1
    end
    table.insert(entries, { key = key, count = count })
  end

  -- Sort by count descending
  table.sort(entries, function(a, b)
    if a.count == b.count then
      return a.key < b.key
    end
    return a.count > b.count
  end)

  -- Format entries
  local shown = 0
  for _, entry in ipairs(entries) do
    if shown >= max_count then
      table.insert(lines, string.format("  ... and %d more", #entries - shown))
      break
    end
    table.insert(lines, string.format("  %-20s (%d files)", entry.key, entry.count))
    shown = shown + 1
  end

  return lines
end

---Format a list of paths
---@param paths string[]
---@param max_count number
---@return string[]
local function format_paths(paths, max_count)
  local lines = {}
  local sorted = vim.deepcopy(paths)
  table.sort(sorted)

  local shown = 0
  for _, path in ipairs(sorted) do
    if shown >= max_count then
      table.insert(lines, string.format("  ... and %d more", #sorted - shown))
      break
    end
    table.insert(lines, "  " .. path)
    shown = shown + 1
  end

  return lines
end

---Gather and format debug information
---@param buf number
---@return string[]
local function gather_debug_info(buf)
  local lines = {}
  local engine = require('bases.engine')
  local base_parser = require('bases.engine.base_parser')

  -- 1. Engine Status
  table.insert(lines, "== Engine Status ==")
  local is_ready = engine.is_ready()
  table.insert(lines, string.format("Ready:      %s", tostring(is_ready)))

  local vault_path = engine.get_vault_path()
  if vault_path then
    table.insert(lines, string.format("Vault path: %s", vault_path))
  else
    table.insert(lines, "Vault path: (not set)")
  end
  table.insert(lines, "")

  -- 2. Note Index
  table.insert(lines, "== Note Index ==")
  local index = engine.get_index()

  if index then
    -- Total notes
    local total = 0
    for _ in pairs(index.notes) do
      total = total + 1
    end
    table.insert(lines, string.format("Total notes: %d", total))
    table.insert(lines, "")

    -- Folders
    local folder_count = 0
    for _ in pairs(index.by_folder) do
      folder_count = folder_count + 1
    end
    table.insert(lines, string.format("Folders (%d):", folder_count))
    if folder_count > 0 then
      local folder_lines = format_counted_table(index.by_folder, 20)
      for _, line in ipairs(folder_lines) do
        table.insert(lines, line)
      end
    end
    table.insert(lines, "")

    -- Tags
    local tag_count = 0
    for _ in pairs(index.by_tag) do
      tag_count = tag_count + 1
    end
    table.insert(lines, string.format("Tags (%d):", tag_count))
    if tag_count > 0 then
      local tag_lines = format_counted_table(index.by_tag, 20)
      for _, line in ipairs(tag_lines) do
        table.insert(lines, line)
      end
    end
    table.insert(lines, "")

    -- Sample paths
    table.insert(lines, "Sample paths (first 20):")
    local paths = {}
    for path in pairs(index.notes) do
      table.insert(paths, path)
    end
    if #paths > 0 then
      local path_lines = format_paths(paths, 20)
      for _, line in ipairs(path_lines) do
        table.insert(lines, line)
      end
    end
  else
    table.insert(lines, "(no index)")
  end
  table.insert(lines, "")

  -- 3. Current Base
  table.insert(lines, "== Current Base ==")
  local bases_path = vim.b[buf].bases_path

  if bases_path then
    table.insert(lines, string.format("Buffer path: %s", bases_path))

    -- Resolve path
    local resolved_path = bases_path
    if vault_path and not vim.startswith(bases_path, "/") then
      resolved_path = vault_path .. "/" .. bases_path
    end
    table.insert(lines, string.format("Resolved:    %s", resolved_path))

    -- Check readability
    local readable = vim.fn.filereadable(resolved_path) == 1
    table.insert(lines, string.format("Readable:    %s", tostring(readable)))

    table.insert(lines, "")

    -- 4. Parsed Query Config
    table.insert(lines, "== Parsed Query Config ==")
    if readable then
      local ok, query_config, parse_err = pcall(base_parser.parse, resolved_path)

      if ok and query_config then
        -- Filters
        table.insert(lines, "Filters:")
        if query_config.filters then
          local filter_lines = format_filter_tree(query_config.filters, 2)
          for _, line in ipairs(filter_lines) do
            table.insert(lines, line)
          end
        else
          table.insert(lines, "  (none)")
        end
        table.insert(lines, "")

        -- Formulas
        table.insert(lines, "Formulas:")
        if query_config.formulas then
          local formula_count = 0
          for name, expr in pairs(query_config.formulas) do
            table.insert(lines, string.format("  %s: %s", name, expr))
            formula_count = formula_count + 1
          end
          if formula_count == 0 then
            table.insert(lines, "  (none)")
          end
        else
          table.insert(lines, "  (none)")
        end
        table.insert(lines, "")

        -- Properties
        table.insert(lines, "Properties:")
        if query_config.properties then
          local prop_count = 0
          for name, prop_config in pairs(query_config.properties) do
            if prop_config.display_name then
              table.insert(lines, string.format("  %s:", name))
              table.insert(lines, string.format("    display_name: %s", prop_config.display_name))
              prop_count = prop_count + 1
            end
          end
          if prop_count == 0 then
            table.insert(lines, "  (none)")
          end
        else
          table.insert(lines, "  (none)")
        end
        table.insert(lines, "")

        -- Views
        if query_config.views and #query_config.views > 0 then
          table.insert(lines, string.format("Views (%d):", #query_config.views))
          for i, view in ipairs(query_config.views) do
            table.insert(lines, string.format("  [%d] \"%s\" (%s)", i, view.name, view.type))

            if view.order then
              table.insert(lines, string.format("      order: %s", table.concat(view.order, ", ")))
            end

            if view.limit then
              table.insert(lines, string.format("      limit: %d", view.limit))
            end

            if view.filters then
              table.insert(lines, "      filters:")
              local filter_lines = format_filter_tree(view.filters, 8)
              for _, line in ipairs(filter_lines) do
                table.insert(lines, line)
              end
            end

            if view.sort then
              local sort_parts = {}
              for _, s in ipairs(view.sort) do
                table.insert(sort_parts, string.format("%s %s", s.column, s.direction))
              end
              table.insert(lines, string.format("      sort: %s", table.concat(sort_parts, ", ")))
            end

            if view.group_by then
              table.insert(lines, string.format("      group_by: %s", view.group_by))
            end
          end
        else
          table.insert(lines, "Views: (none)")
        end
      elseif ok then
        -- parse returned nil + error string
        table.insert(lines, string.format("(parse error: %s)", tostring(parse_err or "unknown")))
      else
        -- pcall caught a thrown error; query_config holds the error message
        table.insert(lines, string.format("(parse error: %s)", tostring(query_config)))
      end
    else
      table.insert(lines, "(file not readable)")
    end
  else
    table.insert(lines, "(not set)")
  end
  table.insert(lines, "")

  -- 5. Query Results
  table.insert(lines, "== Query Results ==")
  local bases_data = vim.b[buf].bases_data

  if bases_data and bases_data.entries then
    table.insert(lines, string.format("Matched files: %d", #bases_data.entries))
    table.insert(lines, "")

    if #bases_data.entries > 0 then
      table.insert(lines, "All matched paths:")
      local paths = {}
      for _, entry in ipairs(bases_data.entries) do
        if entry.file and entry.file.path then
          table.insert(paths, entry.file.path)
        end
      end

      if #paths > 0 then
        local path_lines = format_paths(paths, 20)
        for _, line in ipairs(path_lines) do
          table.insert(lines, line)
        end
      end
    end
  else
    table.insert(lines, "(no data)")
  end

  return lines
end

---Show debug information in a floating window
---@param buf number
function M.show(buf)
  local lines = gather_debug_info(buf)

  -- Calculate window dimensions
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.8)
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  -- Create scratch buffer
  local debug_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[debug_buf].buftype = 'nofile'
  vim.bo[debug_buf].bufhidden = 'wipe'
  vim.bo[debug_buf].swapfile = false

  -- Set lines
  vim.api.nvim_buf_set_lines(debug_buf, 0, -1, false, lines)
  vim.bo[debug_buf].modifiable = false

  -- Open floating window
  local win = vim.api.nvim_open_win(debug_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = 'rounded',
    title = ' Base Debug Info ',
    title_pos = 'center',
    footer = ' q/Esc to close ',
    footer_pos = 'center',
    style = 'minimal',
  })

  -- Set window options
  vim.wo[win].number = false
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false

  -- Set keymaps to close window
  local opts = { noremap = true, silent = true, nowait = true, buffer = debug_buf }
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, opts)
end

return M
