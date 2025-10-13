-- ⚡ COMPREHENSIVE NOTES MODULE ⚡
-- Complete notes management system with zk-nvim, task tracking, and visualization
-- Configurable directories, databases, and visualization preferences

local plot = require('notes.plot')
local utils = require('notes.utils')

local M = {}


-- Default configuration with comprehensive options
local default_config = {
	-- 📁 Directory Configuration
	directories = {
		notebook = vim.env.ZK_NOTEBOOK_DIR or vim.fn.expand("~/notes"), -- Main notes directory
		personal_journal = "journal/daily",    -- Personal daily journals subdirectory  
		work_journal = "work",                 -- Work journals subdirectory
		archive = "archive",                   -- Archive subdirectory
	},
	
	-- 📊 Note Type Tracking Configuration  
	tracking = {
		personal = {
			enabled = true,
			filename_patterns = { "perso%-.*%.md$" },  -- Files to track for personal tasks
			database_path = nil, -- Auto: {notebook}/.perso-tasks.db
		},
		work = {
			enabled = true, 
			filename_patterns = { "work%-.*%.md$" },   -- Files to track for work tasks
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
		carryover_enabled = true, -- Carry unfinished tasks to new journals
	},
	
	-- ⌨️ Keybinding Configuration
	keymaps = {
		enabled = true,
		prefix = "<leader>n",
	-- Individual keybinds can be disabled by setting to false
		mappings = {
			-- Note creation
			new_note = "n",           -- <leader>nn
			new_at_dir = "N",         -- <leader>nN  
			new_task = "T",           -- <leader>nT (creates task with UUID v7)
			new_child_task = "C",     -- <leader>nC (creates child task)
			
			-- Journal creation
			daily_journal = "j",      -- <leader>nj
			work_journal = "w",       -- <leader>nw
			
			-- Note browsing
			open_notes = "o",         -- <leader>no
			find_notes = "f",         -- <leader>nf
			browse_tags = "t",        -- <leader>nt
			
			-- 📊 STATS & DASHBOARDS (Enhanced!)
			dashboard = "d",          -- <leader>nd (personal dashboard)
			work_dashboard = "dw",    -- <leader>ndw (work dashboard) 
			today = "dt",             -- <leader>ndt (today's overview)
			yesterday = "dy",         -- <leader>ndy (yesterday's activity)
			weekly = "dW",            -- <leader>ndW (weekly overview)
			last_week = "dl",         -- <leader>ndl (last week summary)
			friday_review = "df",     -- <leader>ndf (Friday review)
			quick_stats = "ds",       -- <leader>nds (quick stats)
			
			-- Detailed visualization (existing)
			task_stats = "ts",        -- <leader>nts (detailed task stats)
			task_completions = "tc",  -- <leader>ntc (completion history)
			task_states = "tp",       -- <leader>ntp (task state pie chart)
			productivity_trend = "tt", -- <leader>ntt (productivity trend)
			recent_activity = "ta",   -- <leader>nta (recent activity log)
			work_stats = "tw",        -- <leader>ntw (work-specific stats)
		}
	},
	
	-- 🔔 Notification Configuration
	notifications = {
		enabled = true,                  -- Enable/disable all notifications
		task_operations = true,          -- Notify on task save/update operations
		journal_carryover = true,        -- Notify when tasks are carried over to new journals
		database_operations = false,    -- Notify on database creation/connection (verbose)
		level = "info",                  -- Notification level: "error", "warn", "info", "debug"
		duration = 3000,                 -- Duration in milliseconds (0 for no timeout)
		position = "top_right",          -- Position for notifications
	},
	
	-- 🔧 Advanced Configuration
	advanced = {
		auto_create_directories = true,  -- Create missing directories
		database_optimization = true,    -- Use WAL mode, caching, etc.
		debug_mode = false,              -- Verbose logging
	}
}

-- Module state
local config = {}
local is_setup = false

-- Database connection cache
local task_db_cache = {}
local cached_db_paths = {}

-- ═══════════════════════════════════════════════════════════════════════
-- 🔔 NOTIFICATION HELPERS
-- ═══════════════════════════════════════════════════════════════════════

-- Show a notification if enabled
local function notify(message, level, category)
	if not config.notifications or not config.notifications.enabled then
		return
	end
	
	-- Check category-specific settings
	if category == "task_operations" and not config.notifications.task_operations then
		return
	elseif category == "journal_carryover" and not config.notifications.journal_carryover then
		return  
	elseif category == "database_operations" and not config.notifications.database_operations then
		return
	end
	
	-- Map our levels to vim log levels
	local vim_levels = {
		error = vim.log.levels.ERROR,
		warn = vim.log.levels.WARN,
		info = vim.log.levels.INFO,
		debug = vim.log.levels.DEBUG
	}
	
	local vim_level = vim_levels[level or config.notifications.level] or vim.log.levels.INFO
	
	-- Use vim.notify with enhanced options if available
	if vim.notify then
		local notify_opts = {}
		
		if config.notifications.duration and config.notifications.duration > 0 then
			notify_opts.timeout = config.notifications.duration
		end
		
		-- Add title for better context
		notify_opts.title = "📝 Notes"
		
		vim.notify(message, vim_level, notify_opts)
	else
		-- Fallback for basic vim
		local prefix = level == "error" and "❌" or level == "warn" and "⚠️" or "✅"
		print(prefix .. " Notes: " .. message)
	end
end

-- Deep copy utility for configuration
local function deep_copy(orig)
	local copy
	if type(orig) == 'table' then
		copy = {}
		for k, v in pairs(orig) do
			copy[k] = deep_copy(v)
		end
	else
		copy = orig
	end
	return copy
end

-- Deep merge utility for configuration
local function deep_merge(base, override)
	if vim and vim.tbl_deep_extend then
		return vim.tbl_deep_extend("force", base, override)
	else
		local result = deep_copy(base)
		for k, v in pairs(override) do
			if type(v) == "table" and type(result[k]) == "table" then
				result[k] = deep_merge(result[k], v)
			else
				result[k] = v
			end
		end
		return result
	end
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🎯 MAIN SETUP FUNCTION
-- ═══════════════════════════════════════════════════════════════════════

function M.setup(user_config)
	if is_setup then
		if config.advanced and config.advanced.debug_mode then
			print("🔄 Notes module already set up, reconfiguring...")
		end
	end

	-- Merge configuration
	config = deep_merge(default_config, user_config or {})
	
	-- Expand and validate directories
	M._setup_directories()
	
	-- Set up zk-nvim if enabled
	if config.zk.enabled then
		M._setup_zk()
	end
	
	-- Set up task tracking if enabled
	M._setup_task_tracking()
	
	-- Set up commands
	M._setup_commands()
	
	-- Set up keymaps if enabled
	if config.keymaps.enabled then
		M._setup_keymaps()
	end
	
	is_setup = true
	
	if config.advanced.debug_mode then
		print("✅ Notes module setup complete!")
		print("📁 Notebook directory:", config.directories.notebook)
		print("📊 Tracking enabled for:", vim.tbl_keys(config.tracking))
	end
	
	return config
end

-- Get current configuration
function M.get_config()
	return config
end

-- Check if module is set up
function M.is_ready()
	return is_setup
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📁 DIRECTORY SETUP
-- ═══════════════════════════════════════════════════════════════════════

function M._setup_directories()
	-- Expand main notebook directory
	config.directories.notebook = vim.fn.expand(config.directories.notebook)
	
	-- Create directories if needed
	if config.advanced.auto_create_directories then
		local created_dirs = {}
		
		-- Main notebook directory
		if vim.fn.isdirectory(config.directories.notebook) == 0 then
			local success = vim.fn.mkdir(config.directories.notebook, "p")
			if success == 0 then
				error("Failed to create notebook directory: " .. config.directories.notebook)
			else
				table.insert(created_dirs, vim.fn.fnamemodify(config.directories.notebook, ":t"))
			end
		end
		
		-- Subdirectories
		for name, subdir in pairs(config.directories) do
			if name ~= "notebook" and subdir ~= "" then
				local full_path = config.directories.notebook .. "/" .. subdir
				if vim.fn.isdirectory(full_path) == 0 then
					local success = vim.fn.mkdir(full_path, "p")
					if success ~= 0 then
						table.insert(created_dirs, subdir)
					end
				end
			end
		end
		
		-- Notify about created directories
		if #created_dirs > 0 then
			notify(string.format("📁 Created directories: %s", table.concat(created_dirs, ", ")), "info", "database_operations")
		end
	end
	
	-- Set up database paths for tracking types
	for track_type, track_config in pairs(config.tracking) do
		if track_config.enabled and not track_config.database_path then
			track_config.database_path = config.directories.notebook .. "/." .. track_type .. "-tasks.db"
		end
		if track_config.database_path then
			track_config.database_path = vim.fn.expand(track_config.database_path)
		end
	end
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📝 ZK-NVIM SETUP
-- ═══════════════════════════════════════════════════════════════════════

function M._setup_zk()
	-- Load zk-nvim
	local ok, zk = pcall(require, "zk")
	if not ok then
		vim.notify("zk-nvim not available, note management disabled", vim.log.levels.WARN)
		config.zk.enabled = false
		return
	end
	
	-- Basic zk setup
	local zk_config = {
		picker = config.zk.picker,
		lsp = {
			config = {
				cmd = { "zk", "lsp" },
				name = "zk",
				on_attach = function(_, bufnr)
					M._setup_buffer_keymaps(bufnr)
				end,
			}
		}
	}
	
	-- Merge any additional zk config
	for k, v in pairs(config.zk) do
		if k ~= "enabled" and k ~= "picker" then
			zk_config[k] = v
		end
	end
	
	zk.setup(zk_config)
	
	-- Store zk reference for commands
	M.zk = zk
end

-- Set up buffer-specific keymaps for zk buffers
function M._setup_buffer_keymaps(bufnr)
	local function map(mode, lhs, rhs, opts)
		vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { buffer = bufnr }, opts or {}))
	end
	
	local opts = { noremap = true, silent = false }
	
	-- Selection-based note creation
	map("v", config.keymaps.prefix .. config.keymaps.mappings.new_note .. "t",
		":'<,'>ZkNewFromTitleSelection<CR>",
		vim.tbl_extend("force", opts, { desc = "Create note from title selection" }))
	
	map("v", config.keymaps.prefix .. config.keymaps.mappings.new_note .. "c",
		":'<,'>ZkNewFromContentSelection { title = vim.fn.input('Title: ') }<CR>",
		vim.tbl_extend("force", opts, { desc = "Create note from content selection" }))
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📊 TASK TRACKING SETUP
-- ═══════════════════════════════════════════════════════════════════════

function M._setup_task_tracking()
	-- Load sqlite
	local ok, sqlite = pcall(require, "sqlite")
	if not ok then
		vim.notify("sqlite.lua not available, task tracking disabled", vim.log.levels.WARN)
		return
	end
	
	M.sqlite = sqlite
	
	-- Set up autocmd for task tracking
	-- Convert Lua patterns to vim glob patterns
	local patterns = {}
	for track_type, track_config in pairs(config.tracking) do
		if track_config.enabled then
			for _, lua_pattern in ipairs(track_config.filename_patterns) do
				-- Convert Lua pattern to glob pattern
				-- "perso%-.*%.md$" -> "perso-*.md"
				local glob_pattern = lua_pattern
					:gsub("%%%-", "-")      -- %-  -> -
					:gsub("%.%*", "*")      -- .* -> *
					:gsub("%%%.md%$", ".md") -- %.md$ -> .md
					:gsub("%$", "")         -- Remove end anchor
				table.insert(patterns, "*/" .. glob_pattern)
			end
		end
	end
	
	if #patterns > 0 then
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = vim.api.nvim_create_augroup("notes-task-tracking", { clear = true }),
			pattern = patterns,
			callback = function(event)
				M._track_tasks_on_save(event.buf)
			end,
		})
	end
	
	-- Cleanup autocmd
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("notes-task-cleanup", { clear = true }),
		callback = function()
			for track_type, _ in pairs(task_db_cache) do
				if task_db_cache[track_type] then
					task_db_cache[track_type]:close()
					task_db_cache[track_type] = nil
					cached_db_paths[track_type] = nil
				end
			end
		end,
	})
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🔄 DATABASE MIGRATION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

