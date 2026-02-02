# Neovim Quick Reference

## Base Buffer Keymaps

All keymaps are buffer-local, active only in base buffers. Configurable via setup().

| Key | Action | Config Key |
|-----|--------|------------|
| `<CR>` | Follow link under cursor / sort column header | `follow_link` |
| `<Tab>` | Jump to next link | `next_link` |
| `<S-Tab>` | Jump to previous link | `prev_link` |
| `R` | Refresh base data | `refresh` |
| `c` | Edit cell under cursor | `edit_cell` |
| `E` | Edit base source file | `edit_source` |
| `v` | Open view selection picker | `select_view` |
| `?` | Show debug info | `debug` |

## Dashboard Keymaps

All base keymaps above, plus:

| Key | Action |
|-----|--------|
| `]]` | Jump to next section |
| `[[` | Jump to previous section |

## Inline Embed Keymaps

Active on `![[*.base]]` or `` ```base `` lines. Fall through to defaults otherwise.

| Key | Action | Config Key |
|-----|--------|------------|
| `<CR>` | Follow selected link | `inline.keymaps.follow_link` |
| `<Tab>` | Next link in embed | `inline.keymaps.next_link` |
| `<S-Tab>` | Previous link | `inline.keymaps.prev_link` |
| `c` | Edit cell in embed | `inline.keymaps.edit_cell` |
| `E` | Edit source (code blocks) | `inline.keymaps.edit_source` |
| `<leader>br` | Refresh all inline bases | `inline.keymaps.refresh` |

## Floating Editor Keymaps

These apply in floating windows (cell edit, source edit, view picker, debug).

### Cell / Source Editor
| Key | Action |
|-----|--------|
| `<CR>` | Save and close |
| `:w` | Save and close (source editor) |
| `<Esc>` | Cancel / close |
| `q` | Cancel / close |

### View Picker
| Key | Action |
|-----|--------|
| `j` / `k` | Move selection |
| `<CR>` | Switch to selected view |
| `<Esc>` / `q` | Close without switching |

## Commands

| Command | Description |
|---------|-------------|
| `:BasesDashboard {name}` | Open a named dashboard |
| `:BasesDashboard` | List available dashboards |

## Autocmds

| Event | Pattern | Description |
|-------|---------|-------------|
| `BufReadCmd` | `*.base` | Opens .base files with bases.nvim |
| `VimLeavePre` | `*` | Saves cache and stops file watcher on exit |
| `BufWritePost` | `*` | Re-indexes saved vault files and refreshes all base buffers |
| `BufEnter` / `BufWinEnter` | `*.md`, `*.markdown` | Auto-renders inline base embeds (if enabled) |
| `BufWritePost` | `*.md`, `*.markdown` | Re-scans and re-renders inline embeds |

## Highlight Groups

All groups use `default = true`, so user overrides take precedence.

| Group | Default Link | Purpose |
|-------|-------------|---------|
| `BasesLink` | `Underlined` | Wiki-links in cells |
| `BasesHeader` | `Title` | Column headers |
| `BasesSortedHeader` | `Special` | Sorted column headers |
| `BasesBorder` | `Comment` | Table borders |
| `BasesEditable` | `String` | Editable cells |
| `BasesDashboardTitle` | `Title` | Dashboard main title |
| `BasesDashboardSectionTitle` | `Label` | Dashboard section headers |
| `BasesSummary` | `Comment` | Summary row values |

Example override:
```lua
vim.api.nvim_set_hl(0, 'BasesLink', { fg = '#7aa2f7', underline = true })
```

## Buffer Variables

### Base Buffers
| Variable | Type | Description |
|----------|------|-------------|
| `b:bases_path` | string | Path to the .base file |
| `b:bases_view_index` | number | Current view index (0-based) |
| `b:bases_links` | table | Link positions for navigation |
| `b:bases_cells` | table | Cell positions for editing |
| `b:bases_headers` | table | Header positions for sorting |

### Dashboard Buffers
| Variable | Type | Description |
|----------|------|-------------|
| `b:bases_dashboard_name` | string | Dashboard name |
| `b:bases_dashboard_config` | table | Dashboard configuration |
| `b:bases_dashboard_section_starts` | table | Line numbers of section headers |
| `b:bases_dashboard_section_data` | table | Per-section rendered data |
| `b:bases_dashboard_sort_states` | table | Per-section sort state |
| `b:bases_dashboard_use_markdown` | boolean | Whether markdown rendering is active |

### Inline Embed Buffers
| Variable | Type | Description |
|----------|------|-------------|
| `b:bases_inline_embeds` | table | Embed info (source, line range, links, cells) |

## Keymap Configuration

```lua
require('bases').setup({
    keymaps = {
        follow_link = '<CR>',   -- default
        next_link = '<Tab>',    -- default
        prev_link = '<S-Tab>',  -- default
        refresh = 'R',          -- default
        edit_cell = 'c',        -- default
        edit_source = 'E',      -- default
        select_view = 'v',      -- default
        debug = '?',            -- default
    },
    inline = {
        enabled = true,
        auto_render = true,
        keymaps = {
            follow_link = '<CR>',      -- default
            next_link = '<Tab>',       -- default
            prev_link = '<S-Tab>',     -- default
            refresh = '<leader>br',    -- default
            edit_cell = 'c',           -- default
            edit_source = 'E',         -- default
        },
    },
})
```

To disable a keymap, set it to `false`:
```lua
require('bases').setup({
    keymaps = {
        edit_cell = false,  -- disable cell editing keymap
    },
})
```

## Public API

### Opening and Refreshing

| Function | Description |
|----------|-------------|
| `require('bases').open(base_path, buf)` | Open a .base file |
| `require('bases').refresh(buf, opts)` | Refresh current base buffer |
| `require('bases').refresh_all_buffers(opts)` | Refresh all base-related buffers |

### Dashboards

| Function | Description |
|----------|-------------|
| `require('bases').open_dashboard(name)` | Open a named dashboard |
| `require('bases').refresh_dashboard(buf, opts)` | Refresh dashboard buffer |
| `require('bases').list_dashboards()` | Get list of dashboard names |

### Inline Rendering

| Function | Description |
|----------|-------------|
| `require('bases').render_inline(buf)` | Render inline bases in buffer |
| `require('bases').refresh_inline(buf, opts)` | Refresh inline bases |
| `require('bases').enable_inline()` | Enable inline rendering |
| `require('bases').get_embed_at_cursor(buf)` | Get embed info at cursor |

### Views

| Function | Description |
|----------|-------------|
| `require('bases.views').switch_view(buf, index)` | Switch to view by index |
| `require('bases.views').select_view(buf)` | Open view picker |

### Configuration

| Function | Description |
|----------|-------------|
| `require('bases').setup(opts)` | Configure plugin |
| `require('bases').get_config()` | Get current configuration |

## Engine API

| Function | Description |
|----------|-------------|
| `require('bases.engine').is_ready()` | Check if vault index is ready |
| `require('bases.engine').get_vault_path()` | Get configured vault path |
| `require('bases.engine').query(path, view, cb)` | Query a base file |
| `require('bases.engine').update_file(path, cb)` | Re-index a specific file |
| `require('bases.engine').shutdown()` | Save cache and stop watcher |
