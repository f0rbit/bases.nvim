# User Guide

This guide covers all features and usage patterns for bases.nvim, a Neovim plugin that renders Obsidian Bases as unicode tables with navigation, sorting, and editing capabilities.

## Opening a Base

### Using :edit

The simplest way to open a base is with Neovim's `:edit` command:

```vim
:edit /path/to/vault/projects.base
```

The plugin automatically intercepts `BufReadCmd` events for `.base` files and renders them as formatted tables instead of raw YAML.

### Programmatically

You can also open bases programmatically from Lua:

```lua
require('bases').open('projects.base')
```

This method accepts either absolute paths or relative paths (relative to your vault root).

### Auto-discovery with Telescope

If you have Telescope.nvim installed, you can browse and open base files interactively:

```lua
-- Add to your Telescope configuration
require('telescope.builtin').find_files({
    prompt_title = 'Find Bases',
    cwd = vim.fn.expand('~/vault'),
    find_command = { 'rg', '--files', '--glob', '*.base' },
})
```

Map this to a convenient keymap for quick access to your bases.

## Table Display

### Column Headers

Base property names are automatically transformed into readable column headers. The transformation strips the property prefix (`file.`, `note.`, `formula.`) and capitalizes the first letter:

| API Property    | Display Header |
|-----------------|----------------|
| `file.name`     | Name           |
| `note.status`   | Status         |
| `note.priority` | Priority       |
| `formula.total` | Total          |

Custom column labels defined in the base YAML are respected and displayed as-is.

### Value Rendering

Different data types are rendered appropriately for display:

| Type    | Rendering Example                    |
|---------|--------------------------------------|
| String  | As-is                                |
| Number  | As-is (123, 45.67)                   |
| Boolean | "Yes" or "No"                        |
| Link    | Text without brackets (Project A)    |
| Date    | Formatted per `date_format` config   |
| Null    | Empty cell                           |
| List    | Comma-separated items                |

### Date Formatting

Dates can be displayed in two modes:

#### Absolute Format (default)

Configure the display format using standard `strftime` format strings:

```lua
require('bases').setup({
    date_format = '%Y-%m-%d',  -- Default: ISO 8601
})
```

Common format strings:

| Format String    | Example Output       |
|------------------|----------------------|
| `%Y-%m-%d`       | 2026-01-31           |
| `%m/%d/%Y`       | 01/31/2026           |
| `%B %d, %Y`      | January 31, 2026     |
| `%b %d`          | Jan 31               |
| `%Y-%m-%d %H:%M` | 2026-01-31 14:30     |

#### Relative Format

Enable relative date display for human-friendly output:

```lua
require('bases').setup({
    date_format_relative = true,
})
```

Relative date examples:

| Actual Date           | Display         |
|-----------------------|-----------------|
| 2 minutes ago         | 2 minutes ago   |
| 3 hours ago           | 3 hours ago     |
| Yesterday             | 1 day ago       |
| Last week             | 7 days ago      |
| Two weeks from now    | in 14 days      |
| Next month            | in 1 month      |

Note: Date columns always sort chronologically by their underlying timestamp value, regardless of display format.

### Table Borders

Unicode box-drawing characters create clean table borders with rounded corners:

```
╭───────────┬──────────┬──────────╮
│ Name      │ Status   │ Priority │
├───────────┼──────────┼──────────┤
│ Project A │ Active   │ High     │
│ Project B │ Complete │ Low      │
╰───────────┴──────────┴──────────╯
```

## Column Sorting

### Sort Cycle

Click or press `<CR>` on a column header to cycle through sort states:

1. Unsorted (default view order)
2. Ascending (▲ indicator)
3. Descending (▼ indicator)
4. Back to unsorted

The currently sorted column is highlighted with the `BasesSortedHeader` highlight group.

### Sorting Behavior

Each data type has specific sort behavior:

#### Null Values
Null or empty values always sort to the end, regardless of sort direction.

#### Date Columns
Sort chronologically by underlying timestamp value (milliseconds since epoch), independent of display format.

#### String Columns
Sort case-insensitive alphabetically:
- "apple", "Banana", "cherry"
- In ascending order: apple, Banana, cherry

#### Number Columns
Sort numerically:
- -10, 0, 5, 100

#### Boolean Columns
Sort with false before true in ascending order.

#### Mixed-Type Columns
When a column contains multiple types, values sort by type first (numbers, then strings, then booleans), then by value within each type.

### Client-Side vs Server-Side Sorting

- Client-side sorting (clicking headers): Temporary, resets when changing views
- Server-side sorting (defined in base YAML): Persists across sessions

Switching views clears any client-side sort and returns to the view's default order.

## Property Editing

### Editable vs Read-Only

