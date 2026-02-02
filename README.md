# Obsidian Bases for Neovim

View, navigate, and edit [Obsidian Bases](https://obsidian.md/blog/introducing-bases/) directly from Neovim.

```
╭────────────┬──────────┬──────────╮
│ Name       │ Status   │ Priority │
├────────────┼──────────┼──────────┤
│ Project A  │ Active   │ High     │
│ Project B  │ Complete │ Low      │
│ Project C  │ Pending  │ Medium   │
╰────────────┴──────────┴──────────╯
```

## Features

- **Unicode Tables** — Bases render as formatted tables with rounded borders
- **Link Navigation** — Jump between wiki-links with `<Tab>`/`<S-Tab>`, follow with `<CR>`
- **Column Sorting** — Click headers to sort ascending/descending
- **Property Editing** — Edit frontmatter properties directly, changes sync to Obsidian
- **Dashboards** — Combine multiple bases into overview screens
- **Inline Embeds** — Render `![[base.base]]` embeds within markdown files

## Quick Start

```lua
-- lazy.nvim
{
    'obsidian-nvim/bases.nvim',
    config = function()
        require('bases').setup({
            vault_path = '/path/to/vault',
        })
    end,
}
```

Then open any `.base` file:

```vim
:edit path/to/mybase.base
```

## Requirements

- Neovim 0.11+

### Optional

- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) — auto-detects `vault_path` so you don't have to set it explicitly

## Documentation

See [`docs/`](docs/README.md) for complete documentation:

- [Getting Started](docs/users/getting-started.md) — Installation and setup
- [User Guide](docs/users/user-guide.md) — Features and configuration
- [Neovim Quick Reference](docs/users/neovim-quickref.md) — Keymaps and commands cheatsheet
- [Architecture](docs/devel/architecture.md) — System design
- [API Reference](docs/devel/api.md) — Lua API and data types

## License

[License](./LICENSE)
