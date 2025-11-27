# Test Suite Documentation

This directory contains the test suite for aufzeichnung.nvim.

## Test Organization

### Unit Tests (`tests/unit/`)

Unit tests focus on testing individual modules in isolation:

- **`utils_spec.lua`** - Tests for data utility functions
  - SQL to chart/table conversions
  - Date formatting and manipulation
  - Text processing (truncation, cleaning)
  - UUID v7 generation
  - Productivity score calculations
  - Data aggregation and moving averages

- **`plot_spec.lua`** - Tests for visualization functions
  - Histogram generation
  - Pie charts (circular and bar-style)
  - Table rendering (with and without borders)
  - Line plots
  - Edge cases and data validation

- **`task_counter_spec.lua`** - Tests for markdown task counting
  - Setup and configuration
  - Task counting in headings
  - Nested task hierarchies
  - Multiple task patterns
  - Buffer lifecycle management

### Integration Tests (`tests/integration/`)

Integration tests verify that components work together correctly:

- **`task_tracking_spec.lua`** - End-to-end task tracking
  - Task creation and persistence
  - State transitions (CREATED → IN_PROGRESS → FINISHED)
  - Parent-child task relationships
  - Database operations
  - File save triggers
  - Error handling

- **`journal_spec.lua`** - Journal management workflow
  - Journal content generation
  - Section-based task organization
  - Finding most recent journals
  - Configuration respect

## Running Tests

### All Tests
```bash
make test
```

### Specific Test Suites
```bash
make test-unit          # Run only unit tests
make test-integration   # Run only integration tests
```

### Individual Test Files
```bash
make test-file FILE=tests/unit/utils_spec.lua
```

## Test Environment

Tests run in an isolated Neovim environment configured by `tests/minimal_init.lua`:

- No user configuration loaded
- Only essential plugins (plenary.nvim, sqlite.lua)
- Temporary directories for test data
- Minimal Neovim options

## Writing New Tests

### Basic Structure

```lua
-- tests/unit/my_module_spec.lua
local my_module = require('notes.my_module')

describe("my_module", function()
  describe("my_function", function()
    it("should do something specific", function()
      local result = my_module.my_function(input)
      assert.are.equal(expected, result)
    end)
    
    it("should handle edge cases", function()
      local result = my_module.my_function(nil)
      assert.is_nil(result)
    end)
  end)
end)
```

### Integration Test Pattern

```lua
-- tests/integration/my_feature_spec.lua
local notes = require('notes')

describe("My Feature Integration", function()
  local temp_dir
  
  before_each(function()
    -- Setup test environment
    temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")
    
    notes.setup({
      directories = { notebook = temp_dir },
      -- ... test config
    })
  end)
  
  after_each(function()
    -- Cleanup
    vim.fn.delete(temp_dir, "rf")
  end)
  
  it("should work end-to-end", function()
    -- Test implementation
  end)
end)
```

### Assertions

Common assertions from plenary.nvim:

```lua
assert.are.equal(expected, actual)
assert.are_not.equal(value1, value2)
assert.is_true(condition)
assert.is_false(condition)
assert.is_nil(value)
assert.is_not_nil(value)
assert.has_no.errors(function() ... end)
```

## Test Coverage

Current test coverage focuses on:

✅ **Core Utilities** (utils module)
- Data conversion and transformation
- Date/time operations
- Text processing
- UUID generation
- Mathematical calculations

✅ **Visualization** (plot module)
- All chart types
- Edge cases and error handling
- Configuration options

✅ **Task Counter** (task_counter module)
- Setup and configuration
- Task detection patterns
- Buffer operations

✅ **Task Tracking** (integration)
- Full task lifecycle
- Database persistence
- State management

✅ **Journal Management** (integration)
- Content generation
- Multi-section handling

## Continuous Integration

Tests run automatically via GitHub Actions on:
- Push to `main` or `develop`
- Pull requests
- Manual workflow dispatch

CI Matrix:
- **OS**: Ubuntu, macOS
- **Neovim**: stable, nightly

## Debugging Tests

### Verbose Output
```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/unit/utils_spec.lua"
```

### Interactive Debugging
```bash
nvim -u tests/minimal_init.lua
:PlenaryBustedFile tests/unit/utils_spec.lua
```

### Common Issues

1. **"plenary.nvim not found"**
   - Install plenary: `git clone https://github.com/nvim-lua/plenary.nvim ~/.local/share/nvim/lazy/plenary.nvim`

2. **"sqlite.lua not found"**
   - Install sqlite.lua: `git clone https://github.com/kkharji/sqlite.lua ~/.local/share/nvim/lazy/sqlite.lua`

3. **Database locked errors**
   - Clean temp files: `make clean`
   - Ensure no Neovim instances are running

4. **Async test failures**
   - Increase wait times in tests
   - Check for race conditions

## Best Practices

1. **Test Isolation**: Each test should be independent and not rely on other tests
2. **Cleanup**: Always cleanup resources in `after_each`
3. **Descriptive Names**: Use clear, descriptive test names
4. **Single Assertion**: Prefer one logical assertion per test (when practical)
5. **Edge Cases**: Test boundary conditions and error cases
6. **Documentation**: Add comments for complex test scenarios

## Contributing Tests

When adding features:

1. Write unit tests for new functions
2. Write integration tests for user-facing features
3. Ensure tests pass locally before pushing
4. Update this README if adding new test categories

## Performance

Test suite performance goals:
- Unit tests: < 5 seconds
- Integration tests: < 30 seconds
- Full suite: < 1 minute

If tests are slow, consider:
- Reducing wait times where safe
- Mocking expensive operations
- Parallelizing independent tests