Not all properties can be edited. Editability depends on the property type:

| Property Type | Editable | Reason                          |
|---------------|----------|---------------------------------|
| `note.*`      | Yes      | Frontmatter properties          |
| `file.*`      | No       | Filesystem metadata (read-only) |
| `formula.*`   | No       | Computed values (read-only)     |

### Cell Editing

To edit a cell value:

1. Position your cursor on an editable (`note.*`) cell
2. Press `c` (default keymap for `edit_cell`)
3. A floating window opens with the current value
4. Edit the value in insert mode
5. Press `<CR>` to save or `<Esc>`/`q` to cancel

### Edit Behavior

#### Saving Changes
When you save (press `<CR>`):
- The value is written directly to the note's frontmatter
- The file is re-indexed
- The base table automatically refreshes to show the new value

#### Canceling
Press `<Esc>` or `q` to close the editor without saving changes.

#### Deleting Properties
To delete a property entirely, clear the value (make it empty) and save.

#### Read-Only Properties
Attempting to edit a `file.*` or `formula.*` property displays a warning: "`file` properties are read-only" or "`formula` properties are read-only".

### Source Editing

Press `E` (default keymap for `edit_source`) to edit the raw `.base` file YAML in a floating window:

1. The complete base definition appears in a floating editor
2. Edit the YAML (views, filters, properties, etc.)
3. Press `<CR>` or `:w` to save
4. Press `<Esc>` or `q` to cancel

Changes to the source file take effect immediately upon saving, and the base re-renders.

## View Selection

Many bases define multiple views (filtered or sorted variations). To switch between views:

1. Press `v` (default keymap for `select_view`)
2. A floating picker appears showing available views
3. Use `j`/`k` to navigate
4. Press `<CR>` to select

Example picker:

```
╭────────────────────╮
│   Select View      │
├────────────────────┤
│ ● All Projects     │  <- Current view marked with ●
│   Active Only      │
│   By Priority      │
╰────────────────────╯
```

If the base has only one view, you'll see: "No alternate views available".

### View Switching Behavior

When you switch views:
- Any client-side column sorting is cleared
- The new view's default sort order applies
- The view selection persists for that buffer session

## Inline Embeds

Bases can be embedded directly into markdown files, rendering as tables within your notes.

### Embed Syntax

Use standard Obsidian embed syntax:

```markdown
## My Projects

![[projects.base]]

The table above shows all active projects.
```

You can also use code block embeds with inline query definitions:

````markdown
## High Priority Tasks

```base
filters: file.hasTag("task") AND note.priority = "High"
views:
  - type: table
    order: [file.name, note.due_date]
```
````

### How It Works

1. On `BufEnter` for markdown files, the plugin scans for:
   - `![[*.base]]` embed patterns
   - ````base` code block patterns
2. Each embed is queried against the vault index
3. Tables are rendered as virtual lines using Neovim extmarks
4. The original markdown text remains unchanged
5. Virtual lines appear immediately below each embed

### The `this` Context

Code block embeds support special `this.*` references that resolve to properties of the containing markdown file:

````markdown
---
project: ProjectA
---

## Tasks for This Project

```base
filters: note.project = this.project
views:
  - type: table
    order: [file.name, note.status]
