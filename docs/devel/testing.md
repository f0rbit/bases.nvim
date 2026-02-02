# Testing

This document describes the test suite for bases.nvim. The test suite uses mini.test from mini.nvim with no external dependencies beyond Neovim.

## Running Tests

### Requirements

- Neovim 0.11+
- git (for cloning mini.nvim)

### Commands

```bash
# First-time setup: clone mini.nvim into deps/
make deps

# Run all tests
make test

# Run only unit tests
make test-unit

# Run only integration tests
make test-integration

# Clean up dependencies
make clean
```

### Manual Execution

Tests can be run manually with Neovim:

```bash
# All tests
nvim --headless -u NONE -l tests/init.lua

# Subset (unit or integration)
nvim --headless -u NONE -l tests/run_subset.lua unit
nvim --headless -u NONE -l tests/run_subset.lua integration
```

## Test Architecture

### Framework

bases.nvim uses **mini.test** from mini.nvim. This framework provides:

- Test organization via `MiniTest.new_set()`
- Assertions via `MiniTest.expect` methods
- Test lifecycle hooks (pre_case, post_case)
- No external dependencies beyond Neovim

### Bootstrap

`tests/init.lua` bootstraps the test environment:

1. Adds `bases.nvim/` and `deps/mini.nvim` to runtimepath
2. Disables swap files (`vim.o.swapfile = false`)
3. Sets up mini.test
4. Discovers all `test_*.lua` files recursively
5. Runs the full test suite

### Selective Runner

`tests/run_subset.lua` accepts a command-line argument (`unit` or `integration`) to run a subset of tests. It uses the same bootstrap logic but limits file discovery to the specified subdirectory.

### Shared Helpers

`tests/helpers.lua` provides factory functions for creating test data:

```lua
local helpers = require('tests.helpers')

-- Create NoteData with defaults
local note = helpers.make_note_data({
  path = 'projects/alpha.md',
  frontmatter = { status = 'active', priority = 1 },
  tags = { 'project' },
})

-- Build mock NoteIndex with secondary indices
local index = helpers.make_note_index({ note1, note2 })

-- Create SerializedEntry
local entry = helpers.make_serialized_entry({
  file = { path = 'test.md', name = 'test.md', basename = 'test' },
  values = { ['note.status'] = { type = 'primitive', value = 'active' } },
})

-- Access fixture files
local content = helpers.read_fixture('vault/tasks.base')
local path = helpers.fixture_path('vault/projects/alpha.md')
```

## Directory Layout

```
bases.nvim/tests/
├── init.lua              # Bootstrap and full test runner
├── run_subset.lua        # Selective runner (unit/integration)
├── helpers.lua           # Shared factories and utilities
├── fixtures/
│   └── vault/            # Fixture vault for integration tests
│       ├── projects/     # alpha.md, beta.md, gamma.md
│       ├── people/       # alice.md, bob.md
│       ├── daily/        # 2025-01-15.md
│       └── tasks.base    # Sample base query file
├── unit/
│   ├── test_lexer.lua
│   ├── test_parser.lua
│   ├── test_types.lua
│   ├── test_yaml.lua
│   ├── test_base_parser.lua
│   ├── test_evaluator.lua
│   ├── test_functions.lua
│   ├── test_methods.lua
│   ├── test_render.lua
│   ├── test_display.lua
│   └── test_summaries.lua
└── integration/
    ├── test_query_engine.lua
    ├── test_frontmatter_editor.lua
    ├── test_buffer.lua
    ├── test_navigation.lua
    └── test_render_to_buffer.lua
```

## Unit vs Integration

### Unit Tests (`tests/unit/`)

Unit tests verify pure logic modules with no Neovim buffer state. They test isolated functions and data transformations.

**Characteristics:**

- No buffer or window creation
- No file I/O (except via helper fixtures)
- Fast execution (milliseconds per test)
- May use vim runtime utilities (vim.deepcopy, vim.startswith, etc.)

**Examples:**

- Lexer tokenization (`test_lexer.lua`)
- Parser AST generation (`test_parser.lua`)
- Type coercion and operations (`test_types.lua`)
- YAML parsing (`test_yaml.lua`)
- Expression evaluation (`test_evaluator.lua`)

### Integration Tests (`tests/integration/`)

Integration tests verify modules that interact with Neovim buffers, windows, or require multiple modules working together.

**Characteristics:**

- Create buffers and windows
- Test buffer-local variables and state
- Test module interactions
- Require cleanup via post_case hooks
- Slower execution (100ms+ per test)

**Examples:**

- Query engine execution (`test_query_engine.lua`)
- Frontmatter editing (`test_frontmatter_editor.lua`)
- Buffer creation and state (`test_buffer.lua`)
- Link navigation (`test_navigation.lua`)
- Table rendering to buffers (`test_render_to_buffer.lua`)

## Writing Tests

### File Naming

