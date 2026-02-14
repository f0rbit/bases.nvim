# bases.nvim

Render [Obsidian Bases](https://obsidian.md/blog/introducing-bases/) as formatted Unicode tables in Neovim.

```
╭────────────┬──────────┬──────────╮
│ Name       │ Status   │ Priority │
├────────────┼──────────┼──────────┤
│ Project A  │ Active   │     1    │
│ Project B  │ Complete │     3    │
│ Project C  │ Pending  │     2    │
╞════════════╪══════════╪══════════╡
│            │          │ Sum: 6   │
╰────────────┴──────────┴──────────╯
```

Obsidian Bases are a powerful way to query and aggregate your vault — but they're invisible outside the Obsidian app. **bases.nvim** renders `.base` files and inline ````base```` blocks as formatted tables directly in Neovim. Zero external dependencies.

## Features

- Render `.base` files as Unicode tables with rounded or sharp borders
- Inline rendering of ````base```` code blocks in markdown files
- Full expression language support (formulas, filters, sorting)
- Summaries (count, sum, average, min, max, etc.)
- Obsidian date format patterns (`ddd`, `YYYY-MM`, etc.)
- File watching for automatic refresh on vault changes
- Health check via `:checkhealth bases`

## Installation

```lua
-- lazy.nvim
{
    "f0rbit/bases.nvim",
    ft = { "base", "markdown" },
    config = function()
        require("bases").setup({
            vault_path = "~/Documents/Vaults/MyVault",
        })
    end,
}
```

## Configuration

```lua
require("bases").setup({
    -- Path to Obsidian vault root (required)
    vault_path = nil,

    -- Rendering options
    render = {
        max_col_width = 40,
        min_col_width = 5,
        max_table_width = nil,    -- nil = terminal width
        alternating_rows = true,
        border_style = "rounded", -- "rounded" or "sharp"
        null_char = "—",
        bool_true = "✓",
        bool_false = " ",
        list_separator = ", ",
    },

    -- Inline rendering (```base``` blocks in markdown)
    inline = {
        enabled = true,
        auto_render = true,
    },

    -- File watcher
    watcher = {
        enabled = true,
        debounce_ms = 500,
    },

    -- Note index
    index = {
        extensions = { "md" },
        ignore_dirs = { ".obsidian", ".git", ".trash", "node_modules" },
    },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:BasesRender` | Render current `.base` file or inline blocks |
| `:BasesRefresh` | Re-index vault and re-render |
| `:BasesClear` | Clear rendered inline blocks |
| `:BasesToggle` | Toggle inline rendering on/off |
| `:BasesDebug` | Show parsed config for current file |

## Keymaps (in .base buffers)

| Key | Action |
|-----|--------|
| `r` | Re-render |
| `q` | Close buffer |

## Requirements

- Neovim >= 0.10

## Limitations (v1)

- Read-only display (no cell editing)
- No dashboard/multi-base views
- Inline rendering uses single highlight group (per-cell highlights planned for v2)
- Synchronous index build (may briefly block on large vaults)

## Credits

Engine forked from [miller3616/bases.nvim](https://github.com/miller3616/bases.nvim) (GPL-3.0).

## License

[GPL-3.0](./LICENSE)
