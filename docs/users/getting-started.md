# Getting Started

This guide will help you install and configure bases.nvim, a Neovim plugin that renders Obsidian Bases as interactive tables.

## Prerequisites

- **Neovim 0.11+**
- **obsidian.nvim** (optional — auto-detects vault path if installed)
- A vault directory containing `.md` and `.base` files

## Installation

### Using lazy.nvim

Add the following to your Neovim configuration:

```lua
{
    'obsidian-nvim/bases.nvim',
    ft = 'obsidian_base',
    config = function()
        require('bases').setup({
            vault_path = '/path/to/vault',
        })
    end,
}
```

The plugin loads lazily when you open a `.base` file. The `ft = 'obsidian_base'` configuration ensures it only loads when needed.

### Explicit Vault Path

If you prefer not to use obsidian.nvim or need to set a specific vault path, configure it explicitly:

```lua
require('bases').setup({
    vault_path = '/Users/username/Documents/MyVault',
})
```

The vault path must be absolute and point to the root directory of your Obsidian vault.

## How It Works

bases.nvim includes a native Lua query engine that reads vault files directly from the filesystem. No running Obsidian instance or HTTP API is required.

The engine works as follows:

1. **Vault Scanning** - Recursively scans the vault directory for `.md` files, skipping `.obsidian/`, `.git/`, and `.trash/` directories
2. **Indexing** - Parses frontmatter, tags, and wikilinks from each note into an in-memory index with secondary indices for fast lookups
3. **Query Parsing** - Reads `.base` files (YAML format) and parses them into query definitions with filters, formulas, and views
4. **Expression Evaluation** - Evaluates filter expressions and formulas using a built-in expression language supporting operators, functions, and methods
5. **Incremental Updates** - Watches the filesystem for changes and updates the index incrementally without full rebuilds

All processing happens in Lua within Neovim. The index is cached to disk using msgpack serialization for fast startup on subsequent sessions.

## Verification

### End-to-End Test

Open a `.base` file to verify the plugin is working:

```vim
:edit /path/to/vault/mybase.base
```

You should see a formatted unicode table with rounded borders:

```
╭─────────────┬──────────┬──────────╮
│ Name        │ Status   │ Priority │
├─────────────┼──────────┼──────────┤
│ Project A   │ Active   │ High     │
│ Project B   │ Complete │ Low      │
│ Project C   │ Pending  │ Medium   │
╰─────────────┴──────────┴──────────╯
```

Test the following features:

- **Editing** - Press `c` on a `note.*` cell to edit the frontmatter property
- **Link Navigation** - Press `<CR>` on a wikilink to follow it, or `<Tab>`/`<S-Tab>` to jump between links
- **Inline Rendering** - Open a markdown file containing `![[mybase.base]]` to see the table rendered inline

### Quick Checks

| Check | Command | Expected |
|-------|---------|----------|
| Plugin loaded | `:lua print(require('bases'))` | Table output |
| Engine ready | `:lua print(require('bases.engine').is_ready())` | `true` |
| Vault path | `:lua print(require('bases.engine').get_vault_path())` | Vault path |

Run these commands to verify each component is properly initialized.

## Troubleshooting

### "vault_path not configured"

The plugin cannot auto-detect your vault path. Set it explicitly in your setup:

```lua
require('bases').setup({
    vault_path = '/absolute/path/to/vault',
})
```

### "engine not ready yet"

The vault index is still building. This is normal for large vaults (thousands of notes) on the first run. The plugin shows a "Loading..." message while indexing. Subsequent runs use the cached index and load much faster.

### "No entries found"

Check the following:

- **YAML syntax** - Ensure your `.base` file is valid YAML
- **Filter expressions** - Verify your filter logic matches existing notes
- **Note frontmatter** - Confirm your notes have the expected frontmatter properties

Open the `.base` file directly in a text editor to inspect the query definition.

## Next Steps

- **[User Guide](user-guide.md)** - Learn keymaps, editing workflows, and advanced features
- **[Bases Syntax](bases-syntax.md)** - Reference for the expression language used in filters and formulas
