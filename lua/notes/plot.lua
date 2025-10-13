-- ⚡ ASCII PLOTTING MODULE FOR TASK VISUALIZATIONS ⚡
-- Pure visualization functions for creating ASCII charts, graphs, and plots
-- No dependencies on SQLite or task system - just pure plotting

local M = {}

-- ASCII Art Characters for Charts
local CHART_CHARS = {
	bar = "█",
	half_bar = "▌", 
	quarter_bar = "▏",
	dot = "•",
	line_h = "─",
	line_v = "│",
	corner_tl = "┌",
	corner_tr = "┐", 
	corner_bl = "└",
	corner_br = "┘",
	cross = "┼",
	tee_up = "┴",
	tee_down = "┬",
	tee_left = "┤",
	tee_right = "├"
}

-- ═══════════════════════════════════════════════════════════════════════
-- 📊 HISTOGRAM GENERATOR
-- ═══════════════════════════════════════════════════════════════════════

function M.histogram(data, opts)
	opts = opts or {}
	local title = opts.title or "Histogram"
	local width = opts.width or 50
	local height = opts.height or 10
	local show_values = opts.show_values ~= false

	if not data or #data == 0 then
		return {"No data to display"}
	end

	-- Find max value for scaling
	local max_val = 0
	for _, item in ipairs(data) do
		max_val = math.max(max_val, item.value or item[2] or 0)
	end

	if max_val == 0 then
		return {"No data to display"}
	end

	local result = {}
	
	-- Title
	if title then
		table.insert(result, title)
		table.insert(result, string.rep("═", math.min(#title, width)))
	end

	-- Generate bars
	for _, item in ipairs(data) do
		local label = item.label or item[1] or "Unknown"
		local value = item.value or item[2] or 0
		
		-- Calculate bar length
		local bar_length = math.floor((value / max_val) * width)
		local bar = string.rep(CHART_CHARS.bar, bar_length)
		
		-- Format line
		if show_values then
			local line = string.format("%-15s %s %d", label, bar, value)
			table.insert(result, line)
		else
			local line = string.format("%-15s %s", label, bar)
			table.insert(result, line)
		end
	end

	return result
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🥧 PIE CHART GENERATOR - ACTUAL CIRCULAR PIE! 
-- ═══════════════════════════════════════════════════════════════════════

function M.pie_chart(data, opts)
	opts = opts or {}
	local title = opts.title or "Pie Chart"
	local show_percentages = opts.show_percentages ~= false
	local radius = opts.radius or 8
	local show_legend = opts.show_legend ~= false
	local style = opts.style or "solid"  -- "solid", "pattern", "unicode"

	if not data or #data == 0 then
		return {"No data to display"}
	end

	-- Calculate total
	local total = 0
	for _, item in ipairs(data) do
		total = total + (item.value or item[2] or 0)
	end

	if total == 0 then
		return {"No data to display"}
	end

	local result = {}
	
	-- Title
	if title then
		table.insert(result, title)
		table.insert(result, string.rep("═", math.min(#title, 60)))
	end

	-- Pie slice characters for different styles
	local slice_chars = {
		solid = {"█", "▓", "▒", "░", "▬", "▪", "▫", "▭"},
		pattern = {"█", "▓", "▒", "░", "╳", "╱", "╲", "▦"},
		unicode = {"●", "◐", "◑", "◒", "◓", "◔", "◕", "○"}
	}
	
	local chars = slice_chars[style] or slice_chars.solid

	-- Calculate cumulative percentages for angle calculation
	local cumulative = 0
	local slice_data = {}
	for i, item in ipairs(data) do
		local label = item.label or item[1] or "Unknown"
		local value = item.value or item[2] or 0
		local percentage = (value / total) * 100
		
		table.insert(slice_data, {
			label = label,
			value = value,
			percentage = percentage,
			start_angle = cumulative * 2 * math.pi / 100,  -- Convert to radians
			end_angle = (cumulative + percentage) * 2 * math.pi / 100,
			char = chars[((i - 1) % #chars) + 1]
		})
		
		cumulative = cumulative + percentage
	end

	-- Create the circular pie chart
	local center_x, center_y = radius + 1, radius + 1
	local grid = {}
	
	-- Initialize grid
	for y = 1, 2 * radius + 1 do
		grid[y] = {}
		for x = 1, 2 * radius + 1 do
			grid[y][x] = " "
		end
	end

	-- Fill the pie chart
	for y = 1, 2 * radius + 1 do
		for x = 1, 2 * radius + 1 do
			local dx = x - center_x
			local dy = y - center_y
			local distance = math.sqrt(dx * dx + dy * dy)
			
			-- Check if point is within circle
			if distance <= radius then
				-- Calculate angle from center (0 = right, π/2 = down, π = left, 3π/2 = up)
				local angle = math.atan2(dy, dx)
				if angle < 0 then
					angle = angle + 2 * math.pi  -- Normalize to 0-2π
				end
				
				-- Rotate so 0 degrees is at top (like a clock)
				angle = angle - math.pi/2
				if angle < 0 then
					angle = angle + 2 * math.pi
				end
				
				-- Find which slice this angle belongs to
				for _, slice in ipairs(slice_data) do
					if angle >= slice.start_angle and angle < slice.end_angle then
						grid[y][x] = slice.char
						break
					end
				end
				
				-- Handle the case where we're at exactly 0/2π (top of circle)
				if grid[y][x] == " " and math.abs(angle - 2 * math.pi) < 0.1 then
					grid[y][x] = slice_data[1].char  -- First slice
				end
			end
		end
	end

	-- Convert grid to strings
	for y = 1, 2 * radius + 1 do
		table.insert(result, table.concat(grid[y]))
	end

	-- Add legend if requested
	if show_legend then
		table.insert(result, "")
		table.insert(result, "Legend:")
		for _, slice in ipairs(slice_data) do
			if show_percentages then
				local line = string.format("%s %s - %.1f%% (%d)", 
					slice.char, slice.label, slice.percentage, slice.value)
				table.insert(result, line)
			else
				local line = string.format("%s %s (%d)", 
					slice.char, slice.label, slice.value)
				table.insert(result, line)
			end
		end
	end

	return result
end

-- Legacy bar-style pie chart (alternative visualization)
function M.bar_pie_chart(data, opts)
	opts = opts or {}
	local title = opts.title or "Bar Pie Chart"
	local show_percentages = opts.show_percentages ~= false

	if not data or #data == 0 then
		return {"No data to display"}
	end

	-- Calculate total
	local total = 0
	for _, item in ipairs(data) do
		total = total + (item.value or item[2] or 0)
	end

	if total == 0 then
		return {"No data to display"}
	end

	local result = {}
	
	-- Title
	if title then
		table.insert(result, title)
		table.insert(result, string.rep("═", math.min(#title, 40)))
	end

	-- Generate pie slices (horizontal bar representation)
	for _, item in ipairs(data) do
		local label = item.label or item[1] or "Unknown"
		local value = item.value or item[2] or 0
		local percentage = (value / total) * 100
		
		-- Create visual representation with filled blocks
		local block_count = math.floor(percentage / 5) -- Each block = 5%
		local blocks = string.rep(CHART_CHARS.bar, block_count)
		
		if show_percentages then
			local line = string.format("%-15s %s %.1f%% (%d)", label, blocks, percentage, value)
			table.insert(result, line)
		else
			local line = string.format("%-15s %s (%d)", label, blocks, value)
			table.insert(result, line)
		end
	end

	return result
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📋 TABLE GENERATOR
-- ═══════════════════════════════════════════════════════════════════════

function M.table(data, opts)
	opts = opts or {}
	local title = opts.title or "Table"
	local headers = opts.headers or {"Label", "Value"}
	local show_borders = opts.show_borders ~= false

	if not data or #data == 0 then
		return {"No data to display"}
	end

	local result = {}
	
	-- Title (only when borders are enabled)
	if title and show_borders then
		table.insert(result, title)
		table.insert(result, string.rep("═", #title))
	end

	-- Calculate column widths
	local col_widths = {}
	for i, header in ipairs(headers) do
		col_widths[i] = #header
	end
	
	-- Check data for max width
	for _, row in ipairs(data) do
		for i, cell in ipairs(row) do
			if col_widths[i] then
				col_widths[i] = math.max(col_widths[i], #tostring(cell))
			end
		end
	end

	if show_borders then
		-- Top border
		local top_border = CHART_CHARS.corner_tl
		for i, width in ipairs(col_widths) do
			top_border = top_border .. string.rep(CHART_CHARS.line_h, width + 2)
			if i < #col_widths then
				top_border = top_border .. CHART_CHARS.tee_down
			end
		end
		top_border = top_border .. CHART_CHARS.corner_tr
		table.insert(result, top_border)

		-- Headers
		local header_row = CHART_CHARS.line_v
		for i, header in ipairs(headers) do
			header_row = header_row .. " " .. string.format("%-" .. col_widths[i] .. "s", header) .. " "
			if i < #headers then
				header_row = header_row .. CHART_CHARS.line_v
			end
		end
		header_row = header_row .. CHART_CHARS.line_v
		table.insert(result, header_row)

		-- Separator
		local sep = CHART_CHARS.tee_right
		for i, width in ipairs(col_widths) do
			sep = sep .. string.rep(CHART_CHARS.line_h, width + 2)
			if i < #col_widths then
				sep = sep .. CHART_CHARS.cross
			end
		end
		sep = sep .. CHART_CHARS.tee_left
		table.insert(result, sep)

		-- Data rows
		for _, row in ipairs(data) do
			local data_row = CHART_CHARS.line_v
			for i, cell in ipairs(row) do
				if col_widths[i] then
					data_row = data_row .. " " .. string.format("%-" .. col_widths[i] .. "s", tostring(cell)) .. " "
					if i < #headers then
						data_row = data_row .. CHART_CHARS.line_v
					end
				end
			end
			data_row = data_row .. CHART_CHARS.line_v
			table.insert(result, data_row)
		end

		-- Bottom border
		local bottom_border = CHART_CHARS.corner_bl
		for i, width in ipairs(col_widths) do
			bottom_border = bottom_border .. string.rep(CHART_CHARS.line_h, width + 2)
			if i < #col_widths then
				bottom_border = bottom_border .. CHART_CHARS.tee_up
			end
		end
		bottom_border = bottom_border .. CHART_CHARS.corner_br
		table.insert(result, bottom_border)
	else
		-- Simple table without borders
		-- Headers
		local header_row = ""
		for i, header in ipairs(headers) do
			header_row = header_row .. string.format("%-" .. (col_widths[i] + 3) .. "s", header)
		end
		table.insert(result, header_row)
		
		-- Separator
		local sep = ""
		for i, width in ipairs(col_widths) do
			sep = sep .. string.rep("-", width) .. "   "
		end
		table.insert(result, sep)

		-- Data rows
		for _, row in ipairs(data) do
			local data_row = ""
			for i, cell in ipairs(row) do
				if col_widths[i] then
					data_row = data_row .. string.format("%-" .. (col_widths[i] + 3) .. "s", tostring(cell))
				end
			end
			table.insert(result, data_row)
		end
	end

	return result
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📈 LINE PLOT GENERATOR
-- ═══════════════════════════════════════════════════════════════════════

function M.line_plot(data, opts)
	opts = opts or {}
	local title = opts.title or "Line Plot"
	local width = opts.width or 60
	local height = opts.height or 15
	local show_axes = opts.show_axes ~= false

	if not data or #data == 0 then
		return {"No data to display"}
	end

	-- Find min/max values for scaling
	local min_val, max_val = math.huge, -math.huge
	for _, point in ipairs(data) do
		local value = point.value or point[2] or point.y or 0
		min_val = math.min(min_val, value)
		max_val = math.max(max_val, value)
	end

	if min_val == max_val then
		max_val = min_val + 1 -- Avoid division by zero
	end

	local result = {}
	
	-- Title
	if title then
		table.insert(result, title)
		table.insert(result, string.rep("═", #title))
	end

	-- Create plot grid
	local grid = {}
	for y = 1, height do
		grid[y] = {}
		for x = 1, width do
			grid[y][x] = " "
		end
	end

	-- Plot points
	for i, point in ipairs(data) do
		local value = point.value or point[2] or point.y or 0
		
		-- Scale to grid
		local x = math.floor(((i - 1) / (#data - 1)) * (width - 1)) + 1
		local y = height - math.floor(((value - min_val) / (max_val - min_val)) * (height - 1))
		
		if x >= 1 and x <= width and y >= 1 and y <= height then
			grid[y][x] = CHART_CHARS.dot
		end
		
		-- Connect with previous point (simple line)
		if i > 1 then
			local prev_point = data[i - 1]
			local prev_value = prev_point.value or prev_point[2] or prev_point.y or 0
			local prev_x = math.floor(((i - 2) / (#data - 1)) * (width - 1)) + 1
			local prev_y = height - math.floor(((prev_value - min_val) / (max_val - min_val)) * (height - 1))
			
			-- Simple line drawing between points
			local steps = math.max(math.abs(x - prev_x), math.abs(y - prev_y))
			if steps > 0 then
				for step = 1, steps do
					local interp_x = math.floor(prev_x + ((x - prev_x) * step / steps))
					local interp_y = math.floor(prev_y + ((y - prev_y) * step / steps))
					
					if interp_x >= 1 and interp_x <= width and interp_y >= 1 and interp_y <= height then
						if grid[interp_y][interp_x] == " " then
							grid[interp_y][interp_x] = CHART_CHARS.line_h
						end
					end
				end
			end
		end
	end

	-- Add axes if requested
	if show_axes then
		-- Y-axis
		for y = 1, height do
			if grid[y][1] == " " then
				grid[y][1] = CHART_CHARS.line_v
			end
		end
		
		-- X-axis (bottom)
		for x = 1, width do
			if grid[height][x] == " " then
				grid[height][x] = CHART_CHARS.line_h
			end
		end
		
		-- Origin
		grid[height][1] = CHART_CHARS.corner_bl
	end

	-- Convert grid to strings
	for y = 1, height do
		table.insert(result, table.concat(grid[y]))
	end

	-- Add scale info
	table.insert(result, "")
	table.insert(result, string.format("Range: %.2f to %.2f", min_val, max_val))

	return result
end

return M
