# Contributing

This guide is for developers who want to contribute to bases.nvim.

## Development Setup

1. Clone the repository
2. Configure lazy.nvim dev mode to load from your local clone:

```lua
{
    'miller3616/bases.nvim',
    dev = true,
    dir = '/absolute/path/to/your/clone/bases.nvim',
}
```

3. Ensure you have a vault with `.md` and `.base` files for testing

## Project Structure

```
bases.nvim/
├── plugin/bases.lua           # Autocmds, commands, VimLeavePre handler
├── lua/bases/
│   ├── init.lua               # Plugin entry, setup(), public API
│   ├── buffer.lua             # Buffer creation, loading/error states
│   ├── display.lua            # Data transformation (sort, limit)
│   ├── render.lua             # Table rendering, cell tracking
│   ├── navigation.lua         # Link detection, cursor movement
│   ├── edit.lua               # Cell editing UI (floating window)
│   ├── source_edit.lua        # Source file editing
│   ├── views.lua              # View selection picker
│   ├── debug.lua              # Debug info display
│   ├── engine/
│   │   ├── init.lua           # Engine public API
│   │   ├── yaml.lua           # Custom YAML parser
│   │   ├── note_index.lua     # Vault file index with secondary indices
│   │   ├── base_parser.lua    # .base file parser
│   │   ├── query_engine.lua   # Query execution
│   │   ├── summaries.lua      # Column aggregation summaries
│   │   ├── file_watcher.lua   # Filesystem watcher (300ms debounce)
│   │   ├── frontmatter_editor.lua  # YAML frontmatter editing
│   │   └── expr/
│   │       ├── lexer.lua      # Expression tokenizer
│   │       ├── parser.lua     # Recursive descent parser
│   │       ├── evaluator.lua  # AST evaluator
│   │       ├── types.lua      # Runtime type system
│   │       ├── functions.lua  # Global functions
│   │       └── methods.lua    # Type method dispatch
│   ├── inline/
│   │   ├── init.lua           # Inline rendering setup
│   │   ├── detect.lua         # Embed detection
│   │   ├── render.lua         # Virtual line rendering
│   │   ├── navigation.lua     # Inline link navigation
│   │   └── source_edit.lua    # Code block source editing
│   └── dashboard/
│       ├── init.lua           # Dashboard open/refresh
│       ├── render.lua         # Dashboard composition
│       └── navigation.lua     # Section navigation
```

## Architecture Overview

See [Architecture](architecture.md) for full system design.

The codebase splits into two layers:

- **Engine** (`engine/`): Pure data processing. YAML parsing, indexing, querying, expression evaluation.
- **UI** (everything else): Neovim integration. Buffers, rendering, keymaps, floating windows.

## Key Design Decisions

- **No external dependencies**: Custom YAML parser and expression engine to avoid luarocks.
- **Buffer-local state**: All navigation/editing state stored in `vim.b[buf]`, not module-level tables.
- **Callback-based async**: Engine uses callbacks with `vim.schedule` for non-blocking I/O.
- **Unified display layer**: All contexts (standalone, dashboard, inline) go through `display.lua`.
- **Deferred initialization**: Engine starts indexing only when first needed, not on plugin load.
- **msgpack cache**: NoteIndex persists to disk using msgpack for fast restarts.

## Code Conventions

### LuaCATS Type Annotations

All public functions use LuaCATS annotations:

```lua
---Brief description
---@param name type Description
---@return type Description
function M.example(name) end
```

### Buffer-local State

Plugin state is stored in buffer variables:

- Standalone bases: `bases_path`, `bases_view_index`, `bases_links`, `bases_cells`, `bases_headers`
- Dashboards: `bases_dashboard_name`, `bases_dashboard_sections`
- Inline: `bases_inline_embeds`

### Async Patterns

Engine operations are async with callback-based APIs:

```lua
engine.query(path, view_index, function(err, result)
    if err then
        -- handle error in vim.schedule context
    end
    -- process result
end)
```

### Lazy Loading

Modules are loaded on demand:

- `setup()` stores config but does not start indexing
- `engine.on_ready()` triggers lazy initialization
- Heavy modules (`base_parser`, `query_engine`) load on first use

## Testing

See [Testing](testing.md) for the full test guide, including how to run tests, write new tests, and CI setup.

```bash
make deps       # one-time: clone mini.nvim
make test       # run all tests
make test-unit  # unit tests only
make test-integration  # integration tests only
```

### Manual QA Checklist

In addition to the automated test suite, verify these scenarios manually:

- Open a `.base` file with various property types (string, number, date, link, list)
- Test inline embeds in markdown files with `![[name.base]]` syntax
- Test dashboards with multiple sections
- Edit cells with `c` and verify frontmatter updates in source files
- Test sorting on different column types (click headers)
- Test link navigation with `<Tab>`, `<S-Tab>`, `<CR>`
- Test view switching with `v`

## Adding a Feature

1. Read the [Architecture](architecture.md) and identify which layer your feature touches
2. For engine changes: modify the relevant `engine/` module
3. For UI changes: modify the rendering/navigation modules
4. Update keymaps in `init.lua` if adding new interactions
5. Update documentation in `docs/`

## Common Tasks

### Adding a new global function

Edit `lua/bases/engine/expr/functions.lua` and add your function to the `functions` table.

### Adding a new type method

Edit `lua/bases/engine/expr/methods.lua` and add your method to the appropriate type's method table.

### Modifying the table renderer

Edit `lua/bases/render.lua`. The renderer tracks cell positions for navigation and editing.

### Changing how data is sorted

Edit `lua/bases/display.lua`. This module handles sorting and limiting before rendering.

## File Locations

All paths in this project should be absolute when interacting with Neovim APIs or the engine. Relative paths are only used within the vault context.

Key paths:

- **Vault path**: Set via `setup({ vault_path = ... })` or auto-detected from obsidian.nvim if installed
- **Base files**: Resolved relative to vault path (e.g., `vault_path/projects/tasks.base`)
- **Note files**: Always stored as vault-relative paths in NoteIndex (e.g., `people/john.md`)

## Debugging

Use the `?` keymap in any bases buffer to show debug info including:

- Base path and current view
- Query result structure
- Link positions
- Cell tracking data