Test files must match the pattern `test_*.lua` to be discovered automatically. Use `test_<module>.lua` naming convention.

### Test Structure

```lua
local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local module = require('bases.module')

local T = new_set()

T['function_name'] = new_set()

T['function_name']['succeeds with valid input'] = function()
  local result = module.function_name('input')
  expect.equality(result, 'expected')
end

T['function_name']['returns error on invalid input'] = function()
  local result, err = module.function_name(nil)
  expect.equality(result, nil)
  expect.no_equality(err, nil)
end

return T
```

### Assertions

mini.test provides these assertion methods:

```lua
local expect = MiniTest.expect

-- Equality
expect.equality(actual, expected)
expect.no_equality(actual, unexpected)

-- Truthiness
expect.truthy(value)
expect.falsy(value)

-- Errors
expect.error(function() error('boom') end)
expect.no_error(function() return 'ok' end)
```

### Lifecycle Hooks

Use hooks for setup and cleanup:

```lua
local test_bufs = {}

local T = new_set({
  hooks = {
    pre_once = function()
      -- Run once before all tests in this set
    end,
    post_once = function()
      -- Run once after all tests in this set
    end,
    pre_case = function()
      -- Run before each test case
    end,
    post_case = function()
      -- Run after each test case (cleanup)
      for _, buf in ipairs(test_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      test_bufs = {}
    end,
  },
})
```

### Test Independence

Tests must be independent and not share mutable state:

- Clean up all created buffers/windows in post_case hooks
- Do not rely on test execution order
- Reset any global state between tests
- Use fresh data for each test (via helper factories)

## Mocking

### Mocking bases.get_config()

Modules that depend on the bases configuration need a mock:

```lua
-- Place this BEFORE requiring the module under test
package.loaded['bases'] = {
  get_config = function()
    return {
      date_format = '%Y-%m-%d',
      date_format_relative = false,
      vault_path = '/fake/vault',
    }
  end,
}

local module = require('bases.module')
```

### Mocking the Engine

For modules that query the engine:

```lua
local mock_engine_ready = true
local mock_query_result = { properties = {}, entries = {} }

package.loaded['bases.engine'] = {
  is_ready = function() return mock_engine_ready end,
  query = function(path, view_index, callback)
    vim.schedule(function()
      callback(nil, mock_query_result)
    end)
  end,
}
```

## Example: Unit Test

```lua
local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local lexer = require('bases.engine.expr.lexer')

local T = new_set()

T['tokenize'] = new_set()

T['tokenize']['integer literal'] = function()
  local tokens, err = lexer.tokenize('42')
  expect.equality(err, nil)
  expect.equality(tokens[1].type, lexer.NUMBER)
  expect.equality(tokens[1].value, 42)
  expect.equality(tokens[2].type, lexer.EOF)
end

T['tokenize']['returns error for unterminated string'] = function()
  local tokens, err = lexer.tokenize('"hello')
  expect.equality(tokens, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unterminated string', 1, true), nil)
end

return T
```

## Example: Integration Test with Cleanup

```lua
local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local buffer = require('bases.buffer')

local test_bufs = {}

local T = new_set({
  hooks = {
    post_case = function()
      for _, buf in ipairs(test_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      test_bufs = {}
    end,
  },
})

T['get_or_create'] = new_set()

T['get_or_create']['creates buffer with correct filetype'] = function()
  local buf = buffer.get_or_create('test.base')
  table.insert(test_bufs, buf)

  expect.equality(vim.api.nvim_buf_is_valid(buf), true)
  expect.equality(vim.bo[buf].filetype, 'bases')
  expect.equality(vim.bo[buf].buftype, 'nofile')
end

T['get_or_create']['reuses existing buffer'] = function()
  local buf1 = buffer.get_or_create('test.base')
  local buf2 = buffer.get_or_create('test.base')
  table.insert(test_bufs, buf1)

  expect.equality(buf1, buf2)
end

return T
```

## Example: Using Helpers

```lua
local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local query_engine = require('bases.engine.query_engine')
local base_parser = require('bases.engine.base_parser')
local helpers = require('tests.helpers')

-- Mock config
package.loaded['bases'] = {
  get_config = function()
    return { date_format = '%Y-%m-%d', date_format_relative = false }
  end,
}

local T = new_set()

T['execute'] = new_set()

T['execute']['filters by tag'] = function()
  -- Create test data using helpers
  local alpha = helpers.make_note_data({
    path = 'projects/alpha.md',
    frontmatter = { status = 'active' },
    tags = { 'project' },
  })
  local beta = helpers.make_note_data({
    path = 'people/beta.md',
    tags = { 'person' },
  })

  local index = helpers.make_note_index({ alpha, beta })

  -- Parse base config
  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: Projects
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  -- Execute query
  local result = query_engine.execute(config, index, 0, nil)

  -- Verify results
  expect.equality(#result.entries, 1)
  expect.equality(result.entries[1].file.basename, 'alpha')
end

return T
```

