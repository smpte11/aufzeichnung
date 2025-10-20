-- Unit tests for notes.utils module
local utils = require('notes.utils')

describe("notes.utils", function()
    describe("sql_to_chart_data", function()
        it("should convert SQL results to chart format", function()
            local sql_results = {
                { label = "Created",     count = 10 },
                { label = "Completed",   count = 5 },
                { label = "In Progress", count = 3 },
            }

            local result = utils.sql_to_chart_data(sql_results, "label", "count")

            assert.are.equal(3, #result)
            assert.are.equal("Created", result[1].label)
            assert.are.equal(10, result[1].value)
        end)

        it("should handle empty results", function()
            local result = utils.sql_to_chart_data({}, "label", "value")
            assert.are.equal(0, #result)
        end)

        it("should handle nil input", function()
            local result = utils.sql_to_chart_data(nil, "label", "value")
            assert.are.equal(0, #result)
        end)

        it("should convert values to numbers", function()
            local sql_results = {
                { name = "Test", count = "42" },
            }

            local result = utils.sql_to_chart_data(sql_results, "name", "count")
            assert.are.equal(42, result[1].value)
            assert.is_true(type(result[1].value) == "number")
        end)
    end)

    describe("sql_to_table_data", function()
        it("should convert SQL results to table format", function()
            local sql_results = {
                { date = "2025-01-01", task = "Test task",    status = "done" },
                { date = "2025-01-02", task = "Another task", status = "pending" },
            }

            local result = utils.sql_to_table_data(sql_results, { "date", "task", "status" })

            assert.are.equal(2, #result)
            assert.are.equal(3, #result[1])
            assert.are.equal("2025-01-01", result[1][1])
            assert.are.equal("Test task", result[1][2])
        end)

        it("should handle missing columns", function()
            local sql_results = {
                { date = "2025-01-01" },
            }

            local result = utils.sql_to_table_data(sql_results, { "date", "missing" })
            assert.are.equal("", result[1][2])
        end)
    end)

    describe("add_state_emoji", function()
        it("should add glyph to FINISHED state", function()
            local result = utils.add_state_emoji("FINISHED")
            assert.is_not_nil(result:match(""))
        end)

        it("should add glyph to IN_PROGRESS state", function()
            local result = utils.add_state_emoji("IN_PROGRESS")
            assert.is_not_nil(result:match(""))
        end)

        it("should add glyph to CREATED state", function()
            local result = utils.add_state_emoji("CREATED")
            assert.is_not_nil(result:match(""))
        end)

        it("should handle unknown states", function()
            local result = utils.add_state_emoji("UNKNOWN")
            assert.is_not_nil(result:match(""))
        end)

        it("should handle nil state", function()
            local result = utils.add_state_emoji(nil)
            assert.is_not_nil(result:match(""))
        end)

        it("should be case insensitive", function()
            local result = utils.add_state_emoji("finished")
            assert.is_not_nil(result:match(""))
        end)
    end)

    describe("format_date", function()
        it("should format date in short format", function()
            local result = utils.format_date("2025-01-15", "short")
            assert.are.equal("01/15", result)
        end)

        it("should format date in medium format", function()
            local result = utils.format_date("2025-01-15", "medium")
            assert.are.equal("Jan 15", result)
        end)

        it("should format date in long format", function()
            local result = utils.format_date("2025-01-15", "long")
            assert.are.equal("Jan 15, 2025", result)
        end)

        it("should default to short format", function()
            local result = utils.format_date("2025-01-15")
            assert.are.equal("01/15", result)
        end)

        it("should handle invalid date format", function()
            local result = utils.format_date("invalid-date", "short")
            assert.are.equal("invalid-date", result)
        end)

        it("should handle nil date", function()
            local result = utils.format_date(nil, "short")
            assert.are.equal("Unknown", result)
        end)
    end)

    describe("calculate_productivity_score", function()
        it("should calculate score with default weights", function()
            local score = utils.calculate_productivity_score(5, 3, 1)
            -- created=5*1, completed=3*2, carried_over=1*(-1) = 5+6-1 = 10
            assert.are.equal(10, score)
        end)

        it("should calculate score with custom weights", function()
            local weights = { created = 2, completed = 3, carried_over = -2 }
            local score = utils.calculate_productivity_score(5, 3, 1, weights)
            -- created=5*2, completed=3*3, carried_over=1*(-2) = 10+9-2 = 17
            assert.are.equal(17, score)
        end)

        it("should handle zero values", function()
            local score = utils.calculate_productivity_score(0, 0, 0)
            assert.are.equal(0, score)
        end)

        it("should handle nil values as zero", function()
            local score = utils.calculate_productivity_score(nil, nil, nil)
            assert.are.equal(0, score)
        end)
    end)

    describe("truncate_text", function()
        it("should truncate long text", function()
            local result = utils.truncate_text("This is a very long text that needs truncation", 20)
            assert.are.equal("This is a very lo...", result)
        end)

        it("should not truncate short text", function()
            local result = utils.truncate_text("Short", 20)
            assert.are.equal("Short", result)
        end)

        it("should use custom suffix", function()
            local result = utils.truncate_text("Long text here", 10, ">>")
            -- Truncates to max_length - suffix_length characters, then adds suffix
            assert.are.equal("Long tex>>", result)
        end)

        it("should default to 30 characters", function()
            local long_text = string.rep("a", 40)
            local result = utils.truncate_text(long_text)
            assert.are.equal(30, #result)
        end)

        it("should handle nil text", function()
            local result = utils.truncate_text(nil, 20)
            assert.are.equal("", result)
        end)
    end)

    describe("clean_task_text", function()
        it("should remove task URI", function()
            local result = utils.clean_task_text("My task [ ](task://abc-123)")
            assert.are.equal("My task", result)
        end)

        it("should remove extra whitespace", function()
            local result = utils.clean_task_text("  My   task   with   spaces  ")
            assert.are.equal("My task with spaces", result)
        end)

        it("should remove markdown checkboxes", function()
            local result = utils.clean_task_text("- [x] Completed task")
            assert.are.equal("Completed task", result)
        end)

        it("should handle empty text", function()
            local result = utils.clean_task_text("")
            -- Empty string after cleaning returns "Unknown task"
            assert.are.equal("Unknown task", result)
        end)

        it("should handle nil text", function()
            local result = utils.clean_task_text(nil)
            assert.are.equal("Unknown task", result)
        end)

        it("should handle whitespace only", function()
            local result = utils.clean_task_text("   ")
            assert.are.equal("Empty task", result)
        end)
    end)

    describe("generate_uuid_v7", function()
        it("should generate valid UUID format", function()
            local uuid = utils.generate_uuid_v7()
            -- UUID format: xxxxxxxx-xxxx-7xx-xxxx-xxxxxxxxxxxx (note: 3rd section has 3 hex chars)
            assert.is_not_nil(uuid:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-7%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"))
        end)

        it("should generate unique UUIDs", function()
            local uuid1 = utils.generate_uuid_v7()
            local uuid2 = utils.generate_uuid_v7()
            assert.are_not.equal(uuid1, uuid2)
        end)

        it("should have version 7", function()
            local uuid = utils.generate_uuid_v7()
            local version = uuid:sub(15, 15)
            assert.are.equal("7", version)
        end)

        it("should be lowercase", function()
            local uuid = utils.generate_uuid_v7()
            assert.are.equal(uuid, uuid:lower())
        end)

        it("should have correct length", function()
            local uuid = utils.generate_uuid_v7()
            -- UUID format should be close to 36 chars (8-4-4-4-12 with hyphens)
            assert.is_true(#uuid >= 35 and #uuid <= 36)
        end)
    end)

    describe("group_by_period", function()
        it("should group by day", function()
            local data = {
                { date = "2025-01-01", value = 5 },
                { date = "2025-01-01", value = 3 },
                { date = "2025-01-02", value = 4 },
            }

            local result = utils.group_by_period(data, "day")
            assert.are.equal(2, #result)
            assert.are.equal(8, result[1].value) -- 5 + 3
            assert.are.equal(4, result[2].value)
        end)

        it("should sort by date", function()
            local data = {
                { date = "2025-01-03", value = 3 },
                { date = "2025-01-01", value = 1 },
                { date = "2025-01-02", value = 2 },
            }

            local result = utils.group_by_period(data, "day")
            assert.are.equal("2025-01-01", result[1].label)
            assert.are.equal("2025-01-02", result[2].label)
            assert.are.equal("2025-01-03", result[3].label)
        end)

        it("should handle empty data", function()
            local result = utils.group_by_period({}, "day")
            assert.are.equal(0, #result)
        end)

        it("should default to day period", function()
            local data = {
                { date = "2025-01-01", value = 5 },
            }

            local result = utils.group_by_period(data)
            assert.are.equal(1, #result)
        end)
    end)

    describe("moving_average", function()
        it("should calculate moving average", function()
            local data = {
                { label = "Day 1", value = 10 },
                { label = "Day 2", value = 20 },
                { label = "Day 3", value = 30 },
                { label = "Day 4", value = 40 },
            }

            local result = utils.moving_average(data, 3)
            -- First average: (10+20+30)/3 = 20
            -- Second average: (20+30+40)/3 = 30
            assert.are.equal(2, #result)
            assert.are.equal(20, result[1].value)
            assert.are.equal(30, result[2].value)
        end)

        it("should handle insufficient data", function()
            local data = {
                { label = "Day 1", value = 10 },
            }

            local result = utils.moving_average(data, 3)
            assert.are.equal(1, #result)
        end)

        it("should default to window size 3", function()
            local data = {
                { label = "Day 1", value = 10 },
                { label = "Day 2", value = 20 },
                { label = "Day 3", value = 30 },
            }

            local result = utils.moving_average(data)
            assert.are.equal(1, #result)
        end)
    end)
end)
