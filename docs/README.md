# Obsidian Bases for Neovim — Documentation

View, navigate, and edit Obsidian Bases directly from Neovim with unicode tables, clickable wiki-links, and frontmatter editing.

## For Users

| Document | Description |
|----------|-------------|
| [Getting Started](users/getting-started.md) | Installation, setup, and verification |
| [User Guide](users/user-guide.md) | Features, workflow, and configuration |
| [Neovim Quick Reference](users/neovim-quickref.md) | Keymaps, commands, highlights cheatsheet |
| [Bases Syntax](users/bases-syntax.md) | Expression language, filters, and formulas |

## For Developers

| Document | Description |
|----------|-------------|
| [Architecture](devel/architecture.md) | System design, modules, and data flow |
| [API Reference](devel/api.md) | Lua API, data types, and buffer-local state |
| [Contributing](devel/contributing.md) | Dev setup, conventions, and workflow |
| [Testing](devel/testing.md) | Running tests, writing tests, CI setup |

## Requirements

- Neovim 0.11+
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) (for vault path detection and link resolution)
- A vault directory containing markdown (`.md`) and base (`.base`) files
