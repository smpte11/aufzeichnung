-- Integration tests for task tracking functionality
local notes = require('notes')
local utils = require('notes.utils')

-- Helper: fetch number of events by type from the SQLite DB for assertions
local function fetch_events_by_type(db_path, event_type)
    local ok, sqlite = pcall(require, "sqlite")
    if not ok then
        error("sqlite.lua not available for tests")
    end
    local db = sqlite.new(db_path)
    if db.open then
        db:open()
    end
    local rows = db:eval([[SELECT COUNT(*) AS c FROM task_events WHERE event_type = ?]], { event_type })
    return (rows and rows[1] and rows[1].c) or 0
end
local utils = require('notes.utils')

-- Helper: fetch number of events by type from the SQLite DB for assertions
local function fetch_events_by_type(db_path, event_type)
    local ok, sqlite = pcall(require, "sqlite")
    if not ok then
        error("sqlite.lua not available for tests")
    end
    local db = sqlite.new(db_path)
    if db.open then
        db:open()
    end
    local rows = db:eval([[SELECT COUNT(*) AS c FROM task_events WHERE event_type = ?]], { event_type })
    return (rows and rows[1] and rows[1].c) or 0
end

describe("Task Tracking Integration", function()
    local temp_dir
    local test_config

    before_each(function()
        -- Create temporary test directory
        temp_dir = vim.fn.tempname()
        vim.fn.mkdir(temp_dir, "p")
        vim.fn.mkdir(temp_dir .. "/journal", "p")

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
                    filename_patterns = { "test%-.*%.md$" },
                    database_path = temp_dir .. "/.test-tasks.db",
                },
            },
            zk = {
                enabled = false, -- Disable zk for tests
            },
            keymaps = {
                enabled = false, -- Disable keymaps for tests
            },
            notifications = {
                enabled = false, -- Disable notifications for tests
            },
            advanced = {
                auto_create_directories = true,
                database_optimization = false,
                debug_mode = false,
            },
        }

        notes.setup(test_config)
    end)

    after_each(function()
        -- Cleanup temp directory
        if temp_dir and vim.fn.isdirectory(temp_dir) == 1 then
            -- Force close any open database connections
            vim.cmd("sleep 100m")
            vim.fn.delete(temp_dir, "rf")
        end
    end)

    describe("task creation and tracking", function()
        it("should update on URI parent change", function()
            local filepath = temp_dir .. "/test-note.md"
            local parent1 = utils.generate_uuid_v7()
            local parent2 = utils.generate_uuid_v7()
            local child = utils.generate_uuid_v7()

            local content = {
                "# Test Note",
                "",
                string.format("- [ ] Parent 1 [ ](task://%s)", parent1),
                string.format("  - [ ] Child [ ](task://%s?parent=%s)", child, parent1),
            }
            local f = io.open(filepath, "w"); f:write(table.concat(content, "\n")); f:close()

            vim.cmd("edit " .. filepath)
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd("write")
            vim.wait(200)

            -- Change child's parent in URI (should emit task_updated)
            vim.api.nvim_buf_set_lines(buf, 4, 5, false, {
                string.format("  - [ ] Child [ ](task://%s?parent=%s)", child, parent2),
            })
            vim.cmd("write")
            vim.wait(200)

            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))
            -- Assert DB has at least one task_updated due to parent change
            local updated = fetch_events_by_type(db_path, "task_updated")
            assert.is_true(updated >= 1)

            vim.api.nvim_buf_delete(buf, { force = true })
        end)
        it("should track new tasks in markdown file", function()
            -- Create a test markdown file
            local filepath = temp_dir .. "/test-note.md"
            local uuid = require('notes.utils').generate_uuid_v7()
            local task_content = {
                "# Test Note",
                "",
                string.format("- [ ] Test task [ ](task://%s)", uuid),
            }

            -- Write file
            local file = io.open(filepath, "w")
            file:write(table.concat(task_content, "\n"))
            file:close()

            -- Open in buffer and trigger save
            vim.cmd("edit " .. filepath)
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd("write")

            -- Wait for async processing
            vim.wait(200)

            -- Verify database was created
            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))
            -- Assert only creation event; no updates/state/completion/reopen on initial save
            local created = fetch_events_by_type(db_path, "task_created")
            local updated = fetch_events_by_type(db_path, "task_updated")
            local state_changed = fetch_events_by_type(db_path, "task_state_changed")
            local completed = fetch_events_by_type(db_path, "task_completed")
            local reopened = fetch_events_by_type(db_path, "task_reopened")
            assert.is_true(created >= 1)
            assert.are.equal(0, updated)
            assert.are.equal(0, state_changed)
            assert.are.equal(0, completed)
            assert.are.equal(0, reopened)

            -- Clean up buffer
            vim.api.nvim_buf_delete(buf, { force = true })
        end)

        it("should track content change, completion, reopen, and state changes", function()
            local filepath = temp_dir .. "/test-note.md"
            local uuid = utils.generate_uuid_v7()

            -- Create initial task (CREATED)
            local task_content = {
                "# Test Note",
                "",
                string.format("- [ ] Test task [ ](task://%s)", uuid),
            }
            local file = io.open(filepath, "w"); file:write(table.concat(task_content, "\n")); file:close()

            -- Open and initial save
            vim.cmd("edit " .. filepath)
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd("write")
            vim.wait(200)

            -- Content change (should emit task_updated)
            vim.api.nvim_buf_set_lines(buf, 2, 3, false, {
                string.format("- [ ] Test task UPDATED [ ](task://%s)", uuid)
            })
            vim.cmd("write")
            vim.wait(200)

            -- State change to IN_PROGRESS (should emit task_state_changed)
            vim.api.nvim_buf_set_lines(buf, 2, 3, false, {
                string.format("- [-] Test task UPDATED [ ](task://%s)", uuid)
            })
            vim.cmd("write")
            vim.wait(200)

            -- Completion (should emit task_completed)
            vim.api.nvim_buf_set_lines(buf, 2, 3, false, {
                string.format("- [x] Test task UPDATED [ ](task://%s)", uuid)
            })
            vim.cmd("write")
            vim.wait(200)

            -- Reopen (should emit task_reopened)
            vim.api.nvim_buf_set_lines(buf, 2, 3, false, {
                string.format("- [ ] Test task UPDATED [ ](task://%s)", uuid)
            })
            vim.cmd("write")
            vim.wait(200)

            -- Database should exist at least
            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(buf, { force = true })
        end)

        it("should track multiple tasks in same file", function()
            local filepath = temp_dir .. "/test-note.md"
            local utils = require('notes.utils')
            local uuid1 = utils.generate_uuid_v7()
            local uuid2 = utils.generate_uuid_v7()
            local uuid3 = utils.generate_uuid_v7()

            local task_content = {
                "# Test Note",
                "",
                string.format("- [ ] Task 1 [ ](task://%s)", uuid1),
                string.format("- [x] Task 2 [ ](task://%s)", uuid2),
                string.format("- [-] Task 3 [ ](task://%s)", uuid3),
            }

            local file = io.open(filepath, "w")
            file:write(table.concat(task_content, "\n"))
            file:close()

            vim.cmd("edit " .. filepath)
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd("write")
            vim.wait(200)

            -- Verify database exists
            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(buf, { force = true })
        end)

        it("should handle parent-child task relationships", function()
            local filepath = temp_dir .. "/test-note.md"
            local utils = require('notes.utils')
            local parent_uuid = utils.generate_uuid_v7()
            local child_uuid = utils.generate_uuid_v7()

            local task_content = {
                "# Test Note",
                "",
                string.format("- [ ] Parent task [ ](task://%s)", parent_uuid),
                string.format("  - [ ] Child task [ ](task://%s?parent=%s)", child_uuid, parent_uuid),
            }

            local file = io.open(filepath, "w")
            file:write(table.concat(task_content, "\n"))
            file:close()

            vim.cmd("edit " .. filepath)
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd("write")
            vim.wait(200)

            -- Verify database exists
            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end)

    describe("task state management", function()
        it("should recognize CREATED state", function()
            local filepath = temp_dir .. "/test-note.md"
            local uuid = require('notes.utils').generate_uuid_v7()

            local task_content = {
                "# Tasks",
                string.format("- [ ] New task [ ](task://%s)", uuid),
            }

            local file = io.open(filepath, "w")
            file:write(table.concat(task_content, "\n"))
            file:close()

            vim.cmd("edit " .. filepath)
            vim.cmd("write")
            vim.wait(200)

            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(0, { force = true })
        end)

        it("should recognize IN_PROGRESS state", function()
            local filepath = temp_dir .. "/test-note.md"
            local uuid = require('notes.utils').generate_uuid_v7()

            local task_content = {
                "# Tasks",
                string.format("- [-] In progress task [ ](task://%s)", uuid),
            }

            local file = io.open(filepath, "w")
            file:write(table.concat(task_content, "\n"))
            file:close()

            vim.cmd("edit " .. filepath)
            vim.cmd("write")
            vim.wait(200)

            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(0, { force = true })
        end)

        it("should recognize FINISHED state", function()
            local filepath = temp_dir .. "/test-note.md"
            local uuid = require('notes.utils').generate_uuid_v7()

            local task_content = {
                "# Tasks",
                string.format("- [x] Completed task [ ](task://%s)", uuid),
            }

            local file = io.open(filepath, "w")
            file:write(table.concat(task_content, "\n"))
            file:close()

            vim.cmd("edit " .. filepath)
            vim.cmd("write")
            vim.wait(200)

            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(0, { force = true })
        end)
    end)

    describe("database operations", function()
        it("should not emit events on no-op save", function()
            local filepath = temp_dir .. "/test-note.md"
            local uuid = utils.generate_uuid_v7()

            -- Create initial task
            local task_content = {
                "# Test",
                string.format("- [ ] Task A [ ](task://%s)", uuid),
            }
            local f = io.open(filepath, "w"); f:write(table.concat(task_content, "\n")); f:close()

            -- Open and save
            vim.cmd("edit " .. filepath)
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd("write")
            vim.wait(200)
            local db_path = test_config.tracking.personal.database_path
            -- Capture event counts before no-op save
            local updated_before = fetch_events_by_type(db_path, "task_updated")
            local state_changed_before = fetch_events_by_type(db_path, "task_state_changed")
            local completed_before = fetch_events_by_type(db_path, "task_completed")
            local reopened_before = fetch_events_by_type(db_path, "task_reopened")

            -- Save again without changes (no-op)
            vim.cmd("write")
            vim.wait(200)
            -- Assert no new events were emitted
            local updated_after = fetch_events_by_type(db_path, "task_updated")
            local state_changed_after = fetch_events_by_type(db_path, "task_state_changed")
            local completed_after = fetch_events_by_type(db_path, "task_completed")
            local reopened_after = fetch_events_by_type(db_path, "task_reopened")
            assert.are.equal(updated_before, updated_after)
            assert.are.equal(state_changed_before, state_changed_after)
            assert.are.equal(completed_before, completed_after)
            assert.are.equal(reopened_before, reopened_after)

            -- Database should exist; no error thrown. We rely on absence of notifications in CI config.
            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(buf, { force = true })
        end)
        it("should create database on first save", function()
            local db_path = test_config.tracking.personal.database_path

            -- Database should not exist yet
            assert.are.equal(0, vim.fn.filereadable(db_path))

            -- Create and save a file with a task
            local filepath = temp_dir .. "/test-note.md"
            local uuid = require('notes.utils').generate_uuid_v7()

            local file = io.open(filepath, "w")
            file:write(string.format("# Test\n- [ ] Task [ ](task://%s)", uuid))
            file:close()

            vim.cmd("edit " .. filepath)
            vim.cmd("write")
            vim.wait(200)

            -- Database should now exist
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(0, { force = true })
        end)

        it("should persist data across multiple saves", function()
            local filepath = temp_dir .. "/test-note.md"
            local uuid = require('notes.utils').generate_uuid_v7()

            -- First save
            local file = io.open(filepath, "w")
            file:write(string.format("# Test\n- [ ] Task [ ](task://%s)", uuid))
            file:close()

            vim.cmd("edit " .. filepath)
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd("write")
            vim.wait(200)

            -- Second save with update
            vim.api.nvim_buf_set_lines(buf, 1, 2, false, {
                string.format("- [x] Task [ ](task://%s)", uuid)
            })
            vim.cmd("write")
            vim.wait(200)

            -- Database should still exist
            local db_path = test_config.tracking.personal.database_path
            assert.are.equal(1, vim.fn.filereadable(db_path))

            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end)

    describe("error handling", function()
        it("should handle malformed task URIs gracefully", function()
            local filepath = temp_dir .. "/test-note.md"

            local task_content = {
                "# Test",
                "- [ ] Malformed task [ ](task://invalid uuid format)",
            }

            local file = io.open(filepath, "w")
            file:write(table.concat(task_content, "\n"))
            file:close()

            assert.has_no.errors(function()
                vim.cmd("edit " .. filepath)
                vim.cmd("write")
                vim.wait(200)
            end)

            vim.api.nvim_buf_delete(0, { force = true })
        end)

        it("should handle tasks without URIs", function()
            local filepath = temp_dir .. "/test-note.md"

            local task_content = {
                "# Test",
                "- [ ] Task without URI",
            }

            local file = io.open(filepath, "w")
            file:write(table.concat(task_content, "\n"))
            file:close()

            assert.has_no.errors(function()
                vim.cmd("edit " .. filepath)
                vim.cmd("write")
                vim.wait(200)
            end)

            vim.api.nvim_buf_delete(0, { force = true })
        end)

        it("should handle empty files", function()
            local filepath = temp_dir .. "/test-note.md"

            local file = io.open(filepath, "w")
            file:write("")
            file:close()

            assert.has_no.errors(function()
                vim.cmd("edit " .. filepath)
                vim.cmd("write")
                vim.wait(200)
            end)

            vim.api.nvim_buf_delete(0, { force = true })
        end)
    end)
end)
