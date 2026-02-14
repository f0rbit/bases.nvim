# bases.nvim — Implementation Plan

## Pitch

Obsidian Bases are a powerful way to query and aggregate your vault — but they're invisible the moment you leave the Obsidian app. If you edit notes in Neovim, your `.base` files are just inert YAML. Inline ` ```base``` ` blocks are just text. There is no way to see what they render.

**bases.nvim** fixes this. It's a pure-Lua Neovim plugin that parses and renders Obsidian Bases as formatted Unicode tables, directly in your buffer. It handles both standalone `.base` files and inline code blocks inside markdown notes. Zero external dependencies — no Node.js, no npm, no Obsidian bridge. Just Lua.

It's designed for the "Neovim as editor, Obsidian as companion" workflow. It complements `obsidian.nvim` (vault navigation, note creation) and `render-markdown.nvim` (markdown rendering) by filling the one gap neither covers: Bases.

The engine is forked from [miller3616/bases.nvim](https://github.com/miller3616/bases.nvim) (GPL-3.0), a complete Lua-native implementation of the Obsidian Bases expression language including lexer, parser, evaluator, query engine, and aggregation. We fork the engine (~4,200 LOC across 14 files), fix known issues, and write our own rendering layer (~870 LOC across 5 files) that prioritizes simplicity and read-only display over the original's more complex interactive approach.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│ Plugin Layer (NEW)                                  │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│ │ init.lua │ │buffer.lua│ │inline.lua│ │health   │ │
│ │ setup()  │ │ nofile   │ │ extmarks │ │ check   │ │
│ │ cmds     │ │ scratch  │ │ virt_ln  │ │         │ │
│ └────┬─────┘ └────┬─────┘ └────┬─────┘ └─────────┘ │
│      │             │            │                    │
│      └─────────┬───┘────────────┘                    │
│           ┌────▼─────┐                               │
│           │render.lua│  ← Unicode table renderer     │
│           └────┬─────┘                               │
├────────────────┼────────────────────────────────────-┤
│ Engine Layer   │  (FORKED from miller3616/bases.nvim)│
│           ┌────▼──────────┐                          │
│           │ engine/init   │  ← facade                │
│           └───┬───┬───┬───┘                          │
│     ┌─────────┘   │   └──────────┐                   │
│ ┌───▼────┐  ┌─────▼─────┐ ┌─────▼──────┐            │
│ │note_idx│  │query_engine│ │base_parser │            │
│ │+ watcher│ │+ summaries │ │+ yaml      │            │
│ └───┬────┘  └─────┬──────┘ └────────────┘            │
│     │        ┌────▼──────────────────────┐           │
│     │        │ expr/ (lexer→parser→eval) │           │
│     │        │ types, functions, methods │           │
│     │        └───────────────────────────┘           │
│     │        ┌────────────────┐  ┌──────────┐        │
│     │        │frontmatter_edit│  │serialize │        │
│     │        └────────────────┘  └──────────┘        │
│  ┌──▼───┐                                            │
│  │compat│  ← vim.* replacement utilities             │
│  └──────┘                                            │
└─────────────────────────────────────────────────────┘
```

### Data Flow

```
.base file OR ```base``` block
  → base_parser.parse(filepath_or_string)
  → returns BaseConfig { source, filter, formula, sort, groupBy, summaries }
  → query_engine.execute(base_config, note_index)
  → returns SerializedResult { columns, rows, groups?, summaries? }
  → render.render(serialized_result, opts)
  → returns string[] (lines of Unicode table)
  → buffer.set_lines() OR inline.set_extmarks()
```

### Key Types

```lua
-- From base_parser
---@class BaseConfig
---@field source { folder: string, tag?: string }
---@field filter Expression[]
---@field formula { name: string, expr: Expression }[]
---@field sort { column: string, order: "ASC"|"DESC" }[]
---@field groupBy { column: string, order: "ASC"|"DESC" }?
---@field summaries { column: string, func: string }[]
---@field view "table"|"list"

-- From query_engine (serialized output)
---@class SerializedResult
---@field columns string[]
---@field rows string[][]              -- row[i][j] = display string
---@field types ("string"|"number"|"boolean"|"date"|"list"|"null")[][]
---@field groups { header: string, row_indices: integer[] }[]?
---@field summaries { label: string, values: string[] }[]?
```

---

## File Manifest

| File | Status | Est. LOC | Notes |
|------|--------|----------|-------|
| `lua/bases/init.lua` | NEW | 200 | setup(), config, commands, autocmds |
| `lua/bases/render.lua` | NEW | 350 | Unicode table renderer |
| `lua/bases/buffer.lua` | NEW | 80 | Buffer management for .base files |
| `lua/bases/inline.lua` | NEW | 200 | Inline block detection + extmark rendering |
| `lua/bases/health.lua` | NEW | 40 | `:checkhealth bases` |
| `lua/bases/compat.lua` | NEW | 60 | Pure Lua replacements for vim.* utils |
| `lua/bases/engine/init.lua` | REWRITE | 220 | Engine facade |
| `lua/bases/engine/yaml.lua` | KEEP | 310 | YAML parser |
| `lua/bases/engine/base_parser.lua` | MODIFY | 300 | .base file parser |
| `lua/bases/engine/note_index.lua` | REWRITE | 460 | Vault scanner + index |
| `lua/bases/engine/query_engine.lua` | MODIFY | 350 | Query executor |
| `lua/bases/engine/summaries.lua` | MODIFY | 310 | Aggregation |
| `lua/bases/engine/frontmatter_editor.lua` | MODIFY | 230 | YAML frontmatter read/write |
| `lua/bases/engine/file_watcher.lua` | REWRITE | 200 | Filesystem watcher |
| `lua/bases/engine/serialize.lua` | NEW | 50 | Extracted serialize_value (break circ dep) |
| `lua/bases/engine/expr/types.lua` | KEEP | 340 | TypedValue system |
| `lua/bases/engine/expr/lexer.lua` | KEEP | 350 | Tokenizer |
| `lua/bases/engine/expr/parser.lua` | KEEP | 350 | Recursive descent parser |
| `lua/bases/engine/expr/evaluator.lua` | KEEP | 390 | AST evaluator |
| `lua/bases/engine/expr/functions.lua` | KEEP | 170 | Built-in functions |
| `lua/bases/engine/expr/methods.lua` | MODIFY | 550 | Type methods |
| `plugin/bases.lua` | NEW | 15 | ftdetect + lazy autocmd |
| `tests/init.lua` | NEW | 30 | Test bootstrap |
| `tests/unit/test_lexer.lua` | FORK | 150 | Expression lexer tests |
| `tests/unit/test_parser.lua` | FORK | 150 | Expression parser tests |
| `tests/unit/test_types.lua` | FORK | 100 | Type system tests |
| `tests/unit/test_yaml.lua` | NEW | 120 | YAML parser tests |
| `tests/unit/test_query.lua` | NEW | 200 | Query engine integration |
| `tests/unit/test_render.lua` | NEW | 200 | Rendering output tests |

**Total new code:** ~870 LOC
**Total forked code:** ~4,200 LOC (with ~880 LOC rewritten, ~1,740 LOC modified, ~1,910 LOC kept)
**Total test code:** ~950 LOC

---

## Rendering Specification

### Unicode Box Drawing

```
┌──────────┬───────┬──────────┐
│ Name     │ Score │ Active   │
├──────────┼───────┼──────────┤
│ Project1 │    87 │ ✓        │
│ Project2 │    42 │          │
├──────────┼───────┼──────────┤  ← groupBy separator
│ Archive  │       │          │  ← group header (bold, span full width)
├──────────┼───────┼──────────┤
│ OldThing │    12 │          │
╞══════════╪═══════╪══════════╡  ← summary separator (double line)
│ Average  │  47.0 │          │  ← summary row (italic)
└──────────┴───────┴──────────┘
```

Box-drawing characters:
- Corners: `┌ ┐ └ ┘`
- Borders: `│ ─`
- Intersections: `┼ ├ ┤ ┬ ┴`
- Summary separator: `╞ ╡ ╪ ═`

### Column Alignment

| Type | Alignment | Padding |
|------|-----------|---------|
| string | left | 1 space each side |
| number | right | 1 space each side |
| boolean | center | 1 space each side |
| date | left | 1 space each side |
| list | left | 1 space each side |
| null | center | 1 space each side |

### Value Rendering

| Type | Rendering | Example |
|------|-----------|---------|
| string | as-is, truncated at column max width | `Meeting notes` |
| number | formatted, no trailing zeros | `87`, `3.14` |
| boolean (true) | `✓` | `✓` |
| boolean (false) | ` ` (empty) | |
| list | comma-separated | `tag1, tag2` |
| null | `—` (em dash, dimmed) | `—` |
| date | ISO short format from engine | `2026-02-14` |
| link | `[[name]]` display text | `[[My Note]]` |

### Column Width Calculation

```lua
-- width = max(header_len, max(cell_len for all rows), min_col_width)
-- capped at max_col_width (default 40)
-- total table width capped at terminal width or config.max_table_width
-- if total exceeds cap, proportionally shrink widest columns
```

### Highlight Groups

| Group | Default link | Purpose |
|-------|-------------|---------|
| `BasesTableBorder` | `FloatBorder` | All box-drawing characters |
| `BasesTableHeader` | `@markup.heading` | Column header text |
| `BasesTableRow` | `Normal` | Regular cell text |
| `BasesTableRowAlt` | `CursorLine` | Alternating row background |
| `BasesTableNull` | `Comment` | Null/empty values |
| `BasesTableBoolean` | `@boolean` | Checkmarks |
| `BasesTableNumber` | `@number` | Numeric values |
| `BasesTableLink` | `@markup.link` | Wiki-style links |
| `BasesTableGroupHeader` | `@markup.heading` | groupBy section headers |
| `BasesTableSummary` | `@markup.italic` | Summary footer values |
| `BasesTableSummaryBorder` | `FloatBorder` | Double-line summary separator |

---

## Config Specification

```lua
require("bases").setup({
  -- Path to Obsidian vault root (required)
  vault_path = nil, ---@type string?

  -- Rendering options
  render = {
    max_col_width = 40,       -- Max characters per column
    min_col_width = 5,        -- Min characters per column
    max_table_width = nil,    -- nil = use terminal width
    alternating_rows = true,  -- Alternate row highlighting
    border_style = "rounded", -- "rounded"|"sharp" (rounded uses ╭╮╰╯ corners)
    null_char = "—",          -- Character for null values
    bool_true = "✓",          -- Character for true
    bool_false = " ",         -- Character for false (empty)
    list_separator = ", ",    -- Separator for list values
  },

  -- Inline rendering (```base``` blocks in markdown)
  inline = {
    enabled = true,           -- Enable inline block rendering
    auto_render = true,       -- Render on BufEnter/TextChanged
  },

  -- File watcher
  watcher = {
    enabled = true,           -- Watch vault for file changes
    debounce_ms = 500,        -- Debounce file change events
  },

  -- Note index
  index = {
    extensions = { "md" },    -- File extensions to index
    ignore_dirs = {           -- Directories to skip
      ".obsidian", ".git", ".trash", "node_modules",
    },
  },
})
```

### Commands

| Command | Description |
|---------|-------------|
| `:BasesRender` | Render the current `.base` file or re-render inline blocks |
| `:BasesRefresh` | Force re-index vault and re-render |
| `:BasesClear` | Clear rendered output (show raw source) |
| `:BasesToggle` | Toggle between rendered and raw view |
| `:BasesDebug` | Show parsed BaseConfig for current file/block |

### Autocmds

| Event | Pattern | Action |
|-------|---------|--------|
| `BufReadCmd` | `*.base` | Parse and render .base file in scratch buffer |
| `BufEnter` | `*.md` | Detect and render inline ```base``` blocks (if inline.enabled) |
| `FileType` | `base` | Set buffer options, keymaps |

---

## Phase Breakdown

### Phase 0: Scaffold

**Goal:** Create the directory structure, LICENSE, stubs, and plugin boilerplate. No functionality.

#### Task 0.1: Create project skeleton

- **Files:** All directories, `LICENSE`, `plugin/bases.lua`, stub files
- **LOC:** ~30 (boilerplate only)
- **Dependencies:** None
- **Parallel:** No (foundation task)
- **Instructions for coder:**
  1. Create `~/dev/bases.nvim/` with the full directory tree from the file manifest
  2. Add GPL-3.0 `LICENSE` file (copy standard text, copyright `2025 f0rbit`, note fork from miller3616/bases.nvim)
  3. Create `plugin/bases.lua`:
     ```lua
     vim.filetype.add({ extension = { base = "base" } })
     vim.api.nvim_create_autocmd("FileType", {
       pattern = "base",
       callback = function()
         require("bases").attach()
       end,
     })
     ```
  4. Create empty stub files for every file in the manifest (just a comment header with the file's purpose)
  5. Create `tests/init.lua` bootstrap that adds the plugin to package.path
- **Verification:** All directories exist, `plugin/bases.lua` is valid Lua syntax

---

### Phase 1: Fork Engine

**Goal:** Copy, adapt, and verify the 14 engine files from miller3616/bases.nvim. After this phase, the engine layer works standalone with no rendering.

#### Task 1.0: Create compat.lua (utility module)

- **Files:** `lua/bases/compat.lua`
- **LOC:** ~60
- **Dependencies:** None
- **Parallel:** Yes (runs alongside Task 1.1)
- **Instructions for coder:**
  Create a module exporting pure-Lua replacements for vim.* utilities used in the engine:
  ```lua
  local M = {}

  function M.startswith(s, prefix)
    return s:sub(1, #prefix) == prefix
  end

  function M.endswith(s, suffix)
    return suffix == "" or s:sub(-#suffix) == suffix
  end

  function M.trim(s)
    return s:match("^%s*(.-)%s*$")
  end

  function M.pesc(s)
    return s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  end

  function M.tbl_isempty(t)
    return next(t) == nil
  end

  function M.tbl_keys(t)
    local keys = {}
    for k, _ in pairs(t) do keys[#keys + 1] = k end
    return keys
  end

  function M.tbl_count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end

  function M.deepcopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
      copy[M.deepcopy(k)] = M.deepcopy(v)
    end
    return setmetatable(copy, getmetatable(orig))
  end

  -- Read file lines (replaces vim.fn.readfile)
  function M.readfile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local lines = {}
    for line in f:lines() do lines[#lines + 1] = line end
    f:close()
    return lines
  end

  -- Write file lines (replaces vim.fn.writefile)
  function M.writefile(lines, path)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"))
    f:write("\n")
    f:close()
    return true
  end

  return M
  ```
- **Verification:** All functions work as pure Lua (no vim.* usage). Can be tested outside Neovim.

#### Task 1.1: Copy pure-Lua engine files (KEEP AS-IS)

- **Files:** `lua/bases/engine/expr/types.lua`, `expr/lexer.lua`, `expr/parser.lua`, `expr/evaluator.lua`, `expr/functions.lua`, `lua/bases/engine/yaml.lua`
- **LOC:** ~1,910 (copy, do not modify logic)
- **Dependencies:** None
- **Parallel:** Yes (runs alongside Task 1.0)
- **Instructions for coder:**
  1. Clone miller3616/bases.nvim repo to a temp location
  2. Copy these 6 files verbatim from `lua/bases/engine/` into `lua/bases/engine/` in our project
  3. Update `require()` paths: change `require("bases.engine.X")` → `require("bases.engine.X")` (should be the same, but verify all internal requires match our directory structure)
  4. Add a header comment to each file:
     ```lua
     -- Forked from miller3616/bases.nvim (GPL-3.0)
     -- Original: lua/bases/engine/expr/types.lua
     -- No modifications from upstream
     ```
  5. Do NOT modify any logic. These are pure Lua and should work as-is.
- **Verification:** Each file parses without syntax errors. `require()` paths resolve correctly within the project structure.

#### Task 1.2: Create serialize.lua (break circular dependency)

- **Files:** `lua/bases/engine/serialize.lua`
- **LOC:** ~50
- **Dependencies:** Task 1.1 (needs types.lua)
- **Parallel:** Yes (runs alongside Task 1.3)
- **Instructions for coder:**
  1. Extract `serialize_value` function from the upstream `query_engine.lua` (it's used by both query_engine and summaries, creating a circular dependency)
  2. Create `lua/bases/engine/serialize.lua`:
     ```lua
     -- Extracted from query_engine.lua to break circular dependency
     -- between query_engine and summaries
     local types = require("bases.engine.expr.types")

     local M = {}

     --- Serialize a TypedValue to a display string
     ---@param tv TypedValue
     ---@return string
     function M.serialize_value(tv)
       -- ... copy the serialize_value logic from query_engine.lua
       -- It converts TypedValue → display string
       -- Handles: string, number, boolean, date, list, null
     end

     return M
     ```
  3. The function should handle all TypedValue variants from types.lua
- **Verification:** Module loads, serialize_value handles all TypedValue types.

#### Task 1.3: Adapt engine files with minor modifications (MODIFY)

- **Files:** `lua/bases/engine/expr/methods.lua`, `lua/bases/engine/base_parser.lua`, `lua/bases/engine/query_engine.lua`, `lua/bases/engine/summaries.lua`, `lua/bases/engine/frontmatter_editor.lua`
- **LOC:** ~1,740 (copy with targeted replacements)
- **Dependencies:** Task 1.0 (compat.lua), Task 1.1 (pure files), Task 1.2 (serialize.lua)
- **Parallel:** No (depends on 1.0, 1.1, 1.2)
- **Instructions for coder:**
  1. Clone miller3616/bases.nvim if not already done
  2. Copy these 5 files from upstream
  3. Add fork header comment to each
  4. Make these specific replacements in each file:

  **`expr/methods.lua`** (~5 replacements):
  - Add `local compat = require("bases.compat")` at top
  - `vim.startswith(...)` → `compat.startswith(...)`
  - `vim.endswith(...)` → `compat.endswith(...)`
  - `vim.pesc(...)` → `compat.pesc(...)`
  - `vim.trim(...)` → `compat.trim(...)`
  - `vim.deepcopy(...)` → `compat.deepcopy(...)`

  **`base_parser.lua`** (~2 replacements):
  - Add `local compat = require("bases.compat")` at top
  - `vim.fn.readfile(path)` → `compat.readfile(path)` (in parse function)
  - Ensure parse() returns nil/error gracefully if file not found

  **`query_engine.lua`** (~4 replacements):
  - Add `local compat = require("bases.compat")` at top
  - Add `local serialize = require("bases.engine.serialize")` at top
  - `vim.tbl_isempty(...)` → `compat.tbl_isempty(...)`
  - `vim.tbl_keys(...)` → `compat.tbl_keys(...)`
  - `vim.tbl_count(...)` → `compat.tbl_count(...)`
  - Remove inline `serialize_value` function, use `serialize.serialize_value` instead
  - Remove any direct `require` of summaries that creates a cycle

  **`summaries.lua`** (~2 replacements):
  - Add `local compat = require("bases.compat")` at top
  - Add `local serialize = require("bases.engine.serialize")` at top
  - `vim.tbl_isempty(...)` → `compat.tbl_isempty(...)`
  - Use `serialize.serialize_value` instead of requiring query_engine for it

  **`frontmatter_editor.lua`** (~3 replacements):
  - Add `local compat = require("bases.compat")` at top
  - `vim.fn.readfile(path)` → `compat.readfile(path)`
  - `vim.fn.writefile(lines, path)` → `compat.writefile(lines, path)`
  - `vim.deepcopy(...)` → `compat.deepcopy(...)`

- **Verification:** All 5 files parse without syntax errors. No remaining `vim.fn.*` or `vim.tbl_*` calls (grep to confirm). `require()` chains resolve without circular dependencies.

#### Task 1.4: Rewrite engine facade and infrastructure (REWRITE)

- **Files:** `lua/bases/engine/init.lua`, `lua/bases/engine/note_index.lua`, `lua/bases/engine/file_watcher.lua`
- **LOC:** ~880
- **Dependencies:** Task 1.3 (all modified files must be in place)
- **Parallel:** No (depends on full engine)
- **Instructions for coder:**

  **`engine/init.lua`** (~220 LOC) — Engine facade:
  ```lua
  local M = {}

  local _index = nil    -- NoteIndex instance
  local _watcher = nil  -- FileWatcher instance
  local _config = nil   -- Plugin config reference

  --- Initialize the engine with config
  ---@param config table Plugin config from setup()
  function M.setup(config)
    _config = config
    -- Lazy: don't build index until first query
  end

  --- Get or create the note index
  ---@return NoteIndex
  function M.get_index()
    if not _index then
      local NoteIndex = require("bases.engine.note_index")
      _index = NoteIndex.new(_config.vault_path, {
        extensions = _config.index.extensions,
        ignore_dirs = _config.index.ignore_dirs,
      })
      _index:build()
    end
    return _index
  end

  --- Execute a base query from a file path or parsed config
  ---@param input string|BaseConfig File path or parsed config
  ---@return SerializedResult?
  ---@return string? error
  function M.query(input)
    local base_parser = require("bases.engine.base_parser")
    local query_engine = require("bases.engine.query_engine")

    local config
    if type(input) == "string" then
      -- It's a file path
      config = base_parser.parse(input)
    else
      config = input
    end

    if not config then
      return nil, "Failed to parse base config"
    end

    local index = M.get_index()
    return query_engine.execute(config, index)
  end

  --- Start file watching
  function M.watch()
    if _config.watcher.enabled and not _watcher then
      local FileWatcher = require("bases.engine.file_watcher")
      _watcher = FileWatcher.new(_config.vault_path, {
        debounce_ms = _config.watcher.debounce_ms,
        on_change = function()
          M.invalidate()
        end,
      })
      _watcher:start()
    end
  end

  --- Stop file watching
  function M.unwatch()
    if _watcher then
      _watcher:stop()
      _watcher = nil
    end
  end

  --- Invalidate the index (force rebuild on next query)
  function M.invalidate()
    _index = nil
  end

  --- Parse a base config from string content (for inline blocks)
  ---@param content string YAML content of the base block
  ---@param source_path string Path of the file containing the block
  ---@return BaseConfig?
  ---@return string? error
  function M.parse_inline(content, source_path)
    local base_parser = require("bases.engine.base_parser")
    return base_parser.parse_string(content, source_path)
  end

  return M
  ```

  **`note_index.lua`** (~460 LOC) — Vault scanner + in-memory index:
  - Study the upstream note_index.lua for the data structure design (it's good)
  - Keep the same index shape: `{ notes = {}, by_tag = {}, by_folder = {} }`
  - Replace `vim.uv.fs_scandir` / `vim.uv.fs_stat` with Lua `lfs` if available or `vim.uv` (since we're in Neovim context, vim.uv IS available — this is the one legitimate use)
  - Actually: **use `vim.uv` for filesystem** — this module only runs inside Neovim, so vim.uv is fine here. The pure-Lua replacements in compat.lua are for the expression engine files that we want testable outside Neovim.
  - Key methods:
    - `NoteIndex.new(vault_path, opts)` — constructor
    - `NoteIndex:build()` — full recursive scan, parse frontmatter, build indices
    - `NoteIndex:get_notes_in_folder(folder)` — returns notes matching folder
    - `NoteIndex:get_notes_by_tag(tag)` — returns notes matching tag
    - `NoteIndex:get_note(path)` — returns single note metadata
    - `NoteIndex:invalidate()` — clear all indices
  - Note metadata shape:
    ```lua
    ---@class NoteMeta
    ---@field path string       -- absolute path
    ---@field rel_path string   -- relative to vault root
    ---@field name string       -- filename without extension
    ---@field folder string     -- parent folder relative to vault
    ---@field frontmatter table -- parsed YAML frontmatter
    ---@field tags string[]     -- extracted tags (from frontmatter + inline)
    ---@field mtime number      -- modification time (unix timestamp)
    ---@field ext string        -- file extension
    ```
  - Use the engine's own `yaml.lua` to parse frontmatter (not a third-party YAML parser)
  - Frontmatter extraction: read file, find `---` delimiters, parse YAML between them

  **`file_watcher.lua`** (~200 LOC) — Filesystem watcher:
  - Use `vim.uv.new_fs_event()` to watch the vault directory
  - Debounce rapid changes (use vim.defer_fn or a timer)
  - On change, call the `on_change` callback (which invalidates the index)
  - Methods:
    - `FileWatcher.new(path, opts)` — constructor
    - `FileWatcher:start()` — begin watching
    - `FileWatcher:stop()` — stop watching
  - Keep it simple: watch the vault root recursively. Don't try to be surgical about which files changed. Just invalidate the whole index on any change.

- **Verification:**
  1. `require("bases.engine").setup({ vault_path = "...", ... })` doesn't error
  2. `require("bases.engine").get_index()` scans a vault directory and returns an index with notes
  3. `require("bases.engine").query("/path/to/test.base")` returns a SerializedResult
  4. No vim.* calls in compat.lua; vim.uv calls only in note_index.lua and file_watcher.lua

#### Phase 1 Verification

After all Phase 1 tasks complete, the verification agent should:
1. `grep -r "vim.fn\." lua/bases/engine/` — should return zero hits (except note_index/file_watcher which use vim.uv)
2. `grep -r "vim.tbl_" lua/bases/engine/` — should return zero hits
3. `grep -r "vim.startswith\|vim.endswith\|vim.trim\|vim.pesc\|vim.deepcopy" lua/bases/engine/` — zero hits
4. Verify no circular require chains (summaries ↔ query_engine specifically)
5. If a test harness exists: run `nvim --headless -c "lua require('bases.engine').setup({vault_path='/Users/tom/Documents/Vaults/Personal', index={extensions={'md'}, ignore_dirs={'.obsidian','.git','.trash'}}, watcher={enabled=false}}); local idx = require('bases.engine').get_index(); print(vim.inspect(vim.tbl_count(idx.notes)))" -c "qa"`

---

### Phase 2: Core Rendering

**Goal:** Build the rendering layer that converts SerializedResult into Unicode table strings and displays them in buffers.

#### Task 2.1: Build render.lua

- **Files:** `lua/bases/render.lua`
- **LOC:** ~350
- **Dependencies:** Phase 1 complete (needs SerializedResult type)
- **Parallel:** Yes (runs alongside Task 2.2 and Task 2.3)
- **Instructions for coder:**

  This is the core renderer. It takes a `SerializedResult` and render config, and returns two things:
  1. `lines: string[]` — the text lines of the rendered table
  2. `highlights: { line: integer, col_start: integer, col_end: integer, group: string }[]` — highlight positions

  **Structure:**

  ```lua
  local M = {}

  -- Box-drawing character sets
  M.borders = {
    sharp = {
      tl = "┌", tr = "┐", bl = "└", br = "┘",
      h = "─", v = "│",
      t = "┬", b = "┴", l = "├", r = "┤", x = "┼",
      -- Summary separator (double)
      sl = "╞", sr = "╡", sx = "╪", sh = "═",
    },
    rounded = {
      tl = "╭", tr = "╮", bl = "╰", br = "╯",
      h = "─", v = "│",
      t = "┬", b = "┴", l = "├", r = "┤", x = "┼",
      sl = "╞", sr = "╡", sx = "╪", sh = "═",
    },
  }

  --- Calculate column widths from data
  ---@param result SerializedResult
  ---@param opts table Render config
  ---@return integer[] Column widths
  local function calc_col_widths(result, opts)
    -- Start with header widths
    -- Expand to max cell width in each column
    -- Clamp between min_col_width and max_col_width
    -- If total > max_table_width, proportionally shrink widest
  end

  --- Format a cell value with alignment and padding
  ---@param value string Display string
  ---@param width integer Target width
  ---@param type_tag string Type of the value
  ---@return string Padded string
  local function format_cell(value, width, type_tag)
    -- Left align: string, date, list, link
    -- Right align: number
    -- Center align: boolean, null
    -- Pad with spaces to target width
  end

  --- Render a horizontal border line
  local function render_border(widths, b, left, mid, right)
    -- e.g., "├──────┼───────┼──────┤"
  end

  --- Render a data row
  local function render_row(values, types, widths, b)
    -- "│ val1  │  val2 │ val3  │"
  end

  --- Main render function
  ---@param result SerializedResult
  ---@param opts table Render config from setup()
  ---@return string[] lines
  ---@return table[] highlights Array of {line, col_start, col_end, group}
  function M.render(result, opts)
    local lines = {}
    local highlights = {}
    local b = M.borders[opts.border_style] or M.borders.rounded
    local widths = calc_col_widths(result, opts)

    -- 1. Top border
    -- 2. Header row (with BasesTableHeader highlights)
    -- 3. Header separator
    -- 4. Data rows (grouped if result.groups exists)
    --    - For each group: group header line, separator, rows
    --    - If alternating_rows, alternate BasesTableRow/BasesTableRowAlt
    --    - Track highlights for each cell based on its type
    -- 5. Summary separator (double line) if result.summaries exists
    -- 6. Summary rows (with BasesTableSummary highlights)
    -- 7. Bottom border

    return lines, highlights
  end

  --- Setup highlight groups (called once during plugin setup)
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
  ```

  **Critical details:**
  - Use `vim.fn.strdisplaywidth()` (or `vim.api.nvim_strwidth()`) for measuring string widths since Unicode characters like `✓` and `—` may be multi-byte but single-width
  - Handle the case where `result.groups` is nil (no groupBy) — just render flat rows
  - Handle the case where `result.summaries` is nil — skip summary section
  - Null values should use `opts.null_char` and get `BasesTableNull` highlight
  - Boolean true should use `opts.bool_true`, false should use `opts.bool_false`
  - Lists should be joined with `opts.list_separator`

- **Verification:** Given a hardcoded SerializedResult, `render()` returns correctly formatted table lines. Highlight positions are accurate byte offsets.

#### Task 2.2: Build buffer.lua

- **Files:** `lua/bases/buffer.lua`
- **LOC:** ~80
- **Dependencies:** Phase 1 complete
- **Parallel:** Yes (runs alongside Task 2.1 and Task 2.3)
- **Instructions for coder:**

  ```lua
  local M = {}

  --- Create or get a scratch buffer for a .base file
  ---@param source_path string Path to the .base file
  ---@return integer bufnr
  function M.create(source_path)
    local bufnr = vim.api.nvim_get_current_buf()

    -- Set buffer options
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].filetype = "base"

    -- Store source path as buffer variable for re-rendering
    vim.b[bufnr].bases_source = source_path

    return bufnr
  end

  --- Set lines in a buffer (temporarily makes it modifiable)
  ---@param bufnr integer
  ---@param lines string[]
  function M.set_lines(bufnr, lines)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
  end

  --- Apply highlights to a buffer
  ---@param bufnr integer
  ---@param highlights table[] Array of {line, col_start, col_end, group}
  ---@param ns_id integer Namespace ID
  function M.apply_highlights(bufnr, highlights, ns_id)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
    end
  end

  --- Set up keymaps for a base buffer
  ---@param bufnr integer
  function M.set_keymaps(bufnr)
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "r", function()
      require("bases").render_current()
    end, vim.tbl_extend("force", opts, { desc = "Re-render base" }))
    vim.keymap.set("n", "q", function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end, vim.tbl_extend("force", opts, { desc = "Close base view" }))
  end

  return M
  ```

- **Verification:** Can create a scratch buffer, set lines, apply highlights, and close it.

#### Task 2.3: Build inline.lua

- **Files:** `lua/bases/inline.lua`
- **LOC:** ~200
- **Dependencies:** Phase 1 complete, render.lua (conceptually, but can stub for now)
- **Parallel:** Yes (runs alongside Task 2.1 and Task 2.2)
- **Instructions for coder:**

  ```lua
  local M = {}

  local ns_id = vim.api.nvim_create_namespace("bases_inline")

  --- Find all ```base``` code blocks in a buffer
  ---@param bufnr integer
  ---@return { start_line: integer, end_line: integer, content: string }[]
  function M.find_blocks(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local blocks = {}
    local in_block = false
    local current = nil

    for i, line in ipairs(lines) do
      if not in_block and line:match("^%s*```base%s*$") then
        in_block = true
        current = { start_line = i - 1, content_lines = {} }  -- 0-indexed
      elseif in_block and line:match("^%s*```%s*$") then
        in_block = false
        current.end_line = i - 1  -- 0-indexed
        current.content = table.concat(current.content_lines, "\n")
        current.content_lines = nil
        blocks[#blocks + 1] = current
        current = nil
      elseif in_block then
        current.content_lines[#current.content_lines + 1] = line
      end
    end

    return blocks
  end

  --- Render inline blocks in a buffer
  ---@param bufnr integer
  function M.render(bufnr)
    -- Clear previous extmarks
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

    local config = require("bases").config
    local engine = require("bases.engine")
    local render = require("bases.render")

    local source_path = vim.api.nvim_buf_get_name(bufnr)
    local blocks = M.find_blocks(bufnr)

    for _, block in ipairs(blocks) do
      -- Parse the block content as a base config
      local base_config, err = engine.parse_inline(block.content, source_path)
      if base_config then
        -- Execute the query
        local result, qerr = engine.query(base_config)
        if result then
          -- Render to lines
          local lines, highlights = render.render(result, config.render)

          -- Create virtual lines below the code block's closing ```
          local virt_lines = {}
          for _, line in ipairs(lines) do
            -- Each virt_line is an array of {text, highlight_group} chunks
            -- For simplicity, render as single chunk with border highlight
            -- TODO: Per-cell highlighting via chunks
            virt_lines[#virt_lines + 1] = { { line, "BasesTableBorder" } }
          end

          vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.end_line, 0, {
            virt_lines = virt_lines,
            virt_lines_above = false,
          })
        else
          -- Show error as virtual text
          vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.end_line, 0, {
            virt_lines = { { { "bases.nvim: " .. (qerr or "query failed"), "ErrorMsg" } } },
          })
        end
      else
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.end_line, 0, {
          virt_lines = { { { "bases.nvim: " .. (err or "parse failed"), "ErrorMsg" } } },
        })
      end
    end
  end

  --- Clear all inline renders in a buffer
  ---@param bufnr integer
  function M.clear(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end

  return M
  ```

  **Critical details:**
  - Use `virt_lines` extmarks to display the rendered table below the code block
  - Don't replace the original code block text — keep it visible and add the rendered output below
  - Handle parse/query errors gracefully with error virtual text
  - The `find_blocks` function must handle nested code fences (only match ` ```base``` ` at the right level)
  - For v1, per-cell highlighting in inline mode is a stretch goal. Start with the entire rendered line using `BasesTableBorder` highlight, then improve in v2.

- **Verification:** `find_blocks()` correctly identifies ` ```base``` ` blocks in a markdown buffer. Extmarks render below code blocks.

#### Phase 2 Verification

After all Phase 2 tasks complete, the verification agent should:
1. Open a `.base` file in Neovim and verify the render pipeline works end-to-end (manually, via `:lua` commands)
2. Check that render.lua handles edge cases: empty results, single column, no summaries, no groups
3. Verify highlight groups are defined and applied correctly
4. Verify inline block detection works in a markdown file with ` ```base``` ` blocks

---

### Phase 3: Plugin Glue

**Goal:** Wire everything together with init.lua, health.lua, commands, and autocmds.

#### Task 3.1: Build init.lua (plugin entry point)

- **Files:** `lua/bases/init.lua`
- **LOC:** ~200
- **Dependencies:** Phase 2 complete
- **Parallel:** Yes (runs alongside Task 3.2)
- **Instructions for coder:**

  ```lua
  local M = {}

  M.config = {}
  M.ns_id = vim.api.nvim_create_namespace("bases")

  local defaults = {
    vault_path = nil,
    render = {
      max_col_width = 40,
      min_col_width = 5,
      max_table_width = nil,
      alternating_rows = true,
      border_style = "rounded",
      null_char = "—",
      bool_true = "✓",
      bool_false = " ",
      list_separator = ", ",
    },
    inline = {
      enabled = true,
      auto_render = true,
    },
    watcher = {
      enabled = true,
      debounce_ms = 500,
    },
    index = {
      extensions = { "md" },
      ignore_dirs = { ".obsidian", ".git", ".trash", "node_modules" },
    },
  }

  --- Deep merge two tables (b overrides a)
  local function deep_merge(a, b)
    local result = vim.deepcopy(a)
    for k, v in pairs(b or {}) do
      if type(v) == "table" and type(result[k]) == "table" then
        result[k] = deep_merge(result[k], v)
      else
        result[k] = v
      end
    end
    return result
  end

  --- Setup the plugin
  ---@param opts table? User config
  function M.setup(opts)
    M.config = deep_merge(defaults, opts or {})

    if not M.config.vault_path then
      vim.notify("bases.nvim: vault_path is required in setup()", vim.log.levels.ERROR)
      return
    end

    -- Expand ~ in vault path
    M.config.vault_path = vim.fn.expand(M.config.vault_path)

    -- Setup engine
    local engine = require("bases.engine")
    engine.setup(M.config)

    -- Setup highlights
    local render = require("bases.render")
    render.setup_highlights()

    -- Register commands
    M.register_commands()

    -- Register autocmds
    M.register_autocmds()

    -- Start file watcher
    engine.watch()
  end

  function M.register_commands()
    vim.api.nvim_create_user_command("BasesRender", function()
      M.render_current()
    end, { desc = "Render current .base file or inline blocks" })

    vim.api.nvim_create_user_command("BasesRefresh", function()
      require("bases.engine").invalidate()
      M.render_current()
    end, { desc = "Re-index vault and re-render" })

    vim.api.nvim_create_user_command("BasesClear", function()
      M.clear_current()
    end, { desc = "Clear rendered output" })

    vim.api.nvim_create_user_command("BasesToggle", function()
      M.toggle_current()
    end, { desc = "Toggle rendered/raw view" })

    vim.api.nvim_create_user_command("BasesDebug", function()
      M.debug_current()
    end, { desc = "Show parsed base config" })
  end

  function M.register_autocmds()
    local group = vim.api.nvim_create_augroup("bases_nvim", { clear = true })

    -- .base files: render on open
    vim.api.nvim_create_autocmd("BufReadCmd", {
      group = group,
      pattern = "*.base",
      callback = function(ev)
        M.render_base_file(ev.buf, ev.file)
      end,
    })

    -- Markdown files: render inline blocks
    if M.config.inline.enabled and M.config.inline.auto_render then
      vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        pattern = "*.md",
        callback = function(ev)
          -- Only render if file is in the vault
          local path = vim.api.nvim_buf_get_name(ev.buf)
          if path:find(M.config.vault_path, 1, true) then
            require("bases.inline").render(ev.buf)
          end
        end,
      })
    end
  end

  --- Render a .base file into a scratch buffer
  ---@param bufnr integer
  ---@param filepath string
  function M.render_base_file(bufnr, filepath)
    local buffer = require("bases.buffer")
    local engine = require("bases.engine")
    local render = require("bases.render")

    -- Setup the buffer
    buffer.create(filepath)
    buffer.set_keymaps(bufnr)

    -- Execute the query
    local result, err = engine.query(filepath)
    if not result then
      buffer.set_lines(bufnr, { "bases.nvim: " .. (err or "unknown error") })
      return
    end

    -- Render
    local lines, highlights = render.render(result, M.config.render)
    buffer.set_lines(bufnr, lines)
    buffer.apply_highlights(bufnr, highlights, M.ns_id)
  end

  --- Render current buffer (dispatch to .base or inline)
  function M.render_current()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype

    if ft == "base" then
      local source = vim.b[bufnr].bases_source or vim.api.nvim_buf_get_name(bufnr)
      M.render_base_file(bufnr, source)
    elseif ft == "markdown" then
      require("bases.inline").render(bufnr)
    end
  end

  --- Clear current buffer rendering
  function M.clear_current()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype

    if ft == "markdown" then
      require("bases.inline").clear(bufnr)
    end
    -- For .base files, clearing means showing raw YAML — skip for v1
  end

  --- Toggle rendered/raw view
  function M.toggle_current()
    -- For v1: just re-render or clear
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype

    if ft == "markdown" then
      local inline = require("bases.inline")
      -- Check if there are existing extmarks
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, inline.ns_id or
        vim.api.nvim_create_namespace("bases_inline"), 0, -1, {})
      if #marks > 0 then
        inline.clear(bufnr)
      else
        inline.render(bufnr)
      end
    end
  end

  --- Show debug info for current base
  function M.debug_current()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype
    local engine = require("bases.engine")

    if ft == "base" then
      local source = vim.b[bufnr].bases_source or vim.api.nvim_buf_get_name(bufnr)
      local base_parser = require("bases.engine.base_parser")
      local config = base_parser.parse(source)
      vim.notify(vim.inspect(config), vim.log.levels.INFO)
    end
  end

  --- Called by plugin/bases.lua on FileType=base
  function M.attach()
    -- Any per-buffer setup for .base files
    -- Currently handled by BufReadCmd, but this is the hook
    -- for future FileType-based setup
  end

  return M
  ```

- **Verification:** `:lua require("bases").setup({ vault_path = "~/Documents/Vaults/Personal" })` initializes without error. Commands are registered. Autocmds fire correctly.

#### Task 3.2: Build health.lua

- **Files:** `lua/bases/health.lua`
- **LOC:** ~40
- **Dependencies:** None (can reference engine but doesn't depend on it)
- **Parallel:** Yes (runs alongside Task 3.1)
- **Instructions for coder:**

  ```lua
  local M = {}

  function M.check()
    vim.health.start("bases.nvim")

    -- Check Neovim version
    if vim.fn.has("nvim-0.10") == 1 then
      vim.health.ok("Neovim >= 0.10")
    else
      vim.health.error("Neovim >= 0.10 required (for vim.uv, extmarks features)")
    end

    -- Check vault path configured
    local config = require("bases").config
    if config.vault_path then
      vim.health.ok("vault_path: " .. config.vault_path)

      -- Check vault exists
      local stat = vim.uv.fs_stat(config.vault_path)
      if stat and stat.type == "directory" then
        vim.health.ok("vault directory exists")
      else
        vim.health.error("vault directory not found: " .. config.vault_path)
      end
    else
      vim.health.warn("vault_path not configured (call require('bases').setup())")
    end

    -- Check engine loads
    local ok, err = pcall(require, "bases.engine")
    if ok then
      vim.health.ok("engine module loads")
    else
      vim.health.error("engine module failed to load: " .. tostring(err))
    end

    -- Check expression engine
    local ok2, err2 = pcall(function()
      local lexer = require("bases.engine.expr.lexer")
      local parser = require("bases.engine.expr.parser")
      local eval = require("bases.engine.expr.evaluator")
      -- Quick smoke test
      local tokens = lexer.tokenize("1 + 2")
      local ast = parser.parse(tokens)
      -- If we get here, the expression pipeline works
    end)
    if ok2 then
      vim.health.ok("expression engine works (lexer → parser pipeline)")
    else
      vim.health.error("expression engine failed: " .. tostring(err2))
    end
  end

  return M
  ```

- **Verification:** `:checkhealth bases` runs and shows status for all checks.

#### Phase 3 Verification

After all Phase 3 tasks complete, the verification agent should:
1. Test full pipeline: `require("bases").setup({vault_path="~/Documents/Vaults/Personal"})` → open a `.base` file → see rendered table
2. Test all commands: `:BasesRender`, `:BasesRefresh`, `:BasesClear`, `:BasesToggle`, `:BasesDebug`
3. Test inline rendering: open a markdown file with ` ```base``` ` blocks in the vault
4. `:checkhealth bases` passes all checks
5. Test error handling: open a `.base` file with invalid YAML, verify graceful error message

---

### Phase 4: Testing

**Goal:** Fork relevant tests from upstream, write new tests for our rendering and integration.

> **Note:** Neovim Lua plugin testing is different from the bun/TypeScript testing in our standard skills. Tests run via `nvim --headless` using either busted, plenary.nvim, or a custom test harness. We'll use a minimal custom harness for simplicity.

#### Task 4.1: Test harness + fork expression tests

- **Files:** `tests/init.lua`, `tests/unit/test_lexer.lua`, `tests/unit/test_parser.lua`, `tests/unit/test_types.lua`
- **LOC:** ~430
- **Dependencies:** Phase 1 complete
- **Parallel:** Yes (runs alongside Task 4.2)
- **Instructions for coder:**

  **`tests/init.lua`** — Minimal test runner:
  ```lua
  -- Test bootstrap for bases.nvim
  -- Run with: nvim --headless -u tests/init.lua -c "qa"
  -- Or for specific: nvim --headless -u tests/init.lua -c "luafile tests/unit/test_lexer.lua" -c "qa"

  -- Add plugin to runtime path
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  vim.opt.runtimepath:prepend(plugin_dir)

  -- Minimal assertion helpers
  _G.assert_eq = function(a, b, msg)
    if a ~= b then
      error(string.format("%s\nExpected: %s\nGot: %s", msg or "assertion failed", vim.inspect(b), vim.inspect(a)), 2)
    end
  end

  _G.assert_true = function(a, msg)
    if not a then
      error(msg or "expected truthy value", 2)
    end
  end

  _G.describe = function(name, fn)
    print("  " .. name)
    fn()
  end

  _G.it = function(name, fn)
    local ok, err = pcall(fn)
    if ok then
      print("    ✓ " .. name)
    else
      print("    ✗ " .. name)
      print("      " .. tostring(err))
      _G._test_failures = (_G._test_failures or 0) + 1
    end
    _G._test_count = (_G._test_count or 0) + 1
  end
  ```

  Fork the upstream test files for lexer, parser, and types. Adapt them to use our test harness (the upstream uses plenary.nvim's `describe`/`it` which is similar). Update require paths to match our structure.

- **Verification:** `nvim --headless -u tests/init.lua -c "luafile tests/unit/test_lexer.lua" -c "qa"` runs and passes.

#### Task 4.2: Write new tests

- **Files:** `tests/unit/test_yaml.lua`, `tests/unit/test_query.lua`, `tests/unit/test_render.lua`
- **LOC:** ~520
- **Dependencies:** Phase 1 and Phase 2 complete
- **Parallel:** Yes (runs alongside Task 4.1)
- **Instructions for coder:**

  **`test_yaml.lua`** (~120 LOC):
  - Test the YAML parser with Obsidian-style frontmatter
  - Test cases: basic key-value, lists, nested maps, multiline strings, quoted strings, empty values
  - Test edge case: the operator precedence bug in literal/folded block handling (document whether fixed or known)

  **`test_query.lua`** (~200 LOC):
  - Integration test: create a temporary directory with mock markdown files (with frontmatter)
  - Build a note index from that directory
  - Parse a base config string
  - Execute the query
  - Verify the SerializedResult has expected columns, row count, values
  - Test filters: inFolder, tag matching, frontmatter field comparison
  - Test formulas: simple field access, function calls
  - Test sorting: ASC, DESC
  - Test groupBy: verify groups structure in result

  **`test_render.lua`** (~200 LOC):
  - Unit test the renderer with hardcoded SerializedResults
  - Test cases:
    1. Simple 3-column table → verify border characters, alignment, padding
    2. Table with boolean/null values → verify `✓`, `—` rendering
    3. Table with groupBy → verify group headers and separators
    4. Table with summaries → verify double-line separator and summary row
    5. Empty result (no rows) → verify header-only table
    6. Single column → verify degenerate case
    7. Long values → verify truncation at max_col_width

- **Verification:** All test files run and pass. `test_query.lua` cleans up temporary files after running.

#### Phase 4 Verification

After all Phase 4 tasks complete, the verification agent should:
1. Run all tests: `nvim --headless -u tests/init.lua` + luafile each test file
2. Verify no test failures
3. Verify temporary files are cleaned up

---

### Phase 5: Polish

**Goal:** README, edge case handling, error messages, manual testing against Tom's vault.

#### Task 5.1: Manual vault testing + edge case fixes

- **Files:** Any engine or rendering files that need fixes
- **LOC:** ~100 (estimated fixes)
- **Dependencies:** Phase 4 complete
- **Parallel:** No
- **Instructions for coder:**
  1. Set up the plugin with Tom's vault: `require("bases").setup({ vault_path = "~/Documents/Vaults/Personal" })`
  2. Test each of Tom's 5 base files:
     - `8 - Bases/weekly-overview.base` — should render a table with date column, formatted as "ddd"
     - `8 - Bases/habits.base` — should render with 5 boolean formula columns, summary row with Checked count
     - `8 - Bases/open-tasks.base` — should render with file.asLink() and file.mtime.relative() formulas
     - `8 - Bases/energy-trend.base` — should render with groupBy month DESC, Average summary
     - Inline blocks in weekly notes — should render as virtual lines below code blocks
  3. Fix any issues found:
     - Expression evaluation errors → fix in engine files
     - Rendering glitches → fix in render.lua
     - Encoding issues → fix in compat.lua or render.lua
  4. Ensure all error states show helpful messages (not raw Lua errors)

- **Verification:** All 5 of Tom's base files render correctly. No uncaught Lua errors.

#### Task 5.2: README.md

- **Files:** `README.md`
- **LOC:** ~150
- **Dependencies:** Task 5.1 (need to know what actually works)
- **Parallel:** No (needs Task 5.1 results)
- **Instructions for coder:**
  Write a README with:
  1. Project title and one-line description
  2. Screenshot placeholder (` ```base``` ` block rendered as table)
  3. Features list
  4. Installation (lazy.nvim, packer, manual)
  5. Configuration (full config with defaults)
  6. Commands reference
  7. Limitations (v1 scope — read-only, no cell editing, no dashboard)
  8. Credits (miller3616/bases.nvim fork, GPL-3.0)
  9. License

- **Verification:** README renders correctly in GitHub markdown preview.

#### Phase 5 Verification

After all Phase 5 tasks complete, the verification agent should:
1. Re-run all tests (ensure fixes didn't break anything)
2. Verify README has no broken links or formatting issues
3. Final `:checkhealth bases` passes
4. Commit everything

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Upstream expression engine bugs** | High — incorrect query results | Medium | Fork gives us full control to fix. Tests catch regressions. |
| **YAML parser edge cases** | Medium — some .base files fail to parse | High | The custom YAML parser is a subset parser. Test against Tom's actual files. Fall back to error message, not crash. |
| **vim.uv availability** | High — note_index won't work | Low | Require Neovim >= 0.10 (vim.uv landed in 0.10). Documented in health check. |
| **Large vault performance** | Medium — slow initial index build | Medium | Lazy index build (only on first query). File watcher invalidates, doesn't rebuild. Can add async scanning in v2. |
| **Circular require chains** | High — Lua errors on load | Medium | Explicitly broken via serialize.lua extraction. Test require order. |
| **Unicode width calculation** | Low — misaligned columns | Medium | Use `vim.api.nvim_strwidth()` which handles Unicode correctly. |
| **Inline extmarks conflict** | Medium — clashes with render-markdown.nvim | Medium | Use a unique namespace. Test with render-markdown.nvim active. |
| **GPL-3.0 license compliance** | High — legal | Low | LICENSE file, attribution in README, fork headers in files. We're compliant as long as bases.nvim itself is GPL-3.0. |
| **`this.file` reference in inline blocks** | Medium — inline queries that reference the containing file won't resolve | High | Need to pass source file path to the query engine. Handled in engine.parse_inline(). |
| **Frontmatter with non-YAML content** | Low — parse failure | Medium | Gracefully skip files with unparseable frontmatter. Don't crash the index build. |

---

## DECISION NEEDED

### 1. Border style default: `rounded` vs `sharp`

The plan uses `rounded` (╭╮╰╯) as the default, matching the trend in modern Neovim plugins (telescope, noice, etc.). The original miller3616/bases.nvim uses sharp corners. **Confirm rounded is preferred.**

### 2. Synchronous vs async index build

The plan uses synchronous scanning (simpler, blocks briefly on first query). An async approach would use coroutines or `vim.uv` callbacks. **Confirm synchronous is acceptable for v1.** Tom's vault size will determine if this matters (~1000 notes = ~200ms scan, ~10000 notes = ~2s scan).

### 3. Test framework

The plan uses a minimal custom test harness (no dependencies). Alternatives: plenary.nvim (common but heavy), mini.test, busted. **Confirm minimal custom harness is acceptable.**

---

## Definition of Done (v1)

**v1 is shipped when:**

1. All 5 of Tom's base files render correctly:
   - [  ] `weekly-overview.base` — table with date().format("ddd"), date filter
   - [  ] `habits.base` — table with 5 boolean formulas, Checked summary
   - [  ] `open-tasks.base` — table with file.asLink(), file.mtime.relative()
   - [  ] `energy-trend.base` — table with groupBy month DESC, Average summary
   - [  ] Inline blocks in weekly notes — virtual lines below ` ```base``` ` blocks

2. Core functionality works:
   - [  ] `.base` files open as rendered tables (BufReadCmd)
   - [  ] Inline ` ```base``` ` blocks render as virtual lines in markdown files
   - [  ] `:BasesRender`, `:BasesRefresh`, `:BasesClear`, `:BasesToggle` commands work
   - [  ] `:checkhealth bases` passes all checks
   - [  ] File watcher invalidates index on vault changes

3. Quality:
   - [  ] No vim.fn.* or vim.tbl_* calls in expression engine files
   - [  ] No circular require dependencies
   - [  ] Graceful error handling (no uncaught Lua errors)
   - [  ] All tests pass
   - [  ] GPL-3.0 LICENSE present, fork attribution in all forked files

4. Documentation:
   - [  ] README with installation, config, commands, limitations
   - [  ] `:help bases.nvim` — stretch goal, skip for v1 if time-constrained

---

## Suggested AGENTS.md Updates

Once the project is scaffolded and the first phase is complete, create `~/dev/bases.nvim/AGENTS.md` with:

```markdown
# bases.nvim — Agent Context

## Project Structure
- `lua/bases/` — plugin source (init, render, buffer, inline, health, compat)
- `lua/bases/engine/` — forked engine from miller3616/bases.nvim
- `plugin/bases.lua` — ftdetect + lazy autocmd
- `tests/` — test harness + unit tests

## Key Conventions
- Engine files use `require("bases.compat")` instead of vim.* utilities
- Exception: note_index.lua and file_watcher.lua use vim.uv for filesystem (they only run in Neovim)
- All forked files have a header comment noting the fork origin
- No vim.fn.*, vim.tbl_*, vim.startswith, vim.endswith, vim.trim, vim.pesc, vim.deepcopy in engine/expr/* files

## Testing
- Run tests: `nvim --headless -u tests/init.lua -c "luafile tests/unit/test_X.lua" -c "qa"`
- Tests use a minimal custom harness (describe/it/assert_eq), not plenary or busted
- test_query.lua creates temp directories with mock markdown files — verify cleanup

## Known Gotchas
- Circular dependency between summaries and query_engine was broken by extracting serialize.lua
- YAML parser is a subset parser — doesn't handle all YAML spec (anchors, aliases, complex keys)
- Inline block detection uses simple regex — won't handle nested code fences correctly
- vault_path must be absolute (~ expansion happens in setup())

## Tom's Vault
- Path: ~/Documents/Vaults/Personal
- Base files in: 8 - Bases/
- Test with: weekly-overview.base, habits.base, open-tasks.base, energy-trend.base
```