-- Check if a column exists in a table
-- @param db: database connection
-- @param table_name: name of the table
-- @param column_name: name of the column to check
-- @return: boolean indicating if column exists
local function column_exists(db, table_name, column_name)
	local pragma_result = db:eval(string.format("PRAGMA table_info(%s)", table_name))
	if not pragma_result then
		return false
	end
	
	for _, column_info in ipairs(pragma_result) do
		if column_info.name == column_name then
			return true
		end
	end
	
	return false
end

-- Run database migrations to update schema
-- @param db: database connection
function M._run_database_migrations(db)
	if not db then
		return
	end
	
	-- Migration 1: Add parent_id column if it doesn't exist
	if not column_exists(db, "task_events", "parent_id") then
		notify("🔄 Running database migration: Adding parent_id column", "info", "database_operations")
		
		-- Add the parent_id column (nullable) and create its index
		local success, err = pcall(function()
			db:execute("ALTER TABLE task_events ADD COLUMN parent_id TEXT")
			db:execute("CREATE INDEX IF NOT EXISTS idx_parent_id ON task_events(parent_id)")
		end)
		
		if success then
			notify("✅ Database migration completed: parent_id column and index added", "info", "database_operations")
		else
			notify(string.format("❌ Database migration failed: %s", tostring(err)), "error", "database_operations")
		end
	end
	
	-- Future migrations can be added here as needed
end

-- Get database connection for a tracking type
function M._get_task_database(track_type)
	local track_config = config.tracking[track_type]
	if not track_config or not track_config.enabled then
		return nil
	end
	
	local db_path = track_config.database_path
	if not db_path then
		return nil
	end
	
	-- Return cached connection if available
	if task_db_cache[track_type] and cached_db_paths[track_type] == db_path then
		return task_db_cache[track_type]
	end
	
	-- Close old connection if path changed
	if task_db_cache[track_type] then
		task_db_cache[track_type]:close()
		task_db_cache[track_type] = nil
	end
	
	-- Create database directory
	local db_dir = vim.fn.fnamemodify(db_path, ":h")
	if vim.fn.isdirectory(db_dir) == 0 then
		vim.fn.mkdir(db_dir, "p")
	end
	
	-- Create database connection
	local db = M.sqlite.new(db_path)
	if not db then
		notify(string.format("Failed to create database: %s", db_path), "error", "database_operations")
		return nil
	end
	
	if db.open then
		db:open()
	end
	
	-- Notify about database creation/connection
	local db_name = vim.fn.fnamemodify(db_path, ":t")
	notify(string.format("Connected to %s database (%s)", track_type, db_name), "debug", "database_operations")
	
	-- Optimize database if enabled
	if config.advanced.database_optimization then
		db:execute("PRAGMA journal_mode = WAL")
		db:execute("PRAGMA synchronous = NORMAL")
		db:execute("PRAGMA cache_size = 10000") 
		db:execute("PRAGMA temp_store = MEMORY")
	end
	
	-- Create table with original schema first (backward compatible)
	db:execute([[
		CREATE TABLE IF NOT EXISTS task_events (
			event_id INTEGER PRIMARY KEY AUTOINCREMENT,
			task_id TEXT NOT NULL,
			event_type TEXT NOT NULL,
			timestamp TEXT NOT NULL,
			task_text TEXT,
			state TEXT,
			journal_file TEXT,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP
		)
	]])
	
	-- Run database migrations
	M._run_database_migrations(db)
	
	-- Create indexes (parent_id index created in migration if needed)
	db:execute("CREATE INDEX IF NOT EXISTS idx_task_id ON task_events(task_id)")
	db:execute("CREATE INDEX IF NOT EXISTS idx_event_type ON task_events(event_type)")
	db:execute("CREATE INDEX IF NOT EXISTS idx_timestamp ON task_events(timestamp)")
	
	-- Cache connection
	task_db_cache[track_type] = db
	cached_db_paths[track_type] = db_path
	
	return db
end

-- Parse task URI to extract UUID and optional parent UUID
-- Supports formats: "uuid" or "uuid?parent=parent_uuid"
-- @param task_uri: the URI part after "task://"
-- @return: task_uuid, parent_uuid (parent_uuid is nil if not present)
function M._parse_task_uri(task_uri)
	if not task_uri or task_uri == "" then
		return nil, nil
	end
	
	-- Check for query parameters
	local uuid_part, query_part = task_uri:match("^([%w%-]+)%?(.+)$")
	
	if uuid_part and query_part then
		-- Parse query parameters
		local parent_uuid = query_part:match("parent=([%w%-]+)")
		return uuid_part, parent_uuid
	else
		-- No query parameters, just return the UUID
		if task_uri:match("^[%w%-]+$") then
			return task_uri, nil
		else
			return nil, nil
		end
	end
end

-- Determine tracking type from filename
function M._get_tracking_type(filepath)
	local filename = vim.fn.fnamemodify(filepath, ":t")
	
	for track_type, track_config in pairs(config.tracking) do
		if track_config.enabled then
			for _, pattern in ipairs(track_config.filename_patterns) do
				if filename:match(pattern) then
					return track_type
				end
			end
		end
	end
	
	return nil
end