## CI Integration

Example GitHub Actions workflow:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: v0.11.0
      - run: make test
        working-directory: bases.nvim
```

For matrix testing across Neovim versions:

```yaml
strategy:
  matrix:
    neovim: [v0.11.0, nightly]
steps:
  - uses: rhysd/action-setup-vim@v1
    with:
      neovim: true
      version: ${{ matrix.neovim }}
```

## Module Coverage

| Module | Test File | Type |
|--------|-----------|------|
| engine/expr/lexer.lua | test_lexer.lua | Unit |
| engine/expr/parser.lua | test_parser.lua | Unit |
| engine/expr/types.lua | test_types.lua | Unit |
| engine/yaml.lua | test_yaml.lua | Unit |
| engine/base_parser.lua | test_base_parser.lua | Unit |
| engine/expr/evaluator.lua | test_evaluator.lua | Unit |
| engine/expr/functions.lua | test_functions.lua | Unit |
| engine/expr/methods.lua | test_methods.lua | Unit |
| render.lua | test_render.lua | Unit |
| display.lua | test_display.lua | Unit |
| engine/summaries.lua | test_summaries.lua | Unit |
| engine/query_engine.lua | test_query_engine.lua | Integration |
| engine/frontmatter_editor.lua | test_frontmatter_editor.lua | Integration |
| buffer.lua | test_buffer.lua | Integration |
| navigation.lua | test_navigation.lua | Integration |
| render.lua (buffer ops) | test_render_to_buffer.lua | Integration |

## Best Practices

### Test Naming

Use descriptive test names that explain the scenario:

```lua
-- Good
T['execute']['filters by tag and returns matching entries'] = function()

-- Less clear
T['execute']['test 1'] = function()
```

### Error Testing

Always test both success and failure paths:

```lua
T['parse']['succeeds with valid YAML'] = function()
  local result, err = parse('key: value')
  expect.equality(err, nil)
  expect.no_equality(result, nil)
end

T['parse']['returns error for invalid YAML'] = function()
  local result, err = parse('key: [unclosed')
  expect.equality(result, nil)
  expect.no_equality(err, nil)
  expect.no_equality(err:find('Unclosed', 1, true), nil)
end
```

### Boundary Testing

Test edge cases and boundary conditions:

```lua
T['sort']['handles empty list'] = function()
  local result = sort({})
  expect.equality(#result, 0)
end

T['sort']['handles single element'] = function()
  local result = sort({ 5 })
  expect.equality(#result, 1)
  expect.equality(result[1], 5)
end

T['sort']['handles duplicate values'] = function()
  local result = sort({ 3, 1, 3, 2, 1 })
  -- Verify stable sort or document behavior
end
```

### Data Validation

Verify data structure and types, not just values:

```lua
T['query']['returns valid SerializedResult structure'] = function()
  local result = query(config, index)

  -- Check structure
  expect.no_equality(result.properties, nil)
  expect.no_equality(result.entries, nil)
  expect.no_equality(result.views, nil)

  -- Check types
  expect.equality(type(result.properties), 'table')
  expect.equality(type(result.entries), 'table')

  -- Check nested structure
  for _, entry in ipairs(result.entries) do
    expect.no_equality(entry.file, nil)
    expect.no_equality(entry.values, nil)
    expect.equality(type(entry.file.path), 'string')
  end
end
```

### Fixture Management

Keep fixtures minimal and focused:

- Use helpers to generate data programmatically when possible
- Only use file fixtures for testing file I/O or complex parsing
- Document the purpose of each fixture file
- Clean up temporary fixtures in post_case hooks

### Performance Considerations

Tests should run quickly:

- Aim for <10ms per unit test
- Batch integration tests when possible
- Use smaller data sets (10-20 notes, not thousands)
- Profile slow tests and optimize or split them

## Debugging Tests

### Running a Single Test File

```bash
nvim --headless -u NONE -c "lua vim.opt.runtimepath:prepend('.')" \
  -c "lua vim.opt.runtimepath:prepend('deps/mini.nvim')" \
  -c "lua require('mini.test').run_file('tests/unit/test_lexer.lua')"
```

### Interactive Debugging

Run tests in a live Neovim session:

```vim
:lua vim.opt.runtimepath:prepend('deps/mini.nvim')
:lua require('mini.test').setup()
:lua MiniTest.run_file('tests/unit/test_lexer.lua')
```

### Print Debugging

Use `print()` or `vim.inspect()` in tests:

```lua
T['debug']['inspect values'] = function()
  local result = some_function()
  print('Result:', vim.inspect(result))
  expect.equality(result.status, 'active')
end
```

### Test Isolation

To verify test independence, run tests in random order or individually. Each test should pass regardless of execution order.

## See Also

- [Architecture](architecture.md) - System design and module interactions
- [API Reference](api.md) - Function signatures and return types
