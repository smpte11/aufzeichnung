# aufzeichnung.nvim AI Coding Instructions

This is a **Neovim plugin for markdown task tracking with SQLite persistence and ASCII visualization**. The plugin works standalone or integrates with zk-nvim for advanced note management.

## Project Conventions

**Documentation:**
- README.md is the single source of truth - all user documentation goes there
- Only `.github/copilot-instructions.md` and `README.md` should exist as markdown files
- No additional documentation files in subdirectories

**Code Style:**
- Always comment your code - explain the "why", not just the "what"
- Write small, focused functions that do one thing well
- Be concise in implementation - favor clarity over cleverness
- Use descriptive variable names and function names

**Development Workflow:**
- Always show implementation plan before coding
- Confirm plan with user before proceeding
- When uncertain, ask for clarification rather than assuming

## Architecture Overview

**Core Modules:**
- `lua/notes/init.lua` - Main module (3200+ lines) containing setup, database operations, visualization dashboards, and keymaps
- `lua/notes/utils.lua` - Data conversion utilities, icon definitions, UUID generation, and formatting functions  
- `lua/notes/plot.lua` - Pure ASCII plotting functions (histograms, pie charts, line plots, tables)
- `lua/notes/task_counter.lua` - Org-mode style progress counters for markdown headings using virtual text
- `lua/notes/integrations/zk.lua` - Optional zk-nvim integration for note creation and browsing

**Plugin Structure:**
- Plugin entry point: `plugin/aufzeichnung.vim` (minimal Vimscript wrapper)
- Tests: `tests/` with unit tests (`tests/unit/`) and integration tests (`tests/integration/`)
- CI/CD: GitHub Actions workflow in `.github/workflows/test.yml`
- Build system: `Makefile` for testing, linting, and cleanup

## Key Technical Patterns

### Configuration System
```lua
-- Two-tier setup: standalone (task tracking only) vs full (with zk-nvim)
require("notes").setup({
  tracking = {
    personal = { filename_patterns = { "perso%-.*%.md$" } },
    work = { filename_patterns = { "work%-.*%.md$" } }
  },
  integrations = { zk = { enabled = "auto" } }  -- "auto" | true | false
})
```

### Task Format & Database Schema
Tasks use markdown checkboxes with UUID links:
```markdown
- [ ] Task description [ ](task://550e8400-e29b-41d4-a716-446655440000)
- [x] Completed [ ](task://uuid?parent=parent-uuid)  # Parent-child relationships
```

Database: SQLite with `task_events` table tracking `(task_id, event_type, timestamp, state, journal_file, parent_id)`

### Database Architecture
- **Per-tracking-type databases**: `.perso-tasks.db`, `.work-tasks.db` based on filename patterns
- **Connection caching**: `task_db_cache` with path validation to handle config changes
- **Async processing**: File save triggers `BufWritePost` → parse tasks → update database
- **Migrations**: `M._run_database_migrations()` handles schema evolution

### Visualization Pipeline
```lua
-- SQL → utils.sql_to_chart_data() → plot.histogram() → display
local data = utils.sql_to_chart_data(results, "label_col", "value_col")
local lines = plot.histogram(data, { title = "Daily Completions", width = 50 })
```

### Integration Pattern
```lua
-- Optional dependency loading with graceful fallback
local ok, zk = pcall(require, "zk")
if not ok then
  M.is_available = false
  return false  -- Core functionality continues without zk
end
```

## Development Workflows

### Testing
```bash
make test              # Run all tests
make test-unit         # Unit tests only  
make test-integration  # Integration tests only
make test-file FILE=tests/unit/utils_spec.lua  # Specific test
make clean            # Remove test artifacts
```

### Test Environment
- `tests/minimal_init.lua` - Minimal Neovim config for testing
- Temporary directories and databases for isolation
- plenary.nvim test harness with describe/it blocks
- CI runs on Ubuntu/macOS with stable/nightly Neovim

### Icon Customization
All Nerd Font icons centralized in `utils.lua` `M.icons` table:
```lua
M.icons = {
  check = "",     -- Task states
  folder = "",    -- UI elements
  plus = "",      -- Task events
}
```

## Critical Implementation Details

### Filename Pattern Matching
```lua
-- Lua patterns converted to glob patterns for autocmds
"perso%-.*%.md$" → "*/perso-*.md"  -- BufWritePost pattern conversion
```

### Task Parsing & State Management
```lua
-- Task URI parsing: "task://uuid" or "task://uuid?parent=parent-uuid"
function M._parse_task_uri(task_uri)
  -- Returns: uuid_part, parent_uuid
end
```

### Debounced Virtual Text Updates
Task counter module uses debounced refresh with `vim.defer_fn()` to avoid excessive recomputation on rapid buffer changes.

### Journal Carryover Logic
- Parse previous journal for unfinished tasks (`[ ]`, `[-]` states)
- Group by markdown sections 
- Generate new journal with carryover tasks
- Record carryover events in database for analytics

## Common Extension Points

- **New tracking types**: Add to `config.tracking` with filename patterns and database path
- **New visualizations**: Extend `plot.lua` with new chart types following existing data format
- **Custom task states**: Modify task parsing regex and state mapping in `M._track_tasks_on_save()`
- **Additional integrations**: Follow `integrations/zk.lua` pattern for optional dependencies

## Error Handling Patterns

- **Graceful degradation**: Missing dependencies disable features but don't break core functionality
- **Database errors**: Connection failures fall back to memory-only operation with notifications
- **File operations**: Use `pcall()` for file I/O with user-friendly error messages via `notify()`

Always check `is_setup` flag before major operations and validate database connections exist before SQL operations.