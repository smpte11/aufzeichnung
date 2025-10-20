-- ⚡ NOTES UTILITIES MODULE ⚡
-- Data formatting, conversion, and utility functions for task visualizations
-- Bridges between SQLite results and plotting functions

local M = {}

-- ═══════════════════════════════════════════════════════════════════════
-- 📊 DATA CONVERSION UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

-- Convert SQLite results to chart-compatible format
-- @param sql_results: array of rows from db:eval()
-- @param label_column: column name for labels (string)
-- @param value_column: column name for values (number)
-- @return: array of {label = string, value = number}
function M.sql_to_chart_data(sql_results, label_column, value_column)
	local data = {}
	
	if not sql_results or type(sql_results) ~= "table" then
		return data
	end
	
	for _, row in ipairs(sql_results) do
		if type(row) == "table" then
			local label = tostring(row[label_column] or "Unknown")
			local value = tonumber(row[value_column] or 0)
			
			table.insert(data, {
				label = label,
				value = value
			})
		end
	end
	
	return data
end

-- Convert SQLite results to table format
-- @param sql_results: array of rows from db:eval()
-- @param columns: array of column names to extract
-- @return: array of arrays for table display
function M.sql_to_table_data(sql_results, columns)
	local data = {}
	
	if not sql_results or type(sql_results) ~= "table" then
		return data
	end
	
	for _, row in ipairs(sql_results) do
		if type(row) == "table" then
			local table_row = {}
			for _, col in ipairs(columns) do
				table.insert(table_row, tostring(row[col] or ""))
			end
			table.insert(data, table_row)
		end
	end
	
	return data
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🎨 DATA ENHANCEMENT UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

-- Add emojis to task states for better visualization
-- @param state: task state string
-- @return: emoji + state string
function M.add_state_emoji(state)
	local emoji_map = {
		FINISHED = "✅",
		COMPLETED = "✅",
		IN_PROGRESS = "🚀",
		STARTED = "🚀",
		CREATED = "📝",
		NEW = "📝",
		DELETED = "🗑️",
		CANCELLED = "❌",
		BLOCKED = "🚫",
		PAUSED = "⏸️"
	}
	
	local upper_state = string.upper(tostring(state or ""))
	local emoji = emoji_map[upper_state] or "📄"
	
	return emoji .. " " .. (state or "Unknown")
end

-- Add emojis to event types
-- @param event_type: event type string
-- @return: emoji + event type string
function M.add_event_emoji(event_type)
	local emoji_map = {
		task_created = "➕",
		task_completed = "✅",
		task_started = "🚀",
		task_carried_over = "⏭️",
		task_deleted = "🗑️",
		task_paused = "⏸️",
		task_resumed = "▶️",
		task_blocked = "🚫"
	}
	
	local emoji = emoji_map[tostring(event_type or "")] or "📋"
	
	return emoji .. " " .. (event_type or "unknown")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📅 DATE AND TIME UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

-- Format date for display in charts
-- @param date_string: ISO date string (YYYY-MM-DD)
-- @param format: "short", "medium", "long"
-- @return: formatted date string
function M.format_date(date_string, format)
	format = format or "short"
	
	if not date_string or date_string == "" then
		return "Unknown"
	end
	
	-- Parse ISO date (YYYY-MM-DD)
	local year, month, day = date_string:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
	
	if not year then
		return date_string  -- Return as-is if not parseable
	end
	
	local month_names = {
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	}
	
	if format == "short" then
		return string.format("%02d/%02d", tonumber(month), tonumber(day))
	elseif format == "medium" then
		return string.format("%s %d", month_names[tonumber(month)] or "???", tonumber(day))
	elseif format == "long" then
		return string.format("%s %d, %s", month_names[tonumber(month)] or "???", tonumber(day), year)
	else
		return date_string
	end
end

