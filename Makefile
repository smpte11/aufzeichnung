.PHONY: test test-unit test-integration test-all lint clean

# Default Neovim executable
NVIM ?= nvim

# Test directories
TEST_DIR := tests
UNIT_DIR := $(TEST_DIR)/unit
INTEGRATION_DIR := $(TEST_DIR)/integration

# Run all tests
test: test-unit test-integration

# Run only unit tests
test-unit:
	@echo "Running unit tests..."
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('$(UNIT_DIR)', { minimal_init = './tests/minimal_init.lua' })"

# Run only integration tests
test-integration:
	@echo "Running integration tests..."
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('$(INTEGRATION_DIR)', { minimal_init = './tests/minimal_init.lua' })"

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=path/to/test_spec.lua"; \
		exit 1; \
	fi
	@echo "Running $(FILE)..."
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua \
		-c "lua require('plenary.busted').run('$(FILE)')"

# Run all tests with coverage (if available)
test-all:
	@echo "Running all tests..."
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('$(TEST_DIR)', { minimal_init = './tests/minimal_init.lua' })"

# Lint Lua files with luacheck (if installed)
lint:
	@if command -v luacheck >/dev/null 2>&1; then \
		echo "Linting Lua files..."; \
		luacheck lua/ tests/ --globals vim; \
	else \
		echo "luacheck not installed, skipping lint"; \
	fi

# Clean temporary test files
clean:
	@echo "Cleaning temporary files..."
	@find . -name "*.db" -type f -delete
	@find . -name "*.db-shm" -type f -delete
	@find . -name "*.db-wal" -type f -delete
	@rm -rf /tmp/nvim-test-*

# Check dependencies
check-deps:
	@echo "Checking test dependencies..."
	@$(NVIM) --headless -c "lua local ok = pcall(require, 'plenary'); if not ok then error('plenary.nvim not found') end; vim.cmd('quit')" 2>&1 | grep -q "not found" && \
		echo "✗ plenary.nvim not installed" || echo "✓ plenary.nvim installed"
	@$(NVIM) --headless -c "lua local ok = pcall(require, 'sqlite'); if not ok then error('sqlite.lua not found') end; vim.cmd('quit')" 2>&1 | grep -q "not found" && \
		echo "✗ sqlite.lua not installed" || echo "✓ sqlite.lua installed"

# Help
help:
	@echo "Available targets:"
	@echo "  test              - Run all tests (unit + integration)"
	@echo "  test-unit         - Run only unit tests"
	@echo "  test-integration  - Run only integration tests"
	@echo "  test-file         - Run specific test file (FILE=path/to/test.lua)"
	@echo "  test-all          - Run all tests with full output"
	@echo "  check-deps        - Check if test dependencies are installed"
	@echo "  lint              - Run luacheck linter"
	@echo "  clean             - Clean temporary test files"
	@echo "  help              - Show this help message"