```
````

In this example, `this.project` resolves to "ProjectA" from the file's frontmatter.

### Configuration

```lua
require('bases').setup({
    inline = {
        enabled = true,         -- Enable inline rendering
        auto_render = true,     -- Auto-render on BufEnter
        keymaps = {
            follow_link = '<CR>',
            next_link = '<Tab>',
            prev_link = '<S-Tab>',
            edit_cell = 'c',
            edit_source = 'E',
            refresh = '<leader>br',
        },
    },
})
```

Set `enabled = false` to completely disable inline rendering. Set `auto_render = false` to render only on explicit command.

### Inline Keymaps

All keymaps work when the cursor is on or within an inline embed:

| Key          | Action                                    |
|--------------|-------------------------------------------|
| `<CR>`       | Follow selected link                      |
| `<Tab>`      | Select next link                          |
| `<S-Tab>`    | Select previous link                      |
| `c`          | Edit cell under cursor                    |
| `E`          | Edit source (for code block embeds)       |
| `<leader>br` | Refresh all inline bases in current file  |

Keymaps fall through to default behavior when the cursor is not on an embed.

### Link Navigation in Embeds

Since virtual lines cannot be directly navigated like normal buffer lines:

1. Position your cursor on the `![[base.base]]` line or within the code block
2. Press `<Tab>` to select the first link in the table
3. A notification appears: "Link 1/5: Project A"
4. Continue pressing `<Tab>` to cycle through links
5. Press `<CR>` to follow the selected link

Use `<S-Tab>` to navigate backwards through links.

### Source Editing for Code Blocks

Press `E` on a code block embed to edit the YAML definition inline:

1. A floating window opens with the current query
2. Edit filters, views, properties, etc.
3. Press `<CR>` to save and re-render
4. Press `<Esc>` or `q` to cancel

Changes are saved to the markdown file and take effect immediately.

### Limitations

- Column sorting is not available for inline embeds
- For full interactive features, open the `.base` file directly with `:edit`

## Dashboards

Dashboards combine multiple bases into a single overview screen, useful for daily reviews, project overviews, or aggregated status views.

### Configuration

Define dashboards in your `setup()` call:

```lua
require('bases').setup({
    dashboards = {
        daily = {
            title = 'Daily Overview',
            sections = {
                { base = 'tasks', title = "Today's Tasks", max_rows = 5 },
                { base = 'meetings', title = 'Upcoming Meetings', max_rows = 3 },
                { base = 'notes', title = 'Recent Notes' },
            },
            spacing = 1,
        },
        projects = {
            title = 'Projects Dashboard',
            sections = {
                { base = 'active-projects', title = 'Active' },
                { base = 'blocked-projects', title = 'Blocked' },
                { base = 'completed-projects', title = 'Completed This Week' },
            },
            spacing = 2,
        },
    },
})
```

#### Section Options

| Option     | Type   | Required | Description                           |
|------------|--------|----------|---------------------------------------|
| `base`     | string | Yes      | Base name (without `.base` extension) |
| `title`    | string | No       | Section title (defaults to base name) |
| `max_rows` | number | No       | Limit number of data rows displayed   |

#### Dashboard Options

| Option    | Type           | Default | Description                      |
|-----------|----------------|---------|----------------------------------|
| `title`   | string         | nil     | Main dashboard title             |
| `sections`| table          | (none)  | Array of section configurations  |
| `spacing` | number         | 1       | Blank lines between sections     |

### Commands

Open a dashboard by name:

```vim
:BasesDashboard daily
```

List available dashboards:

```vim
:BasesDashboard
```

Output example:

```
Available dashboards:
  daily
  projects
```

### Dashboard Display

A typical dashboard looks like this:

```
═══════════════════════════════════════════════════════════════
                         Daily Overview
═══════════════════════════════════════════════════════════════

                        Today's Tasks
╭────────────────────┬──────────┬──────────╮
│ Name               │ Status   │ Priority │
├────────────────────┼──────────┼──────────┤
│ Write documentation│ Active   │ High     │
│ Review PRs         │ Pending  │ Medium   │
│ Update configs     │ Active   │ Low      │
╰────────────────────┴──────────┴──────────╯

                     Upcoming Meetings