-- Get relative date description
-- @param date_string: ISO date string (YYYY-MM-DD)
-- @return: "Today", "Yesterday", "2 days ago", etc.
function M.relative_date(date_string)
	if not date_string or date_string == "" then
		return "Unknown"
	end
	
	local today = os.date("%Y-%m-%d")
	local yesterday = os.date("%Y-%m-%d", os.time() - 24 * 60 * 60)
	
	if date_string == today then
		return "Today"
	elseif date_string == yesterday then
		return "Yesterday"
	else
		-- Calculate days difference (simplified)
		local year, month, day = date_string:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
		if year and month and day then
			local date_time = os.time({year = year, month = month, day = day})
			local today_time = os.time()
			local diff_days = math.floor((today_time - date_time) / (24 * 60 * 60))
			
			if diff_days > 0 then
				return string.format("%d day%s ago", diff_days, diff_days == 1 and "" or "s")
			elseif diff_days < 0 then
				return string.format("In %d day%s", math.abs(diff_days), math.abs(diff_days) == 1 and "" or "s")
			else
				return "Today"
			end
		end
	end
	
	return date_string
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🔢 MATHEMATICAL UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

-- Calculate productivity score from task events
-- @param created: number of tasks created
-- @param completed: number of tasks completed  
-- @param carried_over: number of tasks carried over
-- @param custom_weights: optional {created = 1, completed = 2, carried_over = -1}
-- @return: productivity score (number)
function M.calculate_productivity_score(created, completed, carried_over, custom_weights)
	local weights = custom_weights or {
		created = 1,      -- Creating tasks is good
		completed = 2,    -- Completing tasks is better
		carried_over = -1 -- Carrying over tasks is less ideal
	}
	
	created = tonumber(created) or 0
	completed = tonumber(completed) or 0
	carried_over = tonumber(carried_over) or 0
	
	return (created * weights.created) + 
	       (completed * weights.completed) + 
	       (carried_over * weights.carried_over)
end

-- Generate date range for queries
-- @param days: number of days to go back
-- @return: start_date, end_date (ISO strings)
function M.date_range(days)
	days = tonumber(days) or 7
	
	local end_date = os.date("%Y-%m-%d")
	local start_date = os.date("%Y-%m-%d", os.time() - (days - 1) * 24 * 60 * 60)
	
	return start_date, end_date
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🔧 TEXT PROCESSING UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