-- Track tasks on file save (simplified version of the original complex logic)
function M._track_tasks_on_save(bufnr)
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	local track_type = M._get_tracking_type(filepath)
	
	if not track_type then
		return
	end
	
	local db = M._get_task_database(track_type)
	if not db then
		return
	end
	
	-- Get tasks from buffer (simplified parsing)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = {}
	local new_tasks = 0
	local updated_tasks = 0
	local completed_tasks = 0
	
	for line_num, line_content in ipairs(lines) do
		-- First check if line contains a task URI (this is the only guaranteed part)
		local task_uri = line_content:match("task://([^%)]+)")
		
		if task_uri then
			-- Now extract the task state and text (we know there's a URI, so this should work)
			local state, task_text = line_content:match("^%s*%- %[([%-%sx ]?)%] (.-)%s%[")
			
			if state and task_text then
				-- Parse the URI to extract task_uuid and optional parent_uuid
				local task_uuid, parent_uuid = M._parse_task_uri(task_uri)
				
				if task_uuid then
					-- Normalize state: trim whitespace and handle empty/space as CREATED
					state = (state or ""):gsub("^%s*(.-)%s*$", "%1")
					
					local task_state = "CREATED"
					if state == "x" or state == "X" then
						task_state = "FINISHED"
					elseif state == "-" then
						task_state = "IN_PROGRESS"
					end
					
					table.insert(tasks, {
						uuid = task_uuid,
						parent_uuid = parent_uuid,
						text = task_text:gsub("^%s+", ""):gsub("%s+$", ""),
						state = task_state,
						line_number = line_num
					})
				end
			end
		end
	end
	
	-- Process tasks (simplified - just save new/changed tasks)
	for _, task in ipairs(tasks) do
		-- Check if task exists and get last known state
		local existing = db:eval("SELECT COUNT(*) as count, state, task_text FROM task_events WHERE task_id = ? ORDER BY timestamp DESC LIMIT 1", {task.uuid})
		
		if not existing or #existing == 0 or existing[1].count == 0 then
			-- New task
			db:eval([[
				INSERT INTO task_events (task_id, event_type, timestamp, task_text, state, journal_file, parent_id)
				VALUES (?, ?, ?, ?, ?, ?, ?)
			]], {task.uuid, "task_created", os.date("%Y-%m-%d %H:%M:%S"), task.text, task.state, filepath, task.parent_uuid})
			new_tasks = new_tasks + 1
		else
			-- Check if state or text changed
			local last_state = existing[1].state
			local last_text = existing[1].task_text
			
			-- Normalize for comparison (trim whitespace)
			local current_text = task.text:gsub("^%s+", ""):gsub("%s+$", "")
			local stored_text = (last_text or ""):gsub("^%s+", ""):gsub("%s+$", "")
			
			local state_changed = last_state ~= task.state
			local text_changed = stored_text ~= current_text
			
			if state_changed or text_changed then
				local event_type = "task_updated"
				if task.state == "FINISHED" and last_state ~= "FINISHED" then
					event_type = "task_completed"
					completed_tasks = completed_tasks + 1
				elseif task.state ~= "FINISHED" and last_state == "FINISHED" then
					event_type = "task_reopened" 
				end
				
				db:eval([[
					INSERT INTO task_events (task_id, event_type, timestamp, task_text, state, journal_file, parent_id)
					VALUES (?, ?, ?, ?, ?, ?, ?)
				]], {task.uuid, event_type, os.date("%Y-%m-%d %H:%M:%S"), task.text, task.state, filepath, task.parent_uuid})
				updated_tasks = updated_tasks + 1
			end
		end
	end
	
	-- Show summary notification
	if new_tasks > 0 or updated_tasks > 0 or completed_tasks > 0 then
		local filename = vim.fn.fnamemodify(filepath, ":t")
		local messages = {}
		
		if new_tasks > 0 then
			table.insert(messages, string.format("📝 %d new task%s", new_tasks, new_tasks == 1 and "" or "s"))
		end
		if completed_tasks > 0 then
			table.insert(messages, string.format("✅ %d completed", completed_tasks))
		end
		if updated_tasks > 0 and completed_tasks ~= updated_tasks then
			table.insert(messages, string.format("🔄 %d updated", updated_tasks - completed_tasks))
		end
		
		local summary = table.concat(messages, ", ")
		notify(string.format("%s in %s", summary, filename), "info", "task_operations")
	end
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📝 JOURNAL HELPERS
-- ═══════════════════════════════════════════════════════════════════════

function M._create_journal_helpers()
	local helpers = {}
	
	function helpers.get_most_recent_journal_note(target_dir, prefix)
		local handle = vim.loop.fs_scandir(target_dir)
		if not handle then return nil end
		
		local files = {}
		while true do
			local name, typ = vim.loop.fs_scandir_next(handle)
			if not name then break end
			
			if typ == "file" and name:match("^" .. prefix .. "%-%d%d%d%d%-%d%d%-%d%d%.md$") then
				table.insert(files, name)
			end
		end
		
		table.sort(files, function(a, b) return a > b end)
		
		if #files == 0 then return nil end
		return target_dir .. "/" .. files[1]
	end
	
	function helpers.read_file(path)
		local file = io.open(path, "r")
		if not file then return nil end
		local content = file:read("*all")
		file:close()
		return content
	end
	
	function helpers.extract_unfinished_tasks(content, section)
		local escaped_section = section:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
		local section_start = content:find("## " .. escaped_section)
		if not section_start then return {} end
		
		local content_start = content:find("\n", section_start)
		if not content_start then return {} end
		content_start = content_start + 1
		
		local next_section_start = content:find("\n## ", content_start)
		local section_content = next_section_start and 
			content:sub(content_start, next_section_start - 1) or 
			content:sub(content_start)
		
		section_content = section_content:gsub("^%s+", ""):gsub("%s+$", "")
		
		local tasks = {}
		if section_content == "" then return tasks end
		
		for line in (section_content .. "\n"):gmatch("(.-)\n") do
			line = line:gsub("^%s+", ""):gsub("%s+$", "")
			if line:match("^%- %[ %]") or line:match("^%- %[%-%]") then
				table.insert(tasks, line)
			end
		end
		
		return tasks
	end
	
	return helpers
end

function M._create_journal_content_with_carryover(target_dir, journal_type)
	if not config.journal.carryover_enabled then
		return M._create_basic_journal_content(journal_type)
	end
	
	local helpers = M._create_journal_helpers()
	local journal_config = config.journal.daily_template[journal_type]
	local prev_path = helpers.get_most_recent_journal_note(target_dir, journal_config.prefix)
	
	local section_tasks = {}
	local total_carried_tasks = 0
	
	if prev_path then
		local prev_content = helpers.read_file(prev_path)
		if prev_content then
			for _, section in ipairs(journal_config.sections) do
				local tasks = helpers.extract_unfinished_tasks(prev_content, section)
				section_tasks[section] = tasks
				total_carried_tasks = total_carried_tasks + (tasks and #tasks or 0)
			end
		end
	end
	
	-- Record carryover events in database and show notification
	if total_carried_tasks > 0 and prev_path then
		local prev_filename = vim.fn.fnamemodify(prev_path, ":t")
		
		-- Track carryover events in database for analytics
		M._record_carryover_events(section_tasks, journal_type, prev_filename)
		
		notify(string.format("📦 Carried over %d unfinished task%s from %s", 
			total_carried_tasks, 
			total_carried_tasks == 1 and "" or "s", 
			prev_filename), "info", "journal_carryover")
	end
	
	-- Generate only body content - ZK handles frontmatter via ~/.config/zk templates  
	local content_parts = {}
	
	for _, section in ipairs(journal_config.sections) do
		table.insert(content_parts, "## " .. section)
		local tasks = section_tasks[section]
		if tasks and #tasks > 0 then
			table.insert(content_parts, table.concat(tasks, "\n"))
			table.insert(content_parts, "")
		else
			table.insert(content_parts, "")
		end
	end
	
	return table.concat(content_parts, "\n")
end

-- Record carryover events in database for analytics
function M._record_carryover_events(section_tasks, journal_type, prev_filename)
	-- Get the appropriate tracking type for this journal type
	local track_type = journal_type == "work" and "work" or "personal"
	local db = M._get_task_database(track_type)
	
	if not db then
		return  -- Silently skip if no database available
	end
	
	-- Record each carried over task as a database event
	for section, tasks in pairs(section_tasks) do
		if tasks and #tasks > 0 then
			for _, task_line in ipairs(tasks) do
				-- Extract task UUID and parent UUID if present
				local task_uri = task_line:match("%(task://([^%)]+)%)")
				local task_uuid, parent_uuid = nil, nil
				
				if task_uri then
					task_uuid, parent_uuid = M._parse_task_uri(task_uri)
				end
				
				if not task_uuid then
					-- Generate UUID for tasks that don't have one
					task_uuid = utils.generate_uuid_v7()
				end
				
				-- Extract task text (remove checkbox and UUID parts)
				local task_text = task_line:gsub("^%s*%- %[.-%] ", "")
				                           :gsub("%s*%[ %]%(task://[^%)]*%)%s*$", "")
				
				-- Record the carryover event
				db:eval([[
					INSERT INTO task_events (task_id, event_type, timestamp, task_text, state, journal_file, parent_id)
					VALUES (?, ?, ?, ?, ?, ?, ?)
				]], {
					task_uuid, 
					"task_carried_over", 
					os.date("%Y-%m-%d %H:%M:%S"), 
					task_text, 
					"CARRIED_OVER", 
					prev_filename,
					parent_uuid
				})
			end
		end
	end
	
	-- No need for summary records - analytics aggregate individual records at query time
end


function M._create_basic_journal_content(journal_type)
	local journal_config = config.journal.daily_template[journal_type]
	
	-- Generate only body content - ZK handles frontmatter via ~/.config/zk templates
	local content_parts = {}
	
	for _, section in ipairs(journal_config.sections) do
		table.insert(content_parts, "## " .. section)
		table.insert(content_parts, "")
	end
	
	return table.concat(content_parts, "\n")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🎯 TASK PICKER (MINI.PICK INTEGRATION)  
-- ═══════════════════════════════════════════════════════════════════════

-- Get available parent tasks for picker
-- @param track_type: "personal" or "work"
-- @return: table with picker items
function M._get_picker_parent_tasks(track_type)
	local db = M._get_task_database(track_type)
	if not db then
		return {}
	end
	
	-- Get recent tasks that could be parents (not completed, from last 30 days)
	-- Group by task_id to avoid duplicates, getting the most recent event for each task
	local sql = [[
		SELECT te.task_id, te.task_text, te.timestamp, te.state
		FROM task_events te
		INNER JOIN (
			SELECT task_id, MAX(timestamp) as max_timestamp
			FROM task_events
			WHERE event_type IN ('task_created', 'task_updated')
			  AND state != 'FINISHED'
			  AND date(timestamp) >= date('now', '-30 days')
			  AND task_text IS NOT NULL
			  AND task_text != ''
			GROUP BY task_id
		) latest ON te.task_id = latest.task_id AND te.timestamp = latest.max_timestamp
		WHERE te.event_type IN ('task_created', 'task_updated')
		ORDER BY te.timestamp DESC
		LIMIT 20
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return {}
	end
	
	local items = {}
	for _, row in ipairs(results) do
		local truncated_uuid = row.task_id:sub(1, 8)
		local task_preview = row.task_text:sub(1, 50)
		if #row.task_text > 50 then
			task_preview = task_preview .. "..."
		end
		
		local state_emoji = row.state == "IN_PROGRESS" and "🚀" or "📝"
		local display = string.format("%s %s %s", truncated_uuid, state_emoji, task_preview)
		
		table.insert(items, {
			text = display,
			uuid = row.task_id,
			task_text = row.task_text,
			state = row.state
		})
	end
	
	return items
end

-- Show parent task picker with subtle bottom-left positioning
-- @param callback: function(selected_uuid) called when task is selected
function M._show_parent_task_picker(callback)
	-- Determine track type from current context
	local track_type = "personal" -- Default fallback
	local current_file = vim.api.nvim_buf_get_name(0)
	
	-- Try to determine track type from filename patterns
	if current_file and current_file ~= "" then
		for track, track_config in pairs(config.tracking or {}) do
			if track_config.filename_patterns then
				for _, pattern in ipairs(track_config.filename_patterns) do
					local lua_pattern = pattern:gsub("%-", "%%-"):gsub("%*", ".*")
					if current_file:match(lua_pattern) then
						track_type = track
						break
					end
				end
				if track_type ~= "personal" then break end
			end
		end
	end
	
	local items = M._get_picker_parent_tasks(track_type)
	
	if #items == 0 then
		notify("📝 No recent tasks found to use as parent", "warn", "task_operations")
		return
	end
	
	
	-- Start picker with proper config
	local MiniPick = require('mini.pick')
	MiniPick.start({
		source = {
			name = "Parent Tasks",
			items = items,
			choose = function(item)
				if item and item.uuid then
					callback(item.uuid)
				end
			end
		},
		window = {
			config = function()
				local height = math.min(6, #items + 2) -- Compact but readable
				local width = 45 -- Enough for truncated UUID + task text
				-- Calculate position for truly bottom-left
				local has_tabline = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
				local has_statusline = vim.o.laststatus > 0
				local max_height = vim.o.lines - vim.o.cmdheight - (has_tabline and 1 or 0) - (has_statusline and 1 or 0)
				
				return {
					relative = "editor",
					anchor = "SW", -- Southwest (bottom-left)
					height = height,
					width = width,
					row = max_height + (has_tabline and 1 or 0), -- At bottom
					col = 0, -- At left edge
					border = Utils.ui.border,
					style = "minimal"
				}
			end
		}
	})
end

-- ═══════════════════════════════════════════════════════════════════════
-- ⌨️ COMMANDS SETUP
-- ═══════════════════════════════════════════════════════════════════════

function M._setup_commands()
	-- Only set up commands if zk is available
	if not M.zk then
		return
	end
	
	local commands = require("zk.commands")
	
	-- Note creation commands
	commands.add("ZkNewAtDir", function(options)
		-- Directory picker implementation (simplified)
		local dir = vim.fn.input("Directory: ", config.directories.notebook)
		if dir == "" then return end
		
		local title = vim.fn.input("Title: ")
		if title == "" then return end
		
		M.zk.new({ dir = dir, title = title })
	end)
	
	-- Journal commands
	commands.add("ZkNewDailyJournal", function(options)
		local dir = vim.fn.input("Journal directory: ", config.directories.personal_journal)
		if dir == "" then return end
		
		local journal_config = config.journal.daily_template.personal
		local date = os.date("%Y-%m-%d")
		local title = journal_config.prefix .. "-" .. date
		local target_dir = config.directories.notebook .. "/" .. dir
		local content = M._create_journal_content_with_carryover(target_dir, "personal")
		
		M.zk.new({ dir = dir, title = title, content = content })
	end)
	
	commands.add("ZkNewWorkJournal", function(options)
		local dir = vim.fn.input("Work journal directory: ", config.directories.work_journal) 
		if dir == "" then return end
		
		local journal_config = config.journal.daily_template.work
		local date = os.date("%Y-%m-%d")
		local title = journal_config.prefix .. "-" .. date
		local target_dir = config.directories.notebook .. "/" .. dir
		local content = M._create_journal_content_with_carryover(target_dir, "work")
		
		M.zk.new({ dir = dir, title = title, content = content })
	end)
	
	-- Task creation
	commands.add("ZkNewTask", function(options)
		local uuid = M._generate_uuid()
		local parent_uuid = options and options.args
		
		local task_uri = "task://" .. uuid
		if parent_uuid and parent_uuid ~= "" then
			task_uri = task_uri .. "?parent=" .. parent_uuid
		end
		
		local task_line = string.format("- [ ]  [ ](%s)", task_uri)
		local current_line = vim.api.nvim_win_get_cursor(0)[1]
		vim.api.nvim_buf_set_lines(0, current_line, current_line, false, {task_line})
		-- Position cursor right after "- [ ] " (position 6) where task text should go  
		vim.api.nvim_win_set_cursor(0, {current_line + 1, 6})
		vim.cmd("startinsert")
	end)
	
	-- Child task creation - creates a task under a parent
	commands.add("ZkNewChildTask", function()
		M._show_parent_task_picker(function(parent_uuid)
			if not parent_uuid then return end
			
			local uuid = M._generate_uuid()
			local task_uri = string.format("task://%s?parent=%s", uuid, parent_uuid)
			
			-- Get the target window and buffer from picker state
			local MiniPick = require('mini.pick')
			local picker_state = MiniPick.get_picker_state()
			local target_win = picker_state.windows.target
			local target_buf = vim.api.nvim_win_get_buf(target_win)
			
			-- Get cursor position from target window
			local current_line_num = vim.api.nvim_win_get_cursor(target_win)[1] -- 1-based line number
			
			-- Get the parent task line to determine indentation
			local parent_line = vim.api.nvim_buf_get_lines(target_buf, current_line_num - 1, current_line_num, false)[1] or ""
			
			-- Extract existing indentation from parent line
			local parent_indent = parent_line:match("^(%s*)") or ""
			
			-- Add 2 spaces for child indentation (standard markdown practice)
			local child_indent = parent_indent .. "  "
			
			-- Create child task line with proper indentation
			local task_line = string.format("%s- [ ]  [ ](%s)", child_indent, task_uri)
			
			-- Insert child task on the line AFTER the current line in target buffer
			vim.api.nvim_buf_set_lines(target_buf, current_line_num, current_line_num, false, {task_line})
			
			-- Position cursor on the newly inserted line in target window, at the right position for task text
			-- Account for the indentation + "- [ ] " = indent + 6 characters
			local cursor_col = #child_indent + 6
			vim.api.nvim_win_set_cursor(target_win, {current_line_num + 1, cursor_col})
			
			-- Set target window as current and enter insert mode
			vim.api.nvim_set_current_win(target_win)
			vim.cmd("startinsert")
		end)
	end)
	
	-- Show task hierarchy
	commands.add("ZkTaskHierarchy", function(options)
		local args = options and options.args or ""
		local parts = vim.split(args, " ", {trimempty = true})
		local track_type = parts[1] or "personal"
		local root_uuid = parts[2]
		
		if not root_uuid or root_uuid == "" then
			root_uuid = vim.fn.input("Root task UUID: ")
			if root_uuid == "" then
				vim.notify("❌ Root UUID is required", vim.log.levels.WARN)
				return
			end
		end
		
		M.show_task_hierarchy(track_type, root_uuid)
	end)
	
	-- Visualization commands (only if visualization is enabled)
	if config.visualization.enabled then
		commands.add("ZkTaskStats", function(options)
			local track_type = (options and options.args) or "personal"
			M.dashboard(track_type)
		end)
		
		commands.add("ZkTaskCompletions", function(options)
			local days = tonumber((options and options.args) or "7")
			M.daily_completions("personal", days)
		end)
		
		commands.add("ZkWorkStats", function()
			M.dashboard("work")
		end)
		
		commands.add("ZkTaskStates", function(options)
			local track_type = (options and options.args) or "personal"
			M.task_states(track_type)
		end)
		
		commands.add("ZkTaskTrend", function(options)
			local days = tonumber((options and options.args) or "14")
			M.productivity_trend("personal", days)
		end)
		
		commands.add("ZkTaskActivity", function()
			M.recent_activity("personal")
		end)
	end
	
	-- Help and utility commands
	commands.add("ZkNotesHelp", function()
		M.help()
	end)
	
	commands.add("ZkNotesHealth", function()
		M.health()
	end)
	
	commands.add("ZkNotesConfig", function()
		M.config()
	end)
	
	commands.add("ZkNotesExamples", function()
		M.examples()
	end)
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- 📊 STATS & DASHBOARD COMMANDS (Perfect for mini.starter!)
	-- ═══════════════════════════════════════════════════════════════════════
	
	-- Quick dashboard commands
	commands.add("ZkDashboard", function(options)
		local track_type = (options and options.args) or "personal"
		M.dashboard(track_type)
	end, { nargs = "?", desc = "Show notes dashboard for track type" })
	
	commands.add("ZkPersonalDashboard", function()
		M.dashboard("personal")
	end, { desc = "Show personal notes dashboard" })
	
	commands.add("ZkWorkDashboard", function() 
		M.dashboard("work")
	end, { desc = "Show work notes dashboard" })
	
	-- Specialized dashboard commands
	commands.add("ZkToday", function(options)
		local track_type = (options and options.args) or "personal"
		M.today_dashboard(track_type)
	end, { nargs = "?", desc = "Today's focus dashboard with hourly insights" })
	
	commands.add("ZkYesterday", function(options)
		local track_type = (options and options.args) or "personal"
		M.previous_day_dashboard(track_type)
	end, { nargs = "?", desc = "Smart previous working day review" })
	
	commands.add("ZkWeekly", function(options)
		local track_type = (options and options.args) or "personal"
		M.weekly_dashboard(track_type)
	end, { nargs = "?", desc = "Weekly productivity trends and day patterns" })
	
	commands.add("ZkLastWeek", function(options)
		local track_type = (options and options.args) or "personal"
		print("📊 Last Week's Productivity (" .. track_type .. ")")
		M.productivity_trend(7, track_type) -- Last 7 days
		print("\n" .. string.rep("═", 60))
		M.daily_completions(7, track_type) -- Last 7 days completions
	end, { nargs = "?", desc = "Show last week's productivity summary" })
	
	-- Friday review special command
	commands.add("ZkFridayReview", function()
		M.friday_dashboard("combined")
	end, { desc = "Complete Friday review with achievements and insights" })
	
	-- Quick stats commands
	commands.add("ZkQuickStats", function(options)
		local track_type = (options and options.args) or "personal"
		print("⚡ Quick Stats (" .. track_type .. ")")
		M.task_states(track_type)
		M.recent_activity(track_type)
	end, { nargs = "?", desc = "Show quick task statistics" })
	
end

-- UUID v7 generation (time-ordered, replaces old UUID v4)
function M._generate_uuid()
	return utils.generate_uuid_v7()
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🔗 PARENT-CHILD TASK RELATIONSHIP UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

-- Get child tasks for a parent task
-- @param track_type: "personal", "work", etc.
-- @param parent_uuid: UUID of the parent task
-- @return: array of child task data
function M.get_child_tasks(track_type, parent_uuid)
	track_type = track_type or "personal"
	
	local db = M._get_task_database(track_type)
	if not db then
		return {}
	end
	
	local sql = [[
		SELECT DISTINCT task_id, task_text, state
		FROM task_events
		WHERE parent_id = ?
		ORDER BY timestamp DESC
	]]
	
	local results = db:eval(sql, {parent_uuid})
	return results or {}
end

-- Get parent task for a child task
-- @param track_type: "personal", "work", etc.
-- @param child_uuid: UUID of the child task
-- @return: parent task data or nil
function M.get_parent_task(track_type, child_uuid)
	track_type = track_type or "personal"
	
	local db = M._get_task_database(track_type)
	if not db then
		return nil
	end
	
	local sql = [[
		SELECT DISTINCT te1.task_id as parent_id, te1.task_text, te1.state
		FROM task_events te1
		JOIN task_events te2 ON te1.task_id = te2.parent_id
		WHERE te2.task_id = ?
		ORDER BY te1.timestamp DESC
		LIMIT 1
	]]
	
	local results = db:eval(sql, {child_uuid})
	return results and results[1] or nil
end

-- Get task hierarchy (parent with all descendants)
-- @param track_type: "personal", "work", etc.
-- @param root_uuid: UUID of the root task
-- @return: hierarchical task structure
function M.get_task_hierarchy(track_type, root_uuid)
	track_type = track_type or "personal"
	
	local function build_hierarchy(parent_uuid, level)
		level = level or 0
		if level > 10 then  -- Prevent infinite recursion
			return {}
		end
		
		local children = M.get_child_tasks(track_type, parent_uuid)
		local hierarchy = {}
		
		for _, child in ipairs(children) do
			table.insert(hierarchy, {
				task_id = child.task_id,
				task_text = child.task_text,
				state = child.state,
				level = level,
				children = build_hierarchy(child.task_id, level + 1)
			})
		end
		
		return hierarchy
	end
	
	-- Get root task info
	local db = M._get_task_database(track_type)
	if not db then
		return nil
	end
	
	local root_sql = [[
		SELECT DISTINCT task_id, task_text, state
		FROM task_events
		WHERE task_id = ?
		ORDER BY timestamp DESC
		LIMIT 1
	]]
	
	local root_results = db:eval(root_sql, {root_uuid})
	if not root_results or #root_results == 0 then
		return nil
	end
	
	local root_task = root_results[1]
	return {
		task_id = root_task.task_id,
		task_text = root_task.task_text,
		state = root_task.state,
		level = 0,
		children = build_hierarchy(root_uuid, 1)
	}
end

-- Display task hierarchy in a formatted way
function M.show_task_hierarchy(track_type, root_uuid)
	local hierarchy = M.get_task_hierarchy(track_type, root_uuid)
	
	if not hierarchy then
		print("❌ Task not found: " .. root_uuid)
		return
	end
	
	local function print_task(task, indent)
		indent = indent or ""
		local state_emoji = task.state == "FINISHED" and "✅" or 
		                   task.state == "IN_PROGRESS" and "🚀" or "📝"
		
		print(indent .. state_emoji .. " " .. (task.task_text or "Unknown task") .. " (" .. task.task_id:sub(1, 8) .. ")")
		
		for _, child in ipairs(task.children or {}) do
			print_task(child, indent .. "  ")
		end
	end
	
	print("🌳 TASK HIERARCHY - " .. string.upper(track_type))
	print("═" .. string.rep("═", 40))
	print_task(hierarchy)
	print("")
end


-- ═══════════════════════════════════════════════════════════════════════
-- ⌨️ KEYMAPS SETUP  
-- ═══════════════════════════════════════════════════════════════════════

function M._setup_keymaps()
	local prefix = config.keymaps.prefix
	local mappings = config.keymaps.mappings or {}
	local opts = { noremap = true, silent = false }
	
	-- Note creation
	if mappings.new_note then
		vim.keymap.set("n", prefix .. mappings.new_note, 
			"<Cmd>ZkNew { title = vim.fn.input('Title: ') }<CR>", 
			vim.tbl_extend("force", opts, { desc = "New note" }))
	end
	
	if mappings.new_at_dir then
		vim.keymap.set("n", prefix .. mappings.new_at_dir, 
			"<Cmd>ZkNewAtDir<CR>", 
			vim.tbl_extend("force", opts, { desc = "New note at directory" }))
	end
	
	if mappings.new_task then
		vim.keymap.set("n", prefix .. mappings.new_task, 
			"<Cmd>ZkNewTask<CR>", 
			vim.tbl_extend("force", opts, { desc = "New task" }))
	end
	
	if mappings.new_child_task then
		vim.keymap.set("n", prefix .. mappings.new_child_task, 
			"<Cmd>ZkNewChildTask<CR>", 
			vim.tbl_extend("force", opts, { desc = "New child task" }))
	end
	
	
	-- Journal creation
	if mappings.daily_journal then
		vim.keymap.set("n", prefix .. mappings.daily_journal, 
			"<Cmd>ZkNewDailyJournal<CR>", 
			vim.tbl_extend("force", opts, { desc = "New daily journal" }))
	end
	
	if mappings.work_journal then
		vim.keymap.set("n", prefix .. mappings.work_journal, 
			"<Cmd>ZkNewWorkJournal<CR>", 
			vim.tbl_extend("force", opts, { desc = "New work journal" }))
	end
	
	-- Note browsing
	if mappings.open_notes then
		vim.keymap.set("n", prefix .. mappings.open_notes, 
			"<Cmd>ZkNotes { sort = { 'modified' } }<CR>", 
			vim.tbl_extend("force", opts, { desc = "Open notes" }))
	end
	
	if mappings.find_notes then
		vim.keymap.set("n", prefix .. mappings.find_notes, 
			"<Cmd>ZkNotes { sort = { 'modified' }, match = { vim.fn.input('Search: ') } }<CR>", 
			vim.tbl_extend("force", opts, { desc = "Find notes" }))
	end
	
	if mappings.browse_tags then
		vim.keymap.set("n", prefix .. mappings.browse_tags, 
			"<Cmd>ZkTags<CR>", 
			vim.tbl_extend("force", opts, { desc = "Browse tags" }))
	end
	
	-- Visualization keymaps (only if enabled)
	if config.visualization.enabled then
		-- 📊 Stats & Dashboards (Quick Access!)
		if mappings.dashboard then
			vim.keymap.set("n", prefix .. mappings.dashboard, 
				"<Cmd>ZkPersonalDashboard<CR>", 
				vim.tbl_extend("force", opts, { desc = "Personal dashboard" }))
		end
		
		if mappings.work_dashboard then
			vim.keymap.set("n", prefix .. mappings.work_dashboard, 
				"<Cmd>ZkWorkDashboard<CR>", 
				vim.tbl_extend("force", opts, { desc = "Work dashboard" }))
		end
		
		if mappings.today then
			vim.keymap.set("n", prefix .. mappings.today, 
				"<Cmd>ZkToday<CR>", 
				vim.tbl_extend("force", opts, { desc = "Today's overview" }))
		end
		
		if mappings.yesterday then
			vim.keymap.set("n", prefix .. mappings.yesterday, 
				"<Cmd>ZkYesterday<CR>", 
				vim.tbl_extend("force", opts, { desc = "Yesterday's activity" }))
		end
		
		if mappings.weekly then
			vim.keymap.set("n", prefix .. mappings.weekly, 
				"<Cmd>ZkWeekly<CR>", 
				vim.tbl_extend("force", opts, { desc = "Weekly overview" }))
		end
		
		if mappings.last_week then
			vim.keymap.set("n", prefix .. mappings.last_week, 
				"<Cmd>ZkLastWeek<CR>", 
				vim.tbl_extend("force", opts, { desc = "Last week summary" }))
		end
		
		if mappings.friday_review then
			vim.keymap.set("n", prefix .. mappings.friday_review, 
				"<Cmd>ZkFridayReview<CR>", 
				vim.tbl_extend("force", opts, { desc = "Friday weekly review" }))
		end
		
		if mappings.quick_stats then
			vim.keymap.set("n", prefix .. mappings.quick_stats, 
				"<Cmd>ZkQuickStats<CR>", 
				vim.tbl_extend("force", opts, { desc = "Quick task statistics" }))
		end
		
		-- Detailed Visualization (existing enhanced)
		if mappings.task_stats then
			vim.keymap.set("n", prefix .. mappings.task_stats, 
				"<Cmd>ZkTaskStats<CR>", 
				vim.tbl_extend("force", opts, { desc = "Detailed task statistics" }))
		end
		
		if mappings.task_completions then
			vim.keymap.set("n", prefix .. mappings.task_completions, 
				"<Cmd>ZkTaskCompletions<CR>", 
				vim.tbl_extend("force", opts, { desc = "Task completions" }))
		end
		
		if mappings.work_stats then
			vim.keymap.set("n", prefix .. mappings.work_stats, 
				"<Cmd>ZkWorkStats<CR>", 
				vim.tbl_extend("force", opts, { desc = "Work task statistics" }))
		end
		
		-- Add more visualization keymaps...
	end
	
	-- Help system keymaps
	if mappings.help == nil or mappings.help then  -- Default enabled unless explicitly disabled
		vim.keymap.set("n", prefix .. "?", 
			"<Cmd>ZkNotesHelp<CR>", 
			vim.tbl_extend("force", opts, { desc = "📖 Notes help" }))
	end
	
	if mappings.health == nil or mappings.health then  -- Default enabled unless explicitly disabled
		vim.keymap.set("n", prefix .. "h", 
			"<Cmd>ZkNotesHealth<CR>", 
			vim.tbl_extend("force", opts, { desc = "🏥 System health" }))
	end
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📊 VISUALIZATION API (from original module)
-- ═══════════════════════════════════════════════════════════════════════

-- Only include visualization functions if enabled
function M._ensure_visualization_enabled()
	if not config.visualization.enabled then
		print("❌ Visualization is disabled. Enable it in setup() config.")
		return false
	end
	return true
end

-- Show daily completion histogram
function M.daily_completions(track_type, days, opts)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal"
	days = tonumber(days) or 7
	
	local db = M._get_task_database(track_type)
	if not db then
		print("❌ Database not available for " .. track_type .. " tasks")
		return
	end
	
	local sql = string.format([[
		SELECT 
			date(timestamp) as day,
			COUNT(*) as count
		FROM task_events 
		WHERE event_type = 'task_completed' 
			AND date(timestamp) >= date('now', '-%d days')
		GROUP BY date(timestamp)
		ORDER BY day
	]], days)
	
	local results = db:eval(sql)
	
	-- Fix: Check if results is valid and is a table before getting length
	if not results or type(results) ~= "table" or #results == 0 then
		print("📊 No completion data found for the last " .. days .. " days")
		return
	end
	
	-- Convert to chart data
	local chart_data = utils.sql_to_chart_data(results, "day", "count")
	
	-- Format dates
	if config.visualization.data.date_format ~= "raw" then
		for _, item in ipairs(chart_data) do
			item.label = utils.format_date(item.label, config.visualization.data.date_format)
		end
	end
	
	-- Create chart
	local chart_opts = deep_merge(config.visualization.charts.histogram, opts or {})
	chart_opts.title = string.format("📊 Daily Completions - %s (%d days)", 
		string.upper(track_type), days)
	
	local chart = plot.histogram(chart_data, chart_opts)
	
	-- Display
	for _, line in ipairs(chart) do
		print(line)
	end
end

-- Show task state distribution pie chart
function M.task_states(track_type, opts)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal"
	
	local db = M._get_task_database(track_type)
	if not db then
		print("❌ Database not available for " .. track_type .. " tasks")
		return
	end
	
	local sql = [[
		WITH latest_states AS (
			SELECT 
				task_id,
				state,
				ROW_NUMBER() OVER (PARTITION BY task_id ORDER BY timestamp DESC, event_id DESC) as rn
			FROM task_events
		)
		SELECT 
			state,
			COUNT(*) as count
		FROM latest_states 
		WHERE rn = 1 AND state != 'DELETED'
		GROUP BY state
		ORDER BY count DESC
	]]
	
	local results = db:eval(sql)
	
	-- Fix: Check if results is valid and is a table before getting length
	if not results or type(results) ~= "table" or #results == 0 then
		print("🥧 No task state data found")
		return
	end
	
	-- Convert to chart data with emojis
	local chart_data = {}
	for _, row in ipairs(results) do
		local label = config.visualization.display.use_emojis and 
			utils.add_state_emoji(row.state) or 
			tostring(row.state)
		
		table.insert(chart_data, {
			label = label,
			value = tonumber(row.count)
		})
	end
	
	-- Create chart
	local chart_opts = deep_merge(config.visualization.charts.pie_chart, opts or {})
	chart_opts.title = string.format("🥧 Task States - %s", string.upper(track_type))
	
	local chart = plot.pie_chart(chart_data, chart_opts)
	
	-- Display
	for _, line in ipairs(chart) do
		print(line)
	end
end

-- Show productivity trend over time
function M.productivity_trend(track_type, days, opts)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal"
	days = tonumber(days) or 14
	
	local db = M._get_task_database(track_type)
	if not db then
		print("❌ Database not available for " .. track_type .. " tasks")
		return
	end
	
	local sql = string.format([[
		WITH daily_stats AS (
			SELECT 
				date(timestamp) as day,
				SUM(CASE WHEN event_type = 'task_created' THEN 1 ELSE 0 END) as created,
				SUM(CASE WHEN event_type = 'task_completed' THEN 1 ELSE 0 END) as completed
			FROM task_events 
			WHERE date(timestamp) >= date('now', '-%d days')
			GROUP BY date(timestamp)
			ORDER BY day
		)
		SELECT 
			day,
			(completed * %d + created * %d) as productivity_score
		FROM daily_stats
	]], days, 
	config.visualization.data.productivity_weights.completed,
	config.visualization.data.productivity_weights.created)
	
	local results = db:eval(sql)
	
	-- Fix: Check if results is valid and is a table before getting length
	if not results or type(results) ~= "table" or #results == 0 then
		print("📈 No productivity data found for the last " .. days .. " days")
		return
	end
	
	-- Convert to chart data
	local chart_data = utils.sql_to_chart_data(results, "day", "productivity_score")
	
	-- Format dates
	if config.visualization.data.date_format ~= "raw" then
		for _, item in ipairs(chart_data) do
			item.label = utils.format_date(item.label, "short")  -- Use short format for trends
		end
	end
	
	-- Create line plot
	local chart_opts = deep_merge(config.visualization.charts.line_plot, opts or {})
	chart_opts.title = string.format("📈 Productivity Trend - %s (%d days)", 
		string.upper(track_type), days)
	
	local chart = plot.line_plot(chart_data, chart_opts)
	
	-- Display
	for _, line in ipairs(chart) do
		print(line)
	end
end

-- Show recent activity table
function M.recent_activity(track_type, opts)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal"
	opts = opts or {}
	local limit = opts.limit or 10
	
	local db = M._get_task_database(track_type)
	if not db then
		print("❌ Database not available for " .. track_type .. " tasks")
		return
	end
	
	local sql = string.format([[
		SELECT 
			datetime(timestamp) as time,
			event_type,
			SUBSTR(task_text, 1, %d) as task_preview,
			state
		FROM task_events 
		ORDER BY timestamp DESC
		LIMIT %d
	]], config.visualization.data.truncate_length, limit)
	
	local results = db:eval(sql)
	
	-- Fix: Check if results is valid and is a table before getting length
	if not results or type(results) ~= "table" or #results == 0 then
		print("📋 No recent activity found")
		return
	end
	
	-- Convert to table data
	local table_data = utils.sql_to_table_data(results, {
		{"time", "Time"},
		{"event_type", "Event"},
		{"task_preview", "Task"},
		{"state", "State"}
	})
	
	-- Add emojis to events
	for _, row in ipairs(table_data.rows) do
		if config.visualization.display.use_emojis then
			-- Add simple event emojis
			local event_emojis = {
				task_created = "📝",
				task_completed = "✅", 
				task_updated = "🔄",
				task_deleted = "🗑️"
			}
			row[2] = (event_emojis[row[2]] or "📋") .. " " .. row[2]  -- Event column
			row[4] = utils.add_state_emoji(row[4])  -- State column
		end
		-- Format time (simplified - just show relative format)
		row[1] = utils.format_date(row[1], "relative")  -- Format time
	end
	
	-- Create table
	local table_opts = deep_merge(config.visualization.charts.table, opts or {})
	table_opts.title = string.format("📋 Recent Activity - %s", string.upper(track_type))
	
	local table_display = plot.table(table_data, table_opts)
	
	-- Display
	for _, line in ipairs(table_display) do
		print(line)
	end
end

-- Show comprehensive dashboard in a buffer
function M.dashboard(track_type, opts)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal"
	opts = opts or {}
	local days = opts.days or 7
	local compact = opts.compact or false
	
	-- Create dashboard content
	local lines = {}
	local function add_line(line)
		table.insert(lines, line or "")
	end
	
	-- Header
	add_line("🎯 TASK ANALYTICS DASHBOARD - " .. string.upper(track_type))
	add_line("═" .. string.rep("═", 60))
	add_line("")
	
	-- Get database
	local db = M._get_task_database(track_type)
	if not db then
		add_line("❌ Database not available for " .. track_type .. " tasks")
		add_line("")
		add_line("💡 To get started:")
		add_line("  • Create a note matching your pattern (e.g., perso-2024-09-22.md)")
		add_line("  • Add some tasks with [ ] checkboxes")
		add_line("  • Save the file to start tracking")
	else
		-- Task states overview
		add_line("📊 TASK STATES OVERVIEW")
		add_line("─" .. string.rep("─", 30))
		local state_results = M._get_task_states_data(track_type)
		if state_results and #state_results > 0 then
			local pie_chart = plot.pie_chart(state_results, compact and {radius = 6, show_legend = false} or nil)
			if type(pie_chart) == "table" then
				for _, line in ipairs(pie_chart) do
					add_line(line)
				end
			else
				add_line(tostring(pie_chart))
			end
		else
			add_line("🥧 No task state data found")
		end
		add_line("")
		
		-- Daily completions
		add_line("📈 DAILY COMPLETIONS (Last " .. days .. " days)")
		add_line("─" .. string.rep("─", 40))
		local completion_results = M._get_daily_completions_data(track_type, days)
		if completion_results and #completion_results > 0 then
			local histogram = plot.histogram(completion_results, compact and {width = 30} or nil)
			if type(histogram) == "table" then
				for _, line in ipairs(histogram) do
					add_line(line)
				end
			else
				add_line(tostring(histogram))
			end
		else
			add_line("📊 No completion data found for the last " .. days .. " days")
		end
		add_line("")
		
		-- Productivity trend (last 14 days)
		add_line("📈 PRODUCTIVITY TREND (Last 14 days)")
		add_line("─" .. string.rep("─", 40))
		local trend_results = M._get_productivity_trend_data(track_type, 14)
		if trend_results and #trend_results > 0 then
			local line_plot = plot.line_plot(trend_results, {width = 50, height = 8, show_axes = true})
			if type(line_plot) == "table" then
				for _, line in ipairs(line_plot) do
					add_line(line)
				end
			else
				add_line(tostring(line_plot))
			end
		else
			add_line("📈 No productivity trend data available")
		end
		add_line("")
		
		-- Task type distribution
		add_line("📊 TASK TYPE DISTRIBUTION")
		add_line("─" .. string.rep("─", 30))
		local type_results = M._get_task_type_data(track_type)
		if type_results and #type_results > 0 then
			local type_table = plot.table(type_results, {
				title = "Task Categories",
				headers = {"Type", "Count", "Percentage"},
				show_borders = true
			})
			if type(type_table) == "table" then
				for _, line in ipairs(type_table) do
					add_line(line)
				end
			else
				add_line(tostring(type_table))
			end
		else
			add_line("📋 No task type data found")
		end
		add_line("")
		
		-- Carryover analysis (NEW!)
		add_line("📦 CARRYOVER ANALYSIS (Last 7 days)")
		add_line("─" .. string.rep("─", 35))
		local carryover_results = M._get_carryover_analysis_data(track_type, 7)
		if carryover_results and #carryover_results > 0 then
			local carryover_chart = plot.histogram(carryover_results, {
				width = 45,
				show_values = true,
				title = "Tasks Carried Over by Day"
			})
			if type(carryover_chart) == "table" then
				for _, line in ipairs(carryover_chart) do
					add_line(line)
				end
			else
				add_line(tostring(carryover_chart))
			end
		else
			add_line("📦 No carryover data found (good job staying on top of tasks!)")
		end
		add_line("")
		
		-- Recent activity summary
		add_line("📋 RECENT ACTIVITY SUMMARY")
		add_line("─" .. string.rep("─", 30))
		local activity_results = M._get_recent_activity_data(track_type, 5)
		if activity_results and #activity_results > 0 then
			for _, row in ipairs(activity_results) do
				local time = utils.format_date(row.timestamp, "relative")
				local emoji = utils.add_event_emoji(row.event_type)
				add_line(string.format("  %s %s %s", emoji, time, row.task_text or "Task"))
			end
		else
			add_line("📝 No recent activity found")
		end
		add_line("")
	end
	
	-- Footer
	add_line("📊 Dashboard generated at " .. os.date("%Y-%m-%d %H:%M:%S"))
	add_line("")
	add_line("💡 Press 'q' to close | 'r' to refresh | 'y' for previous day | 't' for today | 'f' for full review")
	
	-- Create buffer
	M._create_dashboard_buffer(track_type, lines)
end

-- Helper function to create dashboard buffer
function M._create_dashboard_buffer(track_type, lines)
	-- Create new buffer
	local buf = vim.api.nvim_create_buf(false, true)
	
	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
	vim.api.nvim_buf_set_option(buf, 'swapfile', false)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	-- Don't set readonly initially - we'll set it after adding content
	
	-- Set buffer name
	local buf_name = "Notes Dashboard - " .. string.upper(track_type)
	pcall(vim.api.nvim_buf_set_name, buf, buf_name)
	
	-- Add content to buffer (it's modifiable by default)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	
	-- Now make it readonly to prevent accidental edits
	vim.api.nvim_buf_set_option(buf, 'modifiable', false)
	vim.api.nvim_buf_set_option(buf, 'readonly', true)
	
	-- Open in new window
	vim.cmd('split')
	vim.api.nvim_win_set_buf(0, buf)
	
	-- Set window options
	vim.api.nvim_win_set_option(0, 'wrap', false)
	vim.api.nvim_win_set_option(0, 'cursorline', true)
	
	-- Set up buffer-local keymaps
	local function map(key, action, desc)
		vim.api.nvim_buf_set_keymap(buf, 'n', key, action, {
			noremap = true,
			silent = true,
			desc = desc
		})
	end
	
	map('q', ':close<CR>', 'Close dashboard')
	map('<Esc>', ':close<CR>', 'Close dashboard')
	map('r', string.format(':lua require("notes").dashboard("%s")<CR>:close<CR>', track_type), 'Refresh dashboard')
	map('h', ':lua require("notes").help()<CR>', 'Show help')
	
	-- Navigation keymaps (smart navigation)
	map('y', string.format(':lua require("notes").previous_day_dashboard("%s")<CR>:close<CR>', track_type), 'Previous working day')
	map('t', string.format(':lua require("notes").today_dashboard("%s")<CR>:close<CR>', track_type), 'Today overview')
	map('w', string.format(':lua require("notes").weekly_dashboard("%s")<CR>:close<CR>', track_type), 'Weekly dashboard')
	map('f', string.format(':lua require("notes").full_review_dashboard("%s")<CR>:close<CR>', track_type), 'Full productivity review')
	
	-- Position cursor at top
	vim.api.nvim_win_set_cursor(0, {1, 0})
	
	-- Notify
	notify(string.format("📊 %s dashboard opened", track_type), "info", "dashboard")
end

-- Helper functions to get data (for buffer creation)
function M._get_task_states_data(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT state, COUNT(*) as count
		FROM (
			SELECT *,
				ROW_NUMBER() OVER (PARTITION BY task_id ORDER BY timestamp DESC) as rn
			FROM task_events
		)
		WHERE rn = 1 AND state != 'DELETED'
		GROUP BY state
		ORDER BY count DESC
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	-- Convert to chart data
	local chart_data = {}
	for _, row in ipairs(results) do
		local label = config.visualization.display.use_emojis and 
		              (utils.add_state_emoji(row.state) .. " " .. row.state) or row.state
		table.insert(chart_data, { label = label, value = row.count })
	end
	
	return chart_data
end

function M._get_daily_completions_data(track_type, days)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = string.format([[
		SELECT date(timestamp) as day, COUNT(*) as count
		FROM task_events
		WHERE event_type = 'task_completed' AND date(timestamp) >= date('now', '-%d days')
		GROUP BY date(timestamp)
		ORDER BY day
	]], days)
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	-- Convert to chart data
	return utils.sql_to_chart_data(results, "day", "count")
end

function M._get_recent_activity_data(track_type, limit)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = string.format([[
		SELECT event_type, timestamp, 
		       substr(task_text, 1, %d) as task_text
		FROM task_events 
		ORDER BY timestamp DESC
		LIMIT %d
	]], config.visualization.data.truncate_length, limit)
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	return results
end

-- Get completion data for a specific day (used by smart previous day)
function M._get_day_completion_data(track_type, days_ago)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = string.format([[
		SELECT 
			CASE 
				WHEN event_type = 'task_completed' THEN '✅ Completed Tasks'
				WHEN event_type = 'task_created' THEN '📝 New Tasks'
				ELSE '🔄 Other Activity'
			END as activity_type,
			COUNT(*) as count
		FROM task_events
		WHERE date(timestamp) = date('now', '-%d days')
		GROUP BY event_type
		ORDER BY count DESC
	]], days_ago or 1)
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	return utils.sql_to_chart_data(results, "activity_type", "count")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📊 CREATIVE DATA HELPERS FOR SPECIALIZED DASHBOARDS
-- ═══════════════════════════════════════════════════════════════════════

-- Get hourly activity data for specific day (0=today, 1=yesterday, etc)
function M._get_hourly_activity_data(track_type, days_ago)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = string.format([[
		SELECT 
			printf("%%02d:00", CAST(strftime('%%%%H', timestamp) AS INTEGER)) as hour,
			COUNT(*) as activity_count
		FROM task_events
		WHERE date(timestamp) = date('now', '-%d days')
		GROUP BY CAST(strftime('%%%%H', timestamp) AS INTEGER)
		ORDER BY hour
	]], days_ago or 0)
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	-- Convert to chart format 
	return utils.sql_to_chart_data(results, "hour", "activity_count")
end

-- Get today vs yesterday comparison data
function M._get_today_vs_yesterday_data(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT 
			CASE 
				WHEN date(timestamp) = date('now') THEN 'Today'
				WHEN date(timestamp) = date('now', '-1 day') THEN 'Yesterday'
			END as day,
			COUNT(*) as task_count
		FROM task_events
		WHERE date(timestamp) IN (date('now'), date('now', '-1 day'))
		GROUP BY day
		ORDER BY day DESC
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	return utils.sql_to_chart_data(results, "day", "task_count")
end

-- Get today's task breakdown by status
function M._get_today_task_breakdown(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT 
			CASE 
				WHEN state = 'COMPLETED' THEN '✅ Completed'
				WHEN state = 'CREATED' THEN '📝 Created'
				WHEN state = 'UPDATED' THEN '🔄 Updated'
				ELSE '📋 ' || state
			END as status,
			COUNT(*) as count
		FROM task_events
		WHERE date(timestamp) = date('now')
		GROUP BY state
		ORDER BY count DESC
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	return utils.sql_to_chart_data(results, "status", "count")
end


-- Get day-of-week productivity patterns
function M._get_day_of_week_data(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT 
			CASE CAST(strftime('%w', timestamp) AS INTEGER)
				WHEN 0 THEN 'Sun'
				WHEN 1 THEN 'Mon'  
				WHEN 2 THEN 'Tue'
				WHEN 3 THEN 'Wed'
				WHEN 4 THEN 'Thu'
				WHEN 5 THEN 'Fri'
				WHEN 6 THEN 'Sat'
			END as day_name,
			COUNT(*) as task_count
		FROM task_events
		WHERE date(timestamp) >= date('now', '-14 days')
		GROUP BY strftime('%w', timestamp)
		ORDER BY strftime('%w', timestamp)
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	return utils.sql_to_chart_data(results, "day_name", "task_count")
end

-- Get weekly achievements
function M._get_weekly_achievements(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT 
			COUNT(DISTINCT task_id) as unique_tasks,
			COUNT(CASE WHEN event_type = 'task_completed' THEN 1 END) as completed_tasks,
			COUNT(CASE WHEN event_type = 'task_created' THEN 1 END) as created_tasks
		FROM task_events
		WHERE date(timestamp) >= date('now', '-7 days')
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	local row = results[1]
	local productivity_score = (row.completed_tasks * 3) + row.created_tasks
	
	return {
		{"Tasks Worked On", row.unique_tasks, "📝"},
		{"Tasks Completed", row.completed_tasks, "✅"},
		{"New Tasks Created", row.created_tasks, "🆕"},
		{"Productivity Score", productivity_score, productivity_score > 20 and "🔥" or "📈"}
	}
end

-- Get week completion overview
function M._get_week_completion_overview(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT 
			event_type as status,
			COUNT(*) as count
		FROM task_events
		WHERE date(timestamp) >= date('now', '-7 days')
		GROUP BY event_type
		ORDER BY count DESC
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	-- Add emojis to status
	local enhanced_results = {}
	for _, row in ipairs(results) do
		local emoji_status = utils.add_event_emoji(row.status) .. " " .. row.status
		table.insert(enhanced_results, {emoji_status, row.count})
	end
	
	return enhanced_results
end

-- Get week's best day
function M._get_week_best_day(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT 
			CASE CAST(strftime('%w', timestamp) AS INTEGER)
				WHEN 0 THEN 'Sunday'
				WHEN 1 THEN 'Monday'
				WHEN 2 THEN 'Tuesday'
				WHEN 3 THEN 'Wednesday'
				WHEN 4 THEN 'Thursday'
				WHEN 5 THEN 'Friday'
				WHEN 6 THEN 'Saturday'
			END as day_name,
			COUNT(*) as task_count
		FROM task_events
		WHERE date(timestamp) >= date('now', '-7 days')
		GROUP BY strftime('%w', timestamp)
		ORDER BY task_count DESC
		LIMIT 1
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	local best_day = results[1]
	local rating = best_day.task_count > 10 and "🔥 Superstar!" or 
	               best_day.task_count > 5 and "⭐ Great!" or "👍 Good effort!"
	
	return {
		day = best_day.day_name,
		count = best_day.task_count,
		rating = rating
	}
end


-- Enhanced productivity trend data (already exists but let's ensure it works)
function M._get_productivity_trend_data(track_type, days)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = string.format([[
		SELECT 
			date(timestamp) as day,
			(%d * SUM(CASE WHEN event_type = 'task_completed' THEN 1 ELSE 0 END) +
			 %d * SUM(CASE WHEN event_type = 'task_created' THEN 1 ELSE 0 END) +
			 %d * SUM(CASE WHEN event_type = 'task_carried_over' THEN 1 ELSE 0 END)) as productivity_score
		FROM task_events
		WHERE date(timestamp) >= date('now', '-%d days')
		GROUP BY date(timestamp)
		ORDER BY day
	]], config.visualization.data.productivity_weights.completed,
	    config.visualization.data.productivity_weights.created,
	    config.visualization.data.productivity_weights.carried_over,
	    days)
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	-- Format dates and return
	return utils.sql_to_chart_data(results, "day", "productivity_score")
end

-- Get task type distribution for main dashboard
function M._get_task_type_data(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT 
			CASE 
				WHEN task_text LIKE '%meeting%' OR task_text LIKE '%call%' THEN 'Meetings'
				WHEN task_text LIKE '%review%' OR task_text LIKE '%check%' THEN 'Reviews'
				WHEN task_text LIKE '%write%' OR task_text LIKE '%document%' THEN 'Writing'
				WHEN task_text LIKE '%fix%' OR task_text LIKE '%bug%' THEN 'Bug Fixes'
				WHEN task_text LIKE '%feature%' OR task_text LIKE '%implement%' THEN 'Features'
				ELSE 'Other Tasks'
			END as task_type,
			COUNT(*) as count
		FROM task_events
		WHERE date(timestamp) >= date('now', '-7 days')
		GROUP BY task_type
		ORDER BY count DESC
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	-- Calculate percentages
	local total = 0
	for _, row in ipairs(results) do
		total = total + row.count
	end
	
	local enhanced_results = {}
	for _, row in ipairs(results) do
		local percentage = math.floor((row.count / total) * 100)
		table.insert(enhanced_results, {row.task_type, row.count, percentage .. "%"})
	end
	
	return enhanced_results
end

-- Get smart previous day data (handles weekends and finds most recent activity)
function M._get_smart_previous_day_data(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	-- Get current day of week (0=Sunday, 1=Monday, etc.)
	local current_dow = tonumber(os.date("%w"))
	local days_to_check = {}
	
	if track_type == "work" then
		-- For work, skip weekends intelligently
		if current_dow == 1 then -- Monday
			days_to_check = {3} -- Check Friday (3 days ago)
		elseif current_dow == 0 then -- Sunday 
			days_to_check = {2} -- Check Friday (2 days ago)
		else
			days_to_check = {1, 3, 4, 5, 6, 7} -- Yesterday, then check back further on weekdays
		end
	else
		-- For personal, check recent days in order
		days_to_check = {1, 2, 3, 4, 5, 6, 7} -- Check last week
	end
	
	-- Try each day until we find data
	for _, days_ago in ipairs(days_to_check) do
		local data = M._get_hourly_activity_data(track_type, days_ago)
		if data and #data > 0 then
			local check_date = os.date("%Y-%m-%d", os.time() - (days_ago * 24 * 60 * 60))
			local day_name = days_ago == 1 and "Yesterday" or 
			                 days_ago == 2 and (current_dow == 0 and "Friday" or "2 days ago") or
			                 days_ago == 3 and (current_dow == 1 and "Friday" or "3 days ago") or
			                 string.format("%d days ago", days_ago)
			
			return {
				data = data,
				day_name = day_name,
				date = check_date,
				days_ago = days_ago
			}
		end
	end
	
	return nil
end

-- Get carryover analysis data for dashboard visualization
function M._get_carryover_analysis_data(track_type, days)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = string.format([[
		SELECT 
			date(timestamp) as day,
			COUNT(*) as carryover_count
		FROM task_events
		WHERE event_type = 'task_carried_over' AND date(timestamp) >= date('now', '-%d days')
		GROUP BY date(timestamp)
		ORDER BY day
	]], days)
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	return utils.sql_to_chart_data(results, "day", "carryover_count")
end

-- Get today's carryover impact for detailed analysis
function M._get_today_carryover_impact(track_type)
	local db = M._get_task_database(track_type)
	if not db then return nil end
	
	local sql = [[
		SELECT COUNT(*) as carried_in
		FROM task_events
		WHERE event_type = 'task_carried_over' AND date(timestamp) = date('now')
	]]
	
	local results = db:eval(sql)
	if not results or type(results) ~= "table" or #results == 0 then
		return nil
	end
	
	local carried_in = results[1].carried_in
	if carried_in == 0 then return nil end
	
	-- Calculate productivity impact based on carryover weight (-1)
	local productivity_impact = carried_in * config.visualization.data.productivity_weights.carried_over
	local impact_text = productivity_impact < -5 and "⚠️ High carryover load" or
	                   productivity_impact < -2 and "📊 Moderate carryover" or
	                   "✅ Light carryover"
	
	return {
		carried_in = carried_in,
		productivity_impact = productivity_impact,
		impact_text = impact_text
	}
end

-- ═══════════════════════════════════════════════════════════════════════
-- 🎨 SPECIALIZED CREATIVE DASHBOARDS
-- ═══════════════════════════════════════════════════════════════════════

-- TODAY Dashboard - Focus on current day with hourly insights
function M.today_dashboard(track_type)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal"
	local lines = {}
	local function add_line(line)
		table.insert(lines, line or "")
	end
	
	-- Header
	add_line("📅 TODAY'S FOCUS DASHBOARD - " .. string.upper(track_type))
	add_line("═" .. string.rep("═", 50))
	add_line("")
	
	local db = M._get_task_database(track_type)
	if not db then
		add_line("❌ Database not available")
		add_line("💡 Create some tasks today to see your hourly activity!")
	else
		-- Today's hourly activity
		add_line("⏰ TODAY'S HOURLY ACTIVITY")
		add_line("─" .. string.rep("─", 30))
		local hourly_data = M._get_hourly_activity_data(track_type, 0) -- Today
		if hourly_data and #hourly_data > 0 then
			local line_chart = plot.line_plot(hourly_data, {
				width = 50, 
				height = 10, 
				show_axes = true,
				title = "Tasks Activity Throughout the Day"
			})
			if type(line_chart) == "table" then
				for _, line in ipairs(line_chart) do
					add_line(line)
				end
			end
		else
			add_line("📊 No activity recorded yet today")
			add_line("💪 Start working on some tasks to see the magic!")
		end
		add_line("")
		
		-- Today vs Yesterday comparison
		add_line("📊 TODAY vs YESTERDAY COMPARISON")
		add_line("─" .. string.rep("─", 35))
		local comparison_data = M._get_today_vs_yesterday_data(track_type)
		if comparison_data and #comparison_data > 0 then
			local comparison_chart = plot.histogram(comparison_data, {
				width = 40,
				show_values = true,
				title = "Productivity Comparison"
			})
			if type(comparison_chart) == "table" then
				for _, line in ipairs(comparison_chart) do
					add_line(line)
				end
			end
		else
			add_line("📈 Not enough data for comparison yet")
		end
		add_line("")
		
		-- Today's task breakdown
		add_line("🎯 TODAY'S TASK BREAKDOWN")
		add_line("─" .. string.rep("─", 25))
		local task_breakdown = M._get_today_task_breakdown(track_type)
		if task_breakdown and #task_breakdown > 0 then
			local breakdown_pie = plot.pie_chart(task_breakdown, {
				radius = 8,
				show_legend = true,
				style = "solid"
			})
			if type(breakdown_pie) == "table" then
				for _, line in ipairs(breakdown_pie) do
					add_line(line)
				end
			end
		else
			add_line("🎯 No tasks completed today yet")
		end
		add_line("")
		
		-- Today's carryover impact (NEW!)
		local carryover_impact = M._get_today_carryover_impact(track_type)
		if carryover_impact then
			add_line("📦 TODAY'S CARRYOVER IMPACT")
			add_line("─" .. string.rep("─", 28))
			add_line(string.format("  Tasks carried in: %d", carryover_impact.carried_in))
			add_line(string.format("  Impact on productivity: %s", carryover_impact.impact_text))
			add_line("")
		end
	end
	
	add_line("⚡ Today's Focus: Make it count!")
	add_line("📅 Dashboard generated at " .. os.date("%H:%M:%S"))
	add_line("")
	add_line("💡 Press 'q' to close | 'r' to refresh | 'y' for previous day | 'w' for weekly | 'f' for full review")
	
	M._create_dashboard_buffer(track_type .. "_today", lines)
end


-- SMART PREVIOUS DAY Dashboard - Intelligently finds most recent working day
function M.previous_day_dashboard(track_type)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal"
	
	-- Get smart previous day data
	local smart_previous = M._get_smart_previous_day_data(track_type)
	
	if smart_previous then
		-- Found data, show the dashboard
		local lines = {}
		local function add_line(line)
			table.insert(lines, line or "")
		end
		
		-- Header with smart context
		add_line("📊 " .. smart_previous.day_name:upper() .. "'S REVIEW - " .. string.upper(track_type))
		add_line("═" .. string.rep("═", 50))
		add_line("")
		add_line("📅 Showing data from " .. smart_previous.date .. " (" .. smart_previous.day_name .. ")")
		add_line("")
		
		-- Activity timeline
		add_line("🕐 ACTIVITY TIMELINE")
		add_line("─" .. string.rep("─", 25))
		local timeline_chart = plot.line_plot(smart_previous.data, {
			width = 55,
			height = 12,
			show_axes = true,
			title = "Activity Flow " .. smart_previous.day_name
		})
		if type(timeline_chart) == "table" then
			for _, line in ipairs(timeline_chart) do
				add_line(line)
			end
		end
		add_line("")
		
		-- Get additional metrics for this day
		local completion_data = M._get_day_completion_data(track_type, smart_previous.days_ago)
		if completion_data and #completion_data > 0 then
			add_line("✅ COMPLETION BREAKDOWN")
			add_line("─" .. string.rep("─", 25))
			local completion_pie = plot.pie_chart(completion_data, {
				radius = 8,
				show_legend = true,
				style = "pattern"
			})
			if type(completion_pie) == "table" then
				for _, line in ipairs(completion_pie) do
					add_line(line)
				end
			end
			add_line("")
		end
		
		add_line("🎯 Smart Navigation: Found your most recent working day!")
		add_line("📊 Analysis generated at " .. os.date("%H:%M:%S"))
		add_line("")
		add_line("💡 Press 'q' to close | 'r' to refresh | 't' for today | 'w' for weekly")
		
		M._create_dashboard_buffer(track_type .. "_previous", lines)
	else
		-- No recent data found, show helpful message
		notify(string.format("📅 No recent activity found for %s tasks in the last week", track_type), "warn", "dashboard")
	end
end

-- FULL REVIEW Dashboard - Comprehensive productivity analysis (replaces Friday-specific)
function M.full_review_dashboard(track_type)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal" 
	local lines = {}
	local function add_line(line)
		table.insert(lines, line or "")
	end
	
	-- Header
	add_line("🎉 COMPREHENSIVE PRODUCTIVITY REVIEW - " .. string.upper(track_type))
	add_line("═" .. string.rep("═", 65))
	add_line("")
	
	local db = M._get_task_database(track_type)
	if not db then
		add_line("❌ No database available for " .. track_type .. " tasks")
	else
		-- 14-day productivity trend
		add_line("📈 PRODUCTIVITY TREND (Last 14 days)")
		add_line("─" .. string.rep("─", 35))
		local trend_results = M._get_productivity_trend_data(track_type, 14)
		if trend_results and #trend_results > 0 then
			local trend_chart = plot.line_plot(trend_results, {
				width = 65,
				height = 15,
				show_axes = true,
				title = "14-Day Productivity Journey"
			})
			if type(trend_chart) == "table" then
				for _, line in ipairs(trend_chart) do
					add_line(line)
				end
			end
		else
			add_line("📈 Not enough data for trend analysis")
		end
		add_line("")
		
		-- Task states overview 
		add_line("🥧 CURRENT TASK STATUS")
		add_line("─" .. string.rep("─", 25))
		local state_results = M._get_task_states_data(track_type)
		if state_results and #state_results > 0 then
			local states_pie = plot.pie_chart(state_results, {
				radius = 10,
				show_legend = true,
				style = "unicode"
			})
			if type(states_pie) == "table" then
				for _, line in ipairs(states_pie) do
					add_line(line)
				end
			end
		else
			add_line("🥧 No task state data available")
		end
		add_line("")
		
		-- Weekly achievements
		add_line("🏆 RECENT ACHIEVEMENTS")
		add_line("─" .. string.rep("─", 25))
		local achievements_data = M._get_weekly_achievements(track_type)
		if achievements_data and #achievements_data > 0 then
			local achievements_table = plot.table(achievements_data, {
				title = "Productivity Metrics",
				headers = {"Metric", "Count", "Rating"},
				show_borders = true
			})
			if type(achievements_table) == "table" then
				for _, line in ipairs(achievements_table) do
					add_line(line)
				end
			end
		else
			add_line("🏆 Start completing tasks to see achievements!")
		end
		add_line("")
	end
	
	add_line("🌟 Keep up the great work! Every task completed is progress! 🌟")
	add_line("🎉 Full review generated at " .. os.date("%Y-%m-%d %H:%M:%S"))
	add_line("")
	add_line("💡 Press 'q' to close | 'r' to refresh | 't' for today | 'y' for previous day")
	
	M._create_dashboard_buffer(track_type .. "_full_review", lines)
end

-- WEEKLY Dashboard - Show patterns and trends over the week
function M.weekly_dashboard(track_type)
	if not M._ensure_visualization_enabled() then return end
	
	track_type = track_type or "personal"
	local lines = {}
	local function add_line(line)
		table.insert(lines, line or "")
	end
	
	-- Header
	add_line("📈 WEEKLY PRODUCTIVITY DASHBOARD - " .. string.upper(track_type))
	add_line("═" .. string.rep("═", 55))
	add_line("")
	
	local db = M._get_task_database(track_type)
	if not db then
		add_line("❌ Database not available")
	else
		-- 7-day productivity trend
		add_line("📊 WEEKLY PRODUCTIVITY TREND")
		add_line("─" .. string.rep("─", 32))
		local trend_results = M._get_productivity_trend_data(track_type, 7)
		if trend_results and #trend_results > 0 then
			local weekly_trend = plot.line_plot(trend_results, {
				width = 60,
				height = 12,
				show_axes = true,
				title = "7-Day Productivity Flow"
			})
			if type(weekly_trend) == "table" then
				for _, line in ipairs(weekly_trend) do
					add_line(line)
				end
			end
		else
			add_line("📈 Not enough weekly data yet")
		end
		add_line("")
		
		-- Day-of-week patterns
		add_line("📅 DAY-OF-WEEK PRODUCTIVITY PATTERNS")
		add_line("─" .. string.rep("─", 40))
		local dow_data = M._get_day_of_week_data(track_type)
		if dow_data and #dow_data > 0 then
			local dow_histogram = plot.histogram(dow_data, {
				width = 50,
				show_values = true,
				title = "Productivity by Day"
			})
			if type(dow_histogram) == "table" then
				for _, line in ipairs(dow_histogram) do
					add_line(line)
				end
			end
		else
			add_line("📊 Not enough data for day patterns")
		end
		add_line("")
		
		-- Weekly achievements
		add_line("🏆 WEEKLY ACHIEVEMENTS")
		add_line("─" .. string.rep("─", 25))
		local achievements_data = M._get_weekly_achievements(track_type)
		if achievements_data and #achievements_data > 0 then
			local achievements_table = plot.table(achievements_data, {
				title = "This Week's Wins",
				headers = {"Achievement", "Count", "Trend"},
				show_borders = true
			})
			if type(achievements_table) == "table" then
				for _, line in ipairs(achievements_table) do
					add_line(line)
				end
			end
		else
			add_line("🏆 Start completing tasks to see achievements!")
		end
		add_line("")
	end
	
	add_line("🌟 Weekly Focus: Consistency is key!")
	add_line("📈 Weekly dashboard at " .. os.date("%H:%M:%S"))
	add_line("")
	add_line("💡 Press 'q' to close | 'r' to refresh | 't' for today | 'y' for previous day | 'f' for full review")
	
	M._create_dashboard_buffer(track_type .. "_weekly", lines)
end

-- FRIDAY Dashboard - Legacy function redirects to full_review_dashboard
function M.friday_dashboard(track_type)
	-- Redirect old Friday-specific dashboard to the more flexible full review
	if track_type == "combined" then
		-- Show full review for personal (most common use case)
		M.full_review_dashboard("personal")
	else
		M.full_review_dashboard(track_type or "personal")
	end
end


-- Convenience functions
function M.personal()
	M.dashboard("personal")
end

function M.work()
	M.dashboard("work")
end

function M.completions(days)
	M.daily_completions("personal", days)
end

function M.states()
	M.task_states("personal")
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📖 HELP SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

-- Show comprehensive help documentation
function M.help()
	local lines = {
		"",
		"📖 NOTES MODULE HELP",
		"=" .. string.rep("=", 60),
		"",
		"🎯 QUICK START",
		"-" .. string.rep("-", 20),
		"  :ZkTaskStats         Show task analytics dashboard", 
		"  :ZkNewDailyJournal   Create new personal journal",
		"  :ZkNewWorkJournal    Create new work journal",
		"  <leader>nts          Task statistics (keybind)",
		"  <leader>nj           New personal journal (keybind)",
		"  <leader>nw           New work journal (keybind)",
		"",
		"⚙️ CONFIGURATION",
		"-" .. string.rep("-", 20),
		"  Current notebook:    " .. (config.directories and config.directories.notebook or "Not configured"),
		"  Tracking types:      " .. (config.tracking and table.concat(vim.tbl_keys(config.tracking), ", ") or "None"),
		"  Visualization:       " .. (config.visualization and config.visualization.enabled and "✅ Enabled" or "❌ Disabled"),
		"  ZK integration:      " .. (config.zk and config.zk.enabled and "✅ Enabled" or "❌ Disabled"),
		"  Notifications:       " .. (config.notifications and config.notifications.enabled and "✅ Enabled" or "❌ Disabled"),
		"",
		"📊 AVAILABLE FUNCTIONS",
		"-" .. string.rep("-", 20),
		"  require('notes').dashboard('personal')   -- Personal dashboard",
		"  require('notes').dashboard('work')       -- Work dashboard", 
		"  require('notes').daily_completions(7)    -- 7-day completions",
		"  require('notes').task_states('personal') -- Task state pie chart",
		"  require('notes').personal()              -- Personal quick dashboard",
		"  require('notes').work()                  -- Work quick dashboard",
		"",
		"🔔 NOTIFICATIONS",
		"-" .. string.rep("-", 20),
		"  Task operations:     " .. (config.notifications and config.notifications.task_operations and "✅ Enabled" or "❌ Disabled"),
		"  Journal carryover:   " .. (config.notifications and config.notifications.journal_carryover and "✅ Enabled" or "❌ Disabled"),
		"  Examples:",
		"    📝 2 new tasks, ✅ 1 completed in work-2024-09-22.md",
		"    📦 Carried over 3 unfinished tasks from perso-2024-09-21.md",
		"",
		"🔧 TROUBLESHOOTING", 
		"-" .. string.rep("-", 20),
		"  Commands not working? → Restart Neovim after config changes",
		"  No task data?        → Create tasks with <leader>nT format",
		"  Database errors?     → Check ZK_NOTEBOOK_DIR is set and exists",
		"  Keybinds conflict?   → Check with :map <leader>n",
		"  Too many notifications? → Set notifications.enabled = false",
		"",
		"📁 FILE PATTERNS",
		"-" .. string.rep("-", 20),
	}
	
	-- Add current tracking patterns
	if config.tracking then
		for track_type, track_config in pairs(config.tracking) do
			if track_config.enabled and track_config.filename_patterns then
				table.insert(lines, string.format("  %s: %s", track_type, table.concat(track_config.filename_patterns, ", ")))
			end
		end
	end
	
	table.insert(lines, "")
	table.insert(lines, "💡 MORE HELP")
	table.insert(lines, "-" .. string.rep("-", 20))
	table.insert(lines, "  :lua require('notes').health()    -- System health check")
	table.insert(lines, "  :lua require('notes').config()    -- Show full configuration")
	table.insert(lines, "  :lua require('notes').examples()  -- Configuration examples")
	table.insert(lines, "")
	table.insert(lines, "✨ Happy note-taking!")
	table.insert(lines, string.rep("=", 72))
	
	-- Display in new buffer
	vim.cmd("enew")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe" 
	vim.bo.swapfile = false
	vim.bo.modifiable = false
	vim.bo.filetype = "help"
	vim.cmd("file Notes\\ Help")
end

-- Show system health check
function M.health()
	local health_lines = {
		"",
		"🏥 NOTES SYSTEM HEALTH CHECK",
		"=" .. string.rep("=", 45),
		""
	}
	
	-- Check environment
	local notebook_dir = vim.env.ZK_NOTEBOOK_DIR
	if notebook_dir then
		table.insert(health_lines, "✅ ZK_NOTEBOOK_DIR: " .. notebook_dir)
		if vim.fn.isdirectory(vim.fn.expand(notebook_dir)) == 1 then
			table.insert(health_lines, "✅ Notebook directory exists")
		else
			table.insert(health_lines, "❌ Notebook directory missing")
		end
	else
		table.insert(health_lines, "⚠️  ZK_NOTEBOOK_DIR not set")
	end
	
	-- Check module status
	table.insert(health_lines, "")
	table.insert(health_lines, "📦 MODULE STATUS")
	table.insert(health_lines, "-" .. string.rep("-", 20))
	table.insert(health_lines, "Setup complete: " .. (is_setup and "✅ Yes" or "❌ No"))
	table.insert(health_lines, "ZK available: " .. (M.zk and "✅ Yes" or "⚠️ No (disabled)"))
	table.insert(health_lines, "SQLite available: " .. (M.sqlite and "✅ Yes" or "⚠️ No (disabled)"))
	
	-- Check databases
	table.insert(health_lines, "")
	table.insert(health_lines, "💾 DATABASES")
	table.insert(health_lines, "-" .. string.rep("-", 20))
	
	if config.tracking then
		for track_type, track_config in pairs(config.tracking) do
			if track_config.enabled then
				local db_path = track_config.database_path
				if db_path then
					local expanded_path = vim.fn.expand(db_path)
					if vim.fn.filereadable(expanded_path) == 1 then
						local size = vim.fn.getfsize(expanded_path)
						table.insert(health_lines, string.format("✅ %s: %s (%d bytes)", track_type, db_path, size))
					else
						table.insert(health_lines, string.format("⚠️ %s: Will be created on first use", track_type))
					end
				end
			end
		end
	end
	
	-- Check recent files
	if notebook_dir then
		table.insert(health_lines, "")
		table.insert(health_lines, "📄 RECENT TRACKED FILES")
		table.insert(health_lines, "-" .. string.rep("-", 20))
		
		-- Check for recent files (simplified)
		local found_files = false
		for track_type, track_config in pairs(config.tracking or {}) do
			if track_config.enabled and track_config.filename_patterns then
				for _, pattern in ipairs(track_config.filename_patterns) do
					-- This is a simple check - in real implementation you'd search the directory
					table.insert(health_lines, string.format("📝 Tracking %s files matching: %s", track_type, pattern))
					found_files = true
				end
			end
		end
		
		if not found_files then
			table.insert(health_lines, "⚠️ No file patterns configured")
		end
	end
	
	table.insert(health_lines, "")
	table.insert(health_lines, "💡 Run :lua require('notes').help() for usage guide")
	table.insert(health_lines, string.rep("=", 55))
	
	-- Display health check
	for _, line in ipairs(health_lines) do
		print(line)
	end
end

-- Show current configuration
function M.config()
	if vim and vim.inspect then
		print("📋 NOTES CONFIGURATION:")
		print(vim.inspect(config))
	else
		print("📋 Current configuration available via require('notes').get_config()")
	end
end

-- Show configuration examples
function M.examples()
	local examples = {
		"",
		"⚙️ NOTES CONFIGURATION EXAMPLES",
		"=" .. string.rep("=", 50),
		"",
		"🏠 HOME OFFICE SETUP:",
		"require('notes').setup({",
		"  directories = {",
		"    notebook = '~/Documents/Notes',",
		"    personal_journal = 'personal/daily',",
		"    work_journal = 'work/projects'",
		"  },",
		"  tracking = {",
		"    personal = { filename_patterns = {'personal-*.md'} },",
		"    work = { filename_patterns = {'work-*.md'} }",
		"  }",
		"})",
		"",
		"🎓 STUDENT SETUP:",
		"require('notes').setup({",
		"  directories = { notebook = '~/School/Notes' },",
		"  tracking = {",
		"    personal = { filename_patterns = {'personal-*.md'} },",
		"    coursework = { filename_patterns = {'cs-*.md', 'math-*.md'} },",
		"    research = { filename_patterns = {'research-*.md'} }",
		"  }",
		"})",
		"",
		"💼 CORPORATE SETUP:",
		"require('notes').setup({",
		"  directories = { notebook = '~/Work/Notes' },",
		"  tracking = {",
		"    personal = { database_path = '~/Personal/.tasks.db' },",
		"    project_alpha = { filename_patterns = {'alpha-*.md'} },",
		"    meetings = { filename_patterns = {'meeting-*.md'} }",
		"  }",
		"})",
		"",
		"🎨 VISUALIZATION OPTIONS:",
		"visualization = {",
		"  charts = {",
		"    pie_chart = { style = 'unicode', radius = 15 },",
		"    histogram = { width = 80, show_values = true }",
		"  },",
		"  data = { date_format = 'relative' }",
		"}",
		"",
		"🔔 NOTIFICATION OPTIONS:", 
		"notifications = {",
		"  enabled = true,           -- Master toggle",
		"  task_operations = true,   -- Task save/update notifications",  
		"  journal_carryover = true, -- Task carryover notifications",
		"  level = 'info',           -- info, warn, error",
		"  duration = 3000           -- Display time in ms (0 = no timeout)",
		"}",
		"",
		"📝 JOURNAL TEMPLATES:",
		"journal = {",
		"  daily_template = {",
		"    personal = {",
		"      sections = {'🎯 Focus', '📋 Tasks', '💭 Ideas'}",
		"    }",
		"  }",
		"}",
		"",
		string.rep("=", 60)
	}
	
	-- Display examples
	vim.cmd("enew")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, examples)
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.swapfile = false
	vim.bo.modifiable = false
	vim.bo.filetype = "lua"
	vim.cmd("file Notes\\ Examples")
end

-- Expose submodules for advanced usage
M.plot = plot
M.utils = utils

return M
