-- Unit tests for notes.plot module
local plot = require('notes.plot')

describe("notes.plot", function()
	describe("histogram", function()
		it("should generate histogram for valid data", function()
			local data = {
				{ label = "Monday", value = 10 },
				{ label = "Tuesday", value = 20 },
				{ label = "Wednesday", value = 15 },
			}

			local result = plot.histogram(data, { title = "Daily Activity" })

			assert.is_true(#result > 0)
			assert.is_true(result[1]:match("Daily Activity") ~= nil)
		end)

		it("should handle empty data", function()
			local result = plot.histogram({})
			assert.are.equal(1, #result)
			assert.are.equal("No data to display", result[1])
		end)

		it("should handle nil data", function()
			local result = plot.histogram(nil)
			assert.are.equal(1, #result)
			assert.are.equal("No data to display", result[1])
		end)

		it("should respect width option", function()
			local data = {
				{ label = "Test", value = 100 },
			}

			local result = plot.histogram(data, { width = 20, title = nil })
			-- Find the bar line and check its approximate length
			local bar_line = result[1]
			assert.is_true(#bar_line <= 50) -- label + bar + value should be reasonable
		end)

		it("should show values when enabled", function()
			local data = {
				{ label = "Test", value = 42 },
			}

			local result = plot.histogram(data, { show_values = true, title = nil })
			local has_number = false
			for _, line in ipairs(result) do
				if line:match("42") then
					has_number = true
					break
				end
			end
			assert.is_true(has_number)
		end)

		it("should handle zero values", function()
			local data = {
				{ label = "Empty", value = 0 },
			}

			local result = plot.histogram(data)
			assert.are.equal(1, #result)
			assert.are.equal("No data to display", result[1])
		end)
	end)

	describe("pie_chart", function()
		it("should generate pie chart for valid data", function()
			local data = {
				{ label = "Completed", value = 50 },
				{ label = "Pending", value = 30 },
				{ label = "In Progress", value = 20 },
			}

			local result = plot.pie_chart(data, { title = "Task Distribution", radius = 5 })

			assert.is_true(#result > 0)
			assert.is_true(result[1]:match("Task Distribution") ~= nil)
		end)

		it("should handle empty data", function()
			local result = plot.pie_chart({})
			assert.are.equal(1, #result)
			assert.are.equal("No data to display", result[1])
		end)

		it("should include legend when requested", function()
			local data = {
				{ label = "Complete", value = 10 },
				{ label = "Incomplete", value = 5 },
			}

			local result = plot.pie_chart(data, { show_legend = true, title = "Status" })

			local has_legend = false
			for _, line in ipairs(result) do
				if line:match("Legend:") or line:match("Complete") then
					has_legend = true
					break
				end
			end
			assert.is_true(has_legend)
		end)

		it("should show percentages when enabled", function()
			local data = {
				{ label = "A", value = 50 },
				{ label = "B", value = 50 },
			}

			local result = plot.pie_chart(data, { show_percentages = true, show_legend = true })

			local has_percentage = false
			for _, line in ipairs(result) do
				if line:match("%%") then
					has_percentage = true
					break
				end
			end
			assert.is_true(has_percentage)
		end)

		it("should support different styles", function()
			local data = {
				{ label = "Test", value = 100 },
			}

			local result1 = plot.pie_chart(data, { style = "solid", radius = 3 })
			local result2 = plot.pie_chart(data, { style = "pattern", radius = 3 })
			local result3 = plot.pie_chart(data, { style = "unicode", radius = 3 })

			assert.is_true(#result1 > 0)
			assert.is_true(#result2 > 0)
			assert.is_true(#result3 > 0)
		end)
	end)

	describe("bar_pie_chart", function()
		it("should generate bar-style pie chart", function()
			local data = {
				{ label = "Item A", value = 60 },
				{ label = "Item B", value = 40 },
			}

			local result = plot.bar_pie_chart(data, { title = "Distribution" })

			assert.is_true(#result > 0)
			assert.is_true(result[1]:match("Distribution") ~= nil)
		end)

		it("should handle empty data", function()
			local result = plot.bar_pie_chart({})
			assert.are.equal(1, #result)
		end)
	end)

	describe("table", function()
		it("should generate table with borders", function()
			local data = {
				{ "Task 1", "Complete" },
				{ "Task 2", "Pending" },
			}

			local headers = { "Task", "Status" }
			local result = plot.table(data, { headers = headers, show_borders = true, title = "Tasks" })

			assert.is_true(#result > 0)
			-- Should have border characters
			local has_borders = false
			for _, line in ipairs(result) do
				if line:match("[│┌┐└┘─]") then
					has_borders = true
					break
				end
			end
			assert.is_true(has_borders)
		end)

		it("should generate table without borders", function()
			local data = {
				{ "A", "1" },
				{ "B", "2" },
			}

			local headers = { "Col1", "Col2" }
			local result = plot.table(data, { headers = headers, show_borders = false })

			assert.is_true(#result > 0)
		end)

		it("should handle empty data", function()
			local result = plot.table({}, { headers = { "H1", "H2" } })
			assert.are.equal(1, #result)
		end)

		it("should handle missing values", function()
			local data = {
				{ "A" }, -- Missing second column
			}

			local headers = { "Col1", "Col2" }
			local result = plot.table(data, { headers = headers, show_borders = true })

			assert.is_true(#result > 0)
		end)

		it("should use default headers", function()
			local data = {
				{ "Item", "10" },
			}

			local result = plot.table(data)
			assert.is_true(#result > 0)
		end)
	end)

	describe("line_plot", function()
		it("should generate line plot for valid data", function()
			local data = {
				{ value = 10 },
				{ value = 20 },
				{ value = 15 },
				{ value = 25 },
				{ value = 30 },
			}

			local result = plot.line_plot(data, { title = "Trend", width = 40, height = 10 })

			assert.is_true(#result > 0)
			assert.is_true(result[1]:match("Trend") ~= nil)
		end)

		it("should handle empty data", function()
			local result = plot.line_plot({})
			assert.are.equal(1, #result)
		end)

		it("should show axes when enabled", function()
			local data = {
				{ value = 5 },
				{ value = 10 },
				{ value = 7 },
			}

			local result = plot.line_plot(data, { show_axes = true, height = 10 })

			-- Should contain axis characters
			local has_axes = false
			for _, line in ipairs(result) do
				if line:match("[│─└]") then
					has_axes = true
					break
				end
			end
			assert.is_true(has_axes)
		end)

		it("should show scale information", function()
			local data = {
				{ value = 10 },
				{ value = 50 },
			}

			local result = plot.line_plot(data, { title = nil })

			local has_range = false
			for _, line in ipairs(result) do
				if line:match("Range:") then
					has_range = true
					break
				end
			end
			assert.is_true(has_range)
		end)

		it("should handle single data point", function()
			local data = {
				{ value = 42 },
			}

			local result = plot.line_plot(data, { height = 5, width = 20 })
			assert.is_true(#result > 0)
		end)

		it("should handle same values", function()
			local data = {
				{ value = 10 },
				{ value = 10 },
				{ value = 10 },
			}

			local result = plot.line_plot(data)
			assert.is_true(#result > 0)
		end)
	end)

	describe("integration", function()
		it("should handle all chart types with same data", function()
			local data = {
				{ label = "A", value = 10 },
				{ label = "B", value = 20 },
				{ label = "C", value = 15 },
			}

			local hist = plot.histogram(data)
			local pie = plot.pie_chart(data, { radius = 5 })
			local bar_pie = plot.bar_pie_chart(data)

			assert.is_true(#hist > 0)
			assert.is_true(#pie > 0)
			assert.is_true(#bar_pie > 0)
		end)

		it("should handle large datasets", function()
			local data = {}
			for i = 1, 100 do
				table.insert(data, { label = "Item " .. i, value = math.random(1, 100) })
			end

			local hist = plot.histogram(data, { width = 50 })
			local pie = plot.pie_chart(data, { radius = 8, show_legend = false })

			assert.is_true(#hist > 0)
			assert.is_true(#pie > 0)
		end)
	end)
end)