-- Truncate text for display in charts
-- @param text: string to truncate
-- @param max_length: maximum length (default 30)
-- @param suffix: suffix for truncated text (default "...")
-- @return: truncated string
function M.truncate_text(text, max_length, suffix)
	text = tostring(text or "")
	max_length = tonumber(max_length) or 30
	suffix = suffix or "..."
	
	if #text <= max_length then
		return text
	end
	
	return string.sub(text, 1, max_length - #suffix) .. suffix
end

-- Clean task text for display (remove markdown, URIs, etc.)
-- @param task_text: raw task text
-- @return: cleaned text
function M.clean_task_text(task_text)
	if not task_text or task_text == "" then
		return "Unknown task"
	end
	
	-- Remove task URI patterns
	local cleaned = task_text:gsub("%[ %]%(task://[%w%-]+%)", "")
	
	-- Remove extra whitespace
	cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
	cleaned = cleaned:gsub("%s+", " ")
	
	-- Remove markdown checkboxes if they leaked through
	cleaned = cleaned:gsub("^%- %[.-%] ", "")
	
	if cleaned == "" then
		return "Empty task"
	end
	
	return cleaned
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🆔 UUID v7 GENERATION (TIME-ORDERED UNIQUE IDENTIFIERS)
-- ═══════════════════════════════════════════════════════════════════════

-- Generate a UUID v7 (time-ordered UUID with millisecond precision)
-- Format: XXXXXXXX-XXXX-7XXX-XXXX-XXXXXXXXXXXX
-- Where first 48 bits = Unix timestamp (ms), version = 7, rest = random
function M.generate_uuid_v7()
	-- Seed random number generator
	math.randomseed(os.time() + os.clock() * 1000000)
	
	-- Get current Unix timestamp in milliseconds
	local timestamp_ms = math.floor(os.time() * 1000)
	
	-- Generate random bytes function
	local function random_hex_byte()
		return string.format("%02x", math.random(0, 255))
	end
	
	-- Convert timestamp to hex (48 bits = 6 bytes = 12 hex chars)
	local timestamp_hex = string.format("%012x", timestamp_ms)
	
	-- Generate random data for the UUID
	local rand1 = random_hex_byte() .. random_hex_byte() .. random_hex_byte()  -- 24 bits
	local rand2 = random_hex_byte() .. random_hex_byte()                       -- 16 bits
	local rand3 = ""
	for i = 1, 6 do
		rand3 = rand3 .. random_hex_byte()                                    -- 48 bits
	end
	
	-- Set version (4 bits = 7) in the 13th hex digit position
	local version_rand = "7" .. rand1:sub(2, 3)
	
	-- Set variant (2 bits = 10) in the 17th hex digit position  
	local variant_byte = math.random(128, 191) -- 10xxxxxx in binary
	local variant_hex = string.format("%02x", variant_byte)
	local variant_rand = variant_hex .. rand2:sub(3, 4)
	
	-- Construct UUID v7: TTTTTTTT-TTTT-7RRR-VRRR-RRRRRRRRRRRR
	local uuid = string.format("%s-%s-%s-%s-%s",
		timestamp_hex:sub(1, 8),      -- First 32 bits of timestamp
		timestamp_hex:sub(9, 12),     -- Next 16 bits of timestamp  
		version_rand,                 -- Version 7 + 12 bits random
		variant_rand,                 -- Variant + 14 bits random
		rand3                         -- Final 48 bits random
	)
	
	return uuid:lower()
end


-- ═══════════════════════════════════════════════════════════════════════
-- 📊 AGGREGATION UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

-- Group data by time period
-- @param data: array of {date = "YYYY-MM-DD", value = number}
-- @param period: "day", "week", "month"
-- @return: grouped data suitable for charts
function M.group_by_period(data, period)
	period = period or "day"
	
	if not data or #data == 0 then
		return {}
	end
	
	local groups = {}
	
	for _, item in ipairs(data) do
		local date_str = item.date or item.label or ""
		local value = tonumber(item.value) or 0
		
		local group_key = date_str  -- Default: group by day
		
		if period == "week" then
			-- Group by week (simplified - just use Monday of the week)
			local year, month, day = date_str:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
			if year and month and day then
				local date_time = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
				local weekday = tonumber(os.date("%w", date_time))  -- 0 = Sunday
				local monday_offset = weekday == 0 and -6 or -(weekday - 1)
				local monday_time = date_time + monday_offset * 24 * 60 * 60
				group_key = os.date("%Y-%m-%d", monday_time)
			end
		elseif period == "month" then
			-- Group by month - extract YYYY-MM
			local year_month = date_str:match("^(%d%d%d%d)-(%d%d)")
			if year_month then
				group_key = year_month  -- Use YYYY-MM as key
			end
		end
		
		if not groups[group_key] then
			groups[group_key] = 0
		end
		groups[group_key] = groups[group_key] + value
	end
	
	-- Convert to array format
	local result = {}
	for group_key, total_value in pairs(groups) do
		table.insert(result, {
			label = group_key,
			value = total_value
		})
	end
	
	-- Sort by label (date)
	table.sort(result, function(a, b)
		return a.label < b.label
	end)
	
	return result
end

-- Calculate moving average
-- @param data: array of {label = string, value = number}
-- @param window_size: number of periods for average (default 3)
-- @return: smoothed data
function M.moving_average(data, window_size)
	window_size = tonumber(window_size) or 3
	
	if not data or #data < window_size then
		return data
	end
	
	local result = {}
	
	for i = window_size, #data do
		local sum = 0
		local count = 0
		
		for j = i - window_size + 1, i do
			local value = tonumber(data[j].value) or 0
			sum = sum + value
			count = count + 1
		end
		
		local avg = count > 0 and (sum / count) or 0
		
		table.insert(result, {
			label = data[i].label,
			value = math.floor(avg * 100) / 100  -- Round to 2 decimal places
		})
	end
	
	return result
end

return M