╭─────────────┬────────────┬──────────╮
│ Name        │ Date       │ Attendees│
├─────────────┼────────────┼──────────┤
│ Standup     │ 2026-02-01 │ Team     │
│ 1-on-1      │ 2026-02-02 │ Manager  │
╰─────────────┴────────────┴──────────╯
```

The title (if configured) is underlined with double lines (`═`). Section titles are centered above their tables.

### Dashboard Keymaps

All standard base keymaps work within dashboard sections, plus navigation keymaps:

| Key  | Action                   |
|------|--------------------------|
| `]]` | Jump to next section     |
| `[[` | Jump to previous section |
| `c`  | Edit cell under cursor   |
| `<CR>`| Follow link or sort     |
| `<Tab>`| Next link              |
| `<S-Tab>`| Previous link         |
| `R`  | Refresh entire dashboard |

### Per-Section Sorting

Each section maintains its own independent sort state. Clicking a header in one section does not affect others.

### Refreshing Dashboards

Press `R` (default `refresh` keymap) to refresh all sections in the dashboard. Each section re-queries its base and updates its display.

## render-markdown.nvim Integration

For users of the [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) plugin, bases.nvim can render tables as markdown pipe tables instead of unicode tables.

### Configuration

```lua
require('bases').setup({
    render_markdown = true,
})
```

### Behavior Changes

When `render_markdown = true`:

1. Tables render as markdown pipe tables:
   ```
   | Name      | Status   | Priority |
   |-----------|----------|----------|
   | Project A | Active   | High     |
   | Project B | Complete | Low      |
   ```

2. Filetype is set to `markdown` instead of `obsidian_base`

3. Wiki-links remain in `[[...]]` format for render-markdown.nvim to process

4. render-markdown.nvim handles all syntax highlighting

5. All keymaps and navigation work identically

This mode is useful if you prefer consistent markdown styling across all buffers.

## Configuration Reference

Complete configuration with all available options:

```lua
require('bases').setup({
    -- Vault path (auto-detected from obsidian.nvim if nil)
    vault_path = nil,

    -- Use markdown pipe tables instead of unicode tables
    render_markdown = false,

    -- Date formatting
    date_format = '%Y-%m-%d',        -- strftime format string
    date_format_relative = false,    -- Use relative dates ("2 days ago")

    -- Keymaps for .base file buffers
    keymaps = {
        follow_link = '<CR>',       -- Follow link or toggle column sort
        next_link = '<Tab>',        -- Jump to next link
        prev_link = '<S-Tab>',      -- Jump to previous link
        refresh = 'R',              -- Refresh base data
        edit_cell = 'c',            -- Edit cell under cursor
        edit_source = 'E',          -- Edit .base source file
        select_view = 'v',          -- Open view selector
        debug = '?',                -- Show debug information
    },

    -- Inline embed configuration
    inline = {
        enabled = true,             -- Enable inline rendering
        auto_render = true,         -- Auto-render on BufEnter
        keymaps = {
            follow_link = '<CR>',   -- Follow selected link
            next_link = '<Tab>',    -- Select next link
            prev_link = '<S-Tab>',  -- Select previous link
            refresh = '<leader>br', -- Refresh all inline bases
            edit_cell = 'c',        -- Edit cell in inline table
            edit_source = 'E',      -- Edit code block source
        },
    },

    -- Dashboard definitions
    dashboards = {
        daily = {
            title = 'Daily Overview',
            sections = {
                { base = 'tasks', title = "Today's Tasks", max_rows = 5 },
                { base = 'meetings', title = 'Upcoming Meetings' },
            },
            spacing = 1,
        },
    },
})
```

### Disabling Keymaps

Set any keymap to `false` to disable it:

```lua
require('bases').setup({
    keymaps = {
        follow_link = '<CR>',
        next_link = '<Tab>',
        prev_link = '<S-Tab>',
        refresh = false,         -- Disable refresh keymap
        edit_cell = 'c',
        edit_source = false,     -- Disable source editing
        select_view = 'v',
        debug = false,
    },
})
```

### Customizing Keymaps

Change keymaps to match your workflow:

```lua
require('bases').setup({
    keymaps = {
        follow_link = 'gf',      -- Use gf instead of <CR>
        next_link = ']l',        -- Use ]l instead of <Tab>
        prev_link = '[l',        -- Use [l instead of <S-Tab>
        refresh = '<F5>',        -- Use F5 instead of R
        edit_cell = 'i',         -- Use i instead of c
        edit_source = 'gs',      -- Use gs instead of E
        select_view = '<leader>v', -- Use <leader>v instead of v
        debug = 'gd',
    },
    inline = {
        keymaps = {
            refresh = '<leader>r', -- Shorter refresh keymap
        },
    },
})
```

## Commands

bases.nvim provides the following user commands:

### :BasesDashboard

Open a named dashboard or list available dashboards.

```vim
:BasesDashboard daily         " Open the 'daily' dashboard
:BasesDashboard               " List all available dashboards
```

## API Functions

For scripting and advanced usage, bases.nvim exposes these Lua functions:

### Opening Bases

```lua
-- Open a base file
require('bases').open('projects.base')

-- Open with absolute path
require('bases').open('/home/user/vault/projects.base')
```

### Refreshing

```lua
-- Refresh current buffer
require('bases').refresh()

-- Refresh specific buffer
require('bases').refresh(bufnr)

-- Refresh silently (no notifications)
require('bases').refresh(bufnr, { silent = true })

-- Refresh all open bases, dashboards, and inline embeds
require('bases').refresh_all_buffers()
```

### Dashboards

```lua
-- Open a dashboard
require('bases').open_dashboard('daily')

-- List dashboard names
local names = require('bases').list_dashboards()
```

### Inline Bases

```lua
-- Render inline bases in current buffer
require('bases').render_inline()

-- Refresh inline bases in current buffer
require('bases').refresh_inline()
```

### Configuration

```lua
-- Get current configuration
local config = require('bases').get_config()
print(vim.inspect(config.date_format))
```

## Limitations

### Single Vault
bases.nvim currently supports a single vault at a time, configured via `vault_path` (or auto-detected from obsidian.nvim if installed).

### No Grouped Views
Bases with grouped views (group-by clauses) are not currently supported. Only table views render correctly.

### Simple Value Editing
The cell editor is a basic text input. There are no specialized UIs for:
- Link picker/autocomplete
- Multi-value list editing
- Date picker

To edit complex values, use `:edit` on the source note directly.

### No Inline Sorting
Column sorting is not available for inline embeds. To sort, open the `.base` file in a full buffer.

### List Display
When a cell contains a list value, only the first item is displayed in the table. To see all items, open the source note.
