-- Integration tests for journal management
local notes = require('notes')

describe("Journal Management Integration", function()
	local temp_dir
	local test_config

	before_each(function()
		-- Create temporary test directory
		temp_dir = vim.fn.tempname()
		vim.fn.mkdir(temp_dir, "p")
		vim.fn.mkdir(temp_dir .. "/journal", "p")
		vim.fn.mkdir(temp_dir .. "/work", "p")

		-- Setup notes module with test configuration
		test_config = {
			directories = {
				notebook = temp_dir,
				personal_journal = "journal",
				work_journal = "work",
			},
			tracking = {
				personal = {
					enabled = true,
					filename_patterns = { "perso%-.*%.md$" },
					database_path = temp_dir .. "/.personal-tasks.db",
				},
				work = {
					enabled = true,
					filename_patterns = { "work%-.*%.md$" },
					database_path = temp_dir .. "/.work-tasks.db",
				},
			},
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
							"Main tasks",
							"Meetings",
							"Notes"
						}
					}
				},
				carryover_enabled = true,
			},
			zk = {
				enabled = false,
			},
			keymaps = {
				enabled = false,
			},
			notifications = {
				enabled = false,
			},
			advanced = {
				auto_create_directories = true,
			},
		}

		notes.setup(test_config)
	end)

	after_each(function()
		-- Cleanup temp directory
		if temp_dir and vim.fn.isdirectory(temp_dir) == 1 then
			vim.fn.delete(temp_dir, "rf")
		end
	end)

	describe("journal content generation", function()
		it("should generate basic journal content", function()
			local target_dir = temp_dir .. "/journal"
			local content = notes._create_basic_journal_content("personal")

			assert.is_not_nil(content)
			assert.is_true(type(content) == "string")
			assert.is_true(content:match("## What is my main goal for today?") ~= nil)
		end)

		it("should generate work journal content", function()
			local content = notes._create_basic_journal_content("work")

			assert.is_not_nil(content)
			assert.is_true(content:match("## Main tasks") ~= nil)
			assert.is_true(content:match("## Meetings") ~= nil)
		end)

		it("should include all configured sections", function()
			local content = notes._create_basic_journal_content("personal")

			for _, section in ipairs(test_config.journal.daily_template.personal.sections) do
				assert.is_true(content:match(vim.pesc(section)) ~= nil, "Missing section: " .. section)
			end
		end)
	end)

	describe("task carryover", function()
		it("should not carry over completed tasks", function()
			local target_dir = temp_dir .. "/journal"
			local utils = require('notes.utils')
			local uuid = utils.generate_uuid_v7()

			-- Create previous journal with completed task
			local prev_date = os.date("%Y-%m-%d", os.time() - 86400)
			local prev_file = string.format("%s/perso-%s.md", target_dir, prev_date)

			local prev_content = {
				"---",
				"title: Previous Journal",
				"---",
				"",
				"## What is my main goal for today?",
				"",
				string.format("- [x] Completed task [ ](task://%s)", uuid),
				"",
				"## What else do I wanna do?",
				"",
				"## What did I do today?",
			}

			local file = io.open(prev_file, "w")
			file:write(table.concat(prev_content, "\n"))
			file:close()

			-- Generate new journal with carryover
			local content = notes._create_journal_content_with_carryover(target_dir, "personal")

			-- Completed task should NOT be carried over
			assert.is_false(content:match(uuid) ~= nil)
		end)

		it("should carry over uncompleted tasks", function()
			local target_dir = temp_dir .. "/journal"
			local utils = require('notes.utils')
			local uuid = utils.generate_uuid_v7()

			-- Create previous journal with uncompleted task
			local prev_date = os.date("%Y-%m-%d", os.time() - 86400)
			local prev_file = string.format("%s/perso-%s.md", target_dir, prev_date)

			local prev_content = {
				"---",
				"title: Previous Journal",
				"---",
				"",
				"## What is my main goal for today?",
				"",
				string.format("- [ ] Uncompleted task [ ](task://%s)", uuid),
				"",
				"## What else do I wanna do?",
				"",
				"## What did I do today?",
			}

			local file = io.open(prev_file, "w")
			file:write(table.concat(prev_content, "\n"))
			file:close()

			-- Generate new journal with carryover
			local content = notes._create_journal_content_with_carryover(target_dir, "personal")

			-- Uncompleted task SHOULD be carried over
			assert.is_true(content:match(uuid) ~= nil)
		end)

		it("should carry over in-progress tasks", function()
			local target_dir = temp_dir .. "/journal"
			local utils = require('notes.utils')
			local uuid = utils.generate_uuid_v7()

			-- Create previous journal with in-progress task
			local prev_date = os.date("%Y-%m-%d", os.time() - 86400)
			local prev_file = string.format("%s/perso-%s.md", target_dir, prev_date)

			local prev_content = {
				"---",
				"title: Previous Journal",
				"---",
				"",
				"## What is my main goal for today?",
				"",
				string.format("- [-] In progress task [ ](task://%s)", uuid),
				"",
				"## What else do I wanna do?",
				"",
				"## What did I do today?",
			}

			local file = io.open(prev_file, "w")
			file:write(table.concat(prev_content, "\n"))
			file:close()

			-- Generate new journal with carryover
			local content = notes._create_journal_content_with_carryover(target_dir, "personal")

			-- In-progress task SHOULD be carried over
			assert.is_true(content:match(uuid) ~= nil)
		end)

		it("should handle journal with no previous entry", function()
			local target_dir = temp_dir .. "/journal"

			-- No previous journal exists
			local content = notes._create_journal_content_with_carryover(target_dir, "personal")

			assert.is_not_nil(content)
			assert.is_true(type(content) == "string")
		end)

		it("should preserve task order from sections", function()
			local target_dir = temp_dir .. "/journal"
			local utils = require('notes.utils')
			local uuid1 = utils.generate_uuid_v7()
			local uuid2 = utils.generate_uuid_v7()

			-- Create previous journal with tasks in different sections
			local prev_date = os.date("%Y-%m-%d", os.time() - 86400)
			local prev_file = string.format("%s/perso-%s.md", target_dir, prev_date)

			local prev_content = {
				"---",
				"title: Previous Journal",
				"---",
				"",
				"## What is my main goal for today?",
				"",
				string.format("- [ ] Task 1 [ ](task://%s)", uuid1),
				"",
				"## What else do I wanna do?",
				"",
				string.format("- [ ] Task 2 [ ](task://%s)", uuid2),
				"",
				"## What did I do today?",
			}

			local file = io.open(prev_file, "w")
			file:write(table.concat(prev_content, "\n"))
			file:close()

			-- Generate new journal with carryover
			local content = notes._create_journal_content_with_carryover(target_dir, "personal")

			-- Both tasks should be present
			assert.is_true(content:match(uuid1) ~= nil)
			assert.is_true(content:match(uuid2) ~= nil)

			-- Tasks should be in their respective sections
			local goal_section_start = content:find("## What is my main goal for today?")
			local else_section_start = content:find("## What else do I wanna do?")
			local uuid1_pos = content:find(uuid1)
			local uuid2_pos = content:find(uuid2)

			-- Task 1 should be in goal section (between goal and else)
			assert.is_true(uuid1_pos > goal_section_start and uuid1_pos < else_section_start)

			-- Task 2 should be in else section (after else)
			assert.is_true(uuid2_pos > else_section_start)
		end)
	end)

	describe("journal helpers", function()
		it("should find most recent journal", function()
			local target_dir = temp_dir .. "/journal"
			local helpers = notes._create_journal_helpers()

			-- Create some journal files
			local dates = {
				os.date("%Y-%m-%d", os.time() - 86400 * 3), -- 3 days ago
				os.date("%Y-%m-%d", os.time() - 86400 * 1), -- 1 day ago
				os.date("%Y-%m-%d", os.time() - 86400 * 2), -- 2 days ago
			}

			for _, date in ipairs(dates) do
				local filepath = string.format("%s/perso-%s.md", target_dir, date)
				local file = io.open(filepath, "w")
				file:write("# Journal " .. date)
				file:close()
			end

			-- Find most recent
			local most_recent = helpers.get_most_recent_journal_note(target_dir, "perso")

			assert.is_not_nil(most_recent)
			-- Should be yesterday's journal (most recent)
			assert.is_true(most_recent:match(dates[2]) ~= nil)
		end)

		it("should return nil when no journals exist", function()
			local target_dir = temp_dir .. "/journal"
			local helpers = notes._create_journal_helpers()

			local result = helpers.get_most_recent_journal_note(target_dir, "perso")

			assert.is_nil(result)
		end)

		it("should extract unfinished tasks from section", function()
			local helpers = notes._create_journal_helpers()
			local utils = require('notes.utils')
			local uuid1 = utils.generate_uuid_v7()
			local uuid2 = utils.generate_uuid_v7()
			local uuid3 = utils.generate_uuid_v7()

			local content = string.format([[
## Test Section

- [x] Completed task [ ](task://%s)
- [ ] Uncompleted task [ ](task://%s)
- [-] In progress task [ ](task://%s)

## Another Section

- [ ] Different section task
]], uuid1, uuid2, uuid3)

			local tasks = helpers.extract_unfinished_tasks(content, "Test Section")

			-- Should have 2 unfinished tasks (uncompleted and in progress)
			assert.are.equal(2, #tasks)

			-- Should not include completed task
			assert.is_false(tasks[1]:match(uuid1) ~= nil)

			-- Should include uncompleted and in progress
			local has_uuid2 = false
			local has_uuid3 = false
			for _, task in ipairs(tasks) do
				if task:match(uuid2) then has_uuid2 = true end
				if task:match(uuid3) then has_uuid3 = true end
			end
			assert.is_true(has_uuid2)
			assert.is_true(has_uuid3)
		end)
	end)

	describe("configuration", function()
		it("should respect carryover_enabled setting", function()
			-- Disable carryover
			local config = notes.get_config()
			config.journal.carryover_enabled = false

			local target_dir = temp_dir .. "/journal"
			local utils = require('notes.utils')
			local uuid = utils.generate_uuid_v7()

			-- Create previous journal
			local prev_date = os.date("%Y-%m-%d", os.time() - 86400)
			local prev_file = string.format("%s/perso-%s.md", target_dir, prev_date)

			local file = io.open(prev_file, "w")
			file:write(string.format("## Goal\n- [ ] Task [ ](task://%s)", uuid))
			file:close()

			-- Generate new journal
			local content = notes._create_journal_content_with_carryover(target_dir, "personal")

			-- Task should NOT be carried over (carryover disabled)
			assert.is_false(content:match(uuid) ~= nil)

			-- Re-enable for other tests
			config.journal.carryover_enabled = true
		end)
	end)
end)
