# aufzeichnung.nvim

A comprehensive note-taking and task tracking plugin for Neovim with advanced visualization and analytics capabilities.

## ✨ Features

- 📝 **Note Management** - Integrated with [zk-nvim](https://github.com/mickael-menu/zk-nvim) for powerful Zettelkasten-style note-taking
- ✅ **Task Tracking** - Track tasks across your notes with SQLite persistence
- 📊 **Visualizations** - ASCII charts, histograms, pie charts, line plots, and tables
- 📅 **Smart Journals** - Daily journals with automatic task carryover
- 🔄 **Task Counters** - Org-mode style progress counters for markdown headings
- 🎯 **Analytics** - Detailed productivity insights and trend analysis
- 🆔 **UUID v7 Support** - Time-ordered unique task identifiers

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/aufzeichnung.nvim",
  dependencies = {
    "mickael-menu/zk-nvim",        -- Note management
    "kkharji/sqlite.lua",          -- Task tracking database
  },
  config = function()
    require("notes").setup({
      -- Your configuration here
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/aufzeichnung.nvim",
  requires = {
    "mickael-menu/zk-nvim",
    "kkharji/sqlite.lua",
  },
  config = function()
    require("notes").setup({
      -- Your configuration here
    })
  end,
}
```

## ⚙️ Configuration

### Basic Setup

```lua
require("notes").setup({
  directories = {
    notebook = "~/notes",              -- Main notes directory
    personal_journal = "journal/daily", -- Personal daily journals
    work_journal = "work",              -- Work journals
    archive = "archive",                -- Archive directory
  },
  
  tracking = {
    personal = {
      enabled = true,
      filename_patterns = { "perso%-.*%.md$" },
    },
    work = {
      enabled = true,
      filename_patterns = { "work%-.*%.md$" },
    },
  },
  
  keymaps = {
    enabled = true,
    prefix = "<leader>n",
  },
})
```

### Full Configuration Options

<details>
<summary>Click to expand full configuration</summary>

```lua
require("notes").setup({
  -- 📁 Directory Configuration
  directories = {
    notebook = vim.env.ZK_NOTEBOOK_DIR or "~/notes",
    personal_journal = "journal/daily",
    work_journal = "work",
    archive = "archive",
  },
  
  -- 📊 Note Type Tracking Configuration
  tracking = {
    personal = {
      enabled = true,
      filename_patterns = { "perso%-.*%.md$" },
      database_path = nil, -- Auto: {notebook}/.perso-tasks.db
    },
    work = {
      enabled = true,
      filename_patterns = { "work%-.*%.md$" },
      database_path = nil, -- Auto: {notebook}/.work-tasks.db
    },
  },
  
  -- ⚙️ ZK-nvim Configuration
  zk = {
    enabled = true,
    picker = "minipick", -- or "fzf", "telescope"
  },
  
  -- 🎨 Visualization Configuration
  visualization = {
    enabled = true,
    charts = {
      histogram = { width = 50, show_values = true },
      pie_chart = { radius = 10, style = "solid", show_legend = true },
      line_plot = { width = 60, height = 15, show_axes = true },
      table = { show_borders = true, max_rows = 10 }
    },
    data = {
      date_format = "medium",  -- "short", "medium", "long", "relative"
      truncate_length = 30,
      productivity_weights = { created = 1, completed = 2, carried_over = -1 }
    },
    display = { use_emojis = true, show_debug = false }
  },
  
  -- 📝 Journal Configuration
  journal = {
    daily_template = {
      personal = {
        prefix = "perso",
        sections = {
          "What is my main goal for today?",
          "What else do I wanna do?",
          "What did I do today?"
        }
      },
      work = {
        prefix = "work",
        sections = {
          "What is my main goal for today?",
          "What else do I wanna do?",
          "What did I do today?"
        }
      }
    },
    carryover_enabled = true,
  },
  
  -- ⌨️ Keybinding Configuration
  keymaps = {
    enabled = true,
    prefix = "<leader>n",
    mappings = {
      -- Note creation
      new_note = "n",
      new_at_dir = "N",
      new_task = "T",
      new_child_task = "C",
      
      -- Journal creation
      daily_journal = "j",
      work_journal = "w",
      
      -- Note browsing
      open_notes = "o",
      find_notes = "f",
      browse_tags = "t",
      
      -- Dashboards
      dashboard = "d",
      work_dashboard = "dw",
      today = "dt",
      yesterday = "dy",
      weekly = "dW",
      last_week = "dl",
      friday_review = "df",
      quick_stats = "ds",
      
      -- Detailed visualization
      task_stats = "ts",
      task_completions = "tc",
      task_states = "tp",
      productivity_trend = "tt",
      recent_activity = "ta",
      work_stats = "tw",
    }
  },
  
  -- 🔔 Notification Configuration
  notifications = {
    enabled = true,
    task_operations = true,
    journal_carryover = true,
    database_operations = false,
    level = "info",
    duration = 3000,
    position = "top_right",
  },
  
  -- 🔧 Advanced Configuration
  advanced = {
    auto_create_directories = true,
    database_optimization = true,
    debug_mode = false,
  }
})
```

</details>

## 🚀 Usage

### Creating Notes and Tasks

- `<leader>nn` - Create a new note
- `<leader>nN` - Create a note in a specific directory
- `<leader>nT` - Create a new task (with UUID v7)
- `<leader>nC` - Create a child task

### Journals

- `<leader>nj` - Create/open today's personal journal
- `<leader>nw` - Create/open today's work journal

Journals automatically carry over unfinished tasks from the previous day.

### Browsing Notes

- `<leader>no` - Open notes
- `<leader>nf` - Find notes
- `<leader>nt` - Browse tags

### Dashboards & Analytics

- `<leader>nd` - Personal dashboard
- `<leader>ndw` - Work dashboard
- `<leader>ndt` - Today's overview
- `<leader>ndy` - Yesterday's activity
- `<leader>ndW` - Weekly overview
- `<leader>ndl` - Last week summary
- `<leader>ndf` - Friday review
- `<leader>nds` - Quick stats

### Task Statistics

- `<leader>nts` - Detailed task stats
- `<leader>ntc` - Completion history
- `<leader>ntp` - Task state pie chart
- `<leader>ntt` - Productivity trend
- `<leader>nta` - Recent activity log
- `<leader>ntw` - Work-specific stats

### Task Counters

The task counter module automatically shows progress for markdown headings:

```markdown
# My Project [3/10 30%]  ← Automatically added

- [x] Completed task
- [ ] Pending task
- [ ] Another task
```

**Commands:**
- `:MarkdownTaskCounterToggle` - Toggle task counters
- `:MarkdownTaskCounterRefresh` - Refresh counters

## 📊 Task Format

Tasks are tracked using markdown checkboxes with UUID identifiers:

```markdown
- [ ] My task description [ ](task://550e8400-e29b-41d4-a716-446655440000)
- [x] Completed task [ ](task://550e8400-e29b-41d4-a716-446655440001)
- [-] In progress task [ ](task://550e8400-e29b-41d4-a716-446655440002)
```

**Task states:**
- `[ ]` - Created
- `[-]` - In Progress
- `[x]` - Finished

**Parent-child tasks:**
```markdown
- [ ] Parent task [ ](task://parent-uuid)
  - [ ] Child task [ ](task://child-uuid?parent=parent-uuid)
```

## 🎨 Visualization Examples

### Histogram
```
Tasks Created
══════════════
Today        ████████████████████████ 24
Yesterday    ████████████████ 16
2 days ago   ████████ 8
```

### Pie Chart
```
Task States
═══════════
    ●●●●●
  ●●●●●●●●●
 ●●●●●●●●●●●
●●●●●●●●●●●●●
●●●●●●●●●●●●●
 ●●●●●●●●●●●
  ●●●●●●●●●
    ●●●●●

Legend:
● FINISHED - 45.5% (50)
◐ IN_PROGRESS - 27.3% (30)
◑ CREATED - 27.2% (30)
```

## 🔧 Requirements

- Neovim >= 0.9.0
- [zk-nvim](https://github.com/mickael-menu/zk-nvim) - Note management
- [sqlite.lua](https://github.com/kkharji/sqlite.lua) - Task database
- [zk](https://github.com/mickael-menu/zk) CLI tool

**Optional:**
- [mini.pick](https://github.com/echasnovski/mini.nvim) or [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for picker

## 🧪 Testing

This plugin includes a comprehensive test suite with both unit and integration tests.

### Prerequisites

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Required for running tests
- [sqlite.lua](https://github.com/kkharji/sqlite.lua) - Required for integration tests

### Running Tests

```bash
# Run all tests
make test

# Run only unit tests
make test-unit

# Run only integration tests
make test-integration

# Run a specific test file
make test-file FILE=tests/unit/utils_spec.lua

# Run linter
make lint

# Clean temporary test files
make clean
```

### Test Structure

```
tests/
├── unit/                      # Unit tests
│   ├── utils_spec.lua        # Tests for utils module
│   ├── plot_spec.lua         # Tests for plot module
│   └── task_counter_spec.lua # Tests for task counter
├── integration/               # Integration tests
│   ├── task_tracking_spec.lua # Task tracking tests
│   └── journal_spec.lua      # Journal management tests
├── fixtures/                  # Test fixtures and data
└── minimal_init.lua          # Minimal Neovim config for tests
```

### Writing Tests

Tests use [plenary.nvim's test harness](https://github.com/nvim-lua/plenary.nvim#plenarytest_harness). Example:

```lua
describe("my feature", function()
  it("should do something", function()
    local result = my_function()
    assert.are.equal(expected, result)
  end)
end)
```

### Continuous Integration

This project uses GitHub Actions for CI/CD. Tests run automatically on:
- Every push to `main` or `develop` branches
- Every pull request
- Multiple OS (Ubuntu, macOS) and Neovim versions (stable, nightly)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Make sure all tests pass (`make test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- Write tests for all new features
- Maintain existing test coverage
- Follow Lua style conventions (consider using [StyLua](https://github.com/JohnnyMorganz/StyLua))
- Update documentation for user-facing changes

## 📄 License

MIT License

## 🙏 Credits

Originally developed as part of [smpte11/nvim](https://github.com/smpte11/nvim) configuration.

## 📚 Documentation

For more detailed documentation, see the help files:
```vim
:help aufzeichnung
```
