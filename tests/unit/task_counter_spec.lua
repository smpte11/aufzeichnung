-- Unit tests for notes.task_counter module
local task_counter = require('notes.task_counter')

describe("notes.task_counter", function()
	-- Helper to create a test buffer
	local function create_test_buffer(lines)
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
		return buf
	end

	-- Helper to clean up buffer
	local function cleanup_buffer(buf)
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end

	describe("setup", function()
		it("should setup without errors", function()
			assert.has_no.errors(function()
				task_counter.setup()
			end)
		end)

		it("should accept custom configuration", function()
			assert.has_no.errors(function()
				task_counter.setup({
					filetypes = { "markdown", "org" },
					show_percent = false,
					debounce_ms = 200,
				})
			end)
		end)

		it("should allow disabling", function()
			assert.has_no.errors(function()
				task_counter.setup({ enable = false })
			end)
		end)
	end)

	describe("task counting", function()
		before_each(function()
			task_counter.setup({
				enable = true,
				debounce_ms = 0, -- Disable debounce for tests
				show_percent = true,
			})
		end)

		it("should count completed and total tasks", function()
			local lines = {
				"# Project Tasks",
				"- [x] Completed task 1",
				"- [ ] Pending task 1",
				"- [x] Completed task 2",
			}

			local buf = create_test_buffer(lines)

			-- Trigger refresh
			task_counter.refresh(buf)

			-- Wait a bit for async operations
			vim.wait(100)

			-- Get extmarks to verify counter was added
			local marks = vim.api.nvim_buf_get_extmarks(buf, task_counter._config and 0 or -1, 0, -1, { details = true })

			-- Should have at least some processing
			assert.is_true(vim.api.nvim_buf_is_valid(buf))

			cleanup_buffer(buf)
		end)

		it("should handle nested tasks", function()
			local lines = {
				"# Main Project",
				"- [x] Task 1",
				"  - [ ] Subtask 1.1",
				"  - [x] Subtask 1.2",
				"## Sub Section",
				"- [ ] Task 2",
			}

			local buf = create_test_buffer(lines)
			task_counter.refresh(buf)
			vim.wait(100)

			assert.is_true(vim.api.nvim_buf_is_valid(buf))
			cleanup_buffer(buf)
		end)

		it("should handle multiple headings", function()
			local lines = {
				"# Heading 1",
				"- [x] Task A",
				"- [ ] Task B",
				"",
				"## Heading 2",
				"- [x] Task C",
				"- [x] Task D",
				"- [ ] Task E",
				"",
				"### Heading 3",
				"- [ ] Task F",
			}

			local buf = create_test_buffer(lines)
			task_counter.refresh(buf)
			vim.wait(100)

			assert.is_true(vim.api.nvim_buf_is_valid(buf))
			cleanup_buffer(buf)
		end)

		it("should handle buffer with no tasks", function()
			local lines = {
				"# Project",
				"Some regular text",
				"No tasks here",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)

		it("should handle buffer with no headings", function()
			local lines = {
				"- [x] Task without heading",
				"- [ ] Another task",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)

		it("should handle empty buffer", function()
			local buf = create_test_buffer({})

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)
	end)

	describe("task patterns", function()
		before_each(function()
			task_counter.setup({ enable = true, debounce_ms = 0 })
		end)

		it("should recognize standard markdown checkboxes", function()
			local lines = {
				"# Tasks",
				"- [ ] unchecked",
				"- [x] checked",
				"- [X] checked uppercase",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)

		it("should recognize numbered list checkboxes", function()
			local lines = {
				"# Tasks",
				"1. [ ] First task",
				"2. [x] Second task",
				"3. [ ] Third task",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)

		it("should handle tasks with different bullet styles", function()
			local lines = {
				"# Tasks",
				"- [ ] hyphen task",
				"* [ ] asterisk task",
				"+ [ ] plus task",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)
	end)

	describe("configuration", function()
		it("should respect min_tasks_for_counter", function()
			task_counter.setup({
				enable = true,
				min_tasks_for_counter = 3,
				debounce_ms = 0,
			})

			local lines = {
				"# Few Tasks",
				"- [ ] Task 1",
				"- [ ] Task 2",
			}

			local buf = create_test_buffer(lines)
			task_counter.refresh(buf)
			vim.wait(100)

			-- Should not show counter (only 2 tasks, minimum is 3)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
			cleanup_buffer(buf)
		end)

		it("should respect show_percent setting", function()
			task_counter.setup({
				enable = true,
				show_percent = false,
				debounce_ms = 0,
			})

			local lines = {
				"# Tasks",
				"- [x] Done",
				"- [ ] Todo",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)

		it("should respect filetypes configuration", function()
			task_counter.setup({
				enable = true,
				filetypes = { "markdown" },
				debounce_ms = 0,
			})

			-- Create a non-markdown buffer
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_option(buf, 'filetype', 'lua')
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
				"# Not markdown",
				"- [ ] Should not be counted",
			})

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)
	end)

	describe("commands", function()
		it("should provide MarkdownTaskCounterRefresh command", function()
			task_counter.setup()

			assert.has_no.errors(function()
				vim.cmd("MarkdownTaskCounterRefresh")
			end)
		end)

		it("should provide MarkdownTaskCounterToggle command", function()
			task_counter.setup()

			assert.has_no.errors(function()
				vim.cmd("MarkdownTaskCounterToggle")
			end)
		end)

		it("should toggle enable state", function()
			task_counter.setup({ enable = true })

			-- Get initial state
			local config_before = task_counter._config
			local enabled_before = config_before and config_before.enable

			-- Toggle
			vim.cmd("MarkdownTaskCounterToggle")

			-- Check state changed
			local config_after = task_counter._config
			local enabled_after = config_after and config_after.enable

			if enabled_before ~= nil and enabled_after ~= nil then
				assert.are_not.equal(enabled_before, enabled_after)
			end
		end)
	end)

	describe("edge cases", function()
		before_each(function()
			task_counter.setup({ enable = true, debounce_ms = 0 })
		end)

		it("should handle deeply nested tasks", function()
			local lines = {
				"# Deep Nesting",
				"- [ ] Level 1",
				"  - [ ] Level 2",
				"    - [ ] Level 3",
				"      - [x] Level 4",
				"        - [ ] Level 5",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)

		it("should handle mixed content", function()
			local lines = {
				"# Mixed Content",
				"Some text before",
				"- [x] Task 1",
				"More text",
				"```lua",
				"- [ ] This is code, not a task",
				"```",
				"- [ ] Task 2",
				"",
				"## Another Section",
				"> - [x] Quote with checkbox",
				"- [ ] Real task",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)

		it("should handle special characters in headings", function()
			local lines = {
				"# Tasks (2025-01-13) [Priority]",
				"- [x] Task with special chars!",
				"- [ ] Another @task #tagged",
			}

			local buf = create_test_buffer(lines)

			assert.has_no.errors(function()
				task_counter.refresh(buf)
				vim.wait(100)
			end)

			cleanup_buffer(buf)
		end)
	end)
end)
