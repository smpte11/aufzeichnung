-- sqlite.lua test stub
-- Provides a minimal in-memory "sqlite" interface sufficient for integration tests.
-- This is NOT a real SQL engine. It only supports the specific statements used in the plugin/tests.

local M = {}

-- In-memory databases keyed by path
local MEM = {}

local function new_db_state()
    return {
        tables = {
            task_events = {
                columns = {
                    event_id = { type = "INTEGER", primary_key = true, autoincrement = true },
                    task_id = { type = "TEXT", not_null = true },
                    event_type = { type = "TEXT", not_null = true },
                    timestamp = { type = "TEXT", not_null = true },
                    task_text = { type = "TEXT" },
                    state = { type = "TEXT" },
                    journal_file = { type = "TEXT" },
                    created_at = { type = "DATETIME" },
                    -- Added via migrations in real plugin; we allow dynamic addition:
                    parent_id = { type = "TEXT" },
                    content_hash = { type = "TEXT" },
                },
                rows = {},
                next_event_id = 1,
            },
        },
    }
end

local function get_db(path)
    if not MEM[path] then
        MEM[path] = new_db_state()
    end
    return MEM[path]
end

-- Simple stmt normalization
local function normalize_sql(sql)
    sql = sql:gsub("%s+", " ")
    sql = sql:gsub("^%s+", "")
    sql = sql:gsub("%s+$", "")
    return sql
end

-- Insert into task_events
local function exec_insert_task_events(db, params)
    local t = db.tables.task_events
    local row = {
        event_id = t.next_event_id,
        task_id = params[1],
        event_type = params[2],
        timestamp = params[3],
        task_text = params[4],
        state = params[5],
        journal_file = params[6],
        parent_id = params[7],
        content_hash = params[8],
        created_at = os.date("%Y-%m-%d %H:%M:%S"),
    }
    t.rows[#t.rows + 1] = row
    t.next_event_id = t.next_event_id + 1
    return true
end

-- Update content_hash by event_id
local function exec_update_content_hash(db, hash, event_id)
    local t = db.tables.task_events
    for i = #t.rows, 1, -1 do
        local row = t.rows[i]
        if row.event_id == tonumber(event_id) then
            row.content_hash = hash
            return 1
        end
    end
    return 0
end

-- SELECT COUNT(*) AS c FROM task_events WHERE event_type = ?
local function eval_count_by_event_type(db, event_type)
    local t = db.tables.task_events
    local count = 0
    for _, row in ipairs(t.rows) do
        if row.event_type == event_type then
            count = count + 1
        end
    end
    return { { c = count } }
end

-- SELECT event_id, task_text FROM task_events WHERE content_hash IS NULL OR content_hash = ''
local function eval_event_id_task_text_where_missing_hash(db)
    local t = db.tables.task_events
    local res = {}
    for _, row in ipairs(t.rows) do
        if row.content_hash == nil or row.content_hash == "" then
            res[#res + 1] = { event_id = row.event_id, task_text = row.task_text }
        end
    end
    return res
end

-- SELECT event_id, task_text, content_hash FROM task_events WHERE (content_hash IS NULL OR content_hash = '') AND COALESCE(task_text, '') != ''
local function eval_records_to_fix(db)
    local t = db.tables.task_events
    local res = {}
    for _, row in ipairs(t.rows) do
        local task_text = row.task_text or ""
        local ch = row.content_hash
        if (ch == nil or ch == "") and task_text ~= "" then
            res[#res + 1] = { event_id = row.event_id, task_text = row.task_text, content_hash = row.content_hash }
        end
    end
    return res
end

-- SELECT COUNT(*) as count, state, task_text, parent_id, content_hash FROM task_events WHERE task_id = ? ORDER BY event_id DESC LIMIT 1
local function eval_latest_for_task_id(db, task_id)
    local t = db.tables.task_events
    local latest = nil
    for _, row in ipairs(t.rows) do
        if row.task_id == task_id then
            if not latest or row.event_id > latest.event_id then
                latest = row
            end
        end
    end
    if latest then
        return { {
            count = 1,
            state = latest.state,
            task_text = latest.task_text,
            parent_id = latest.parent_id,
            content_hash = latest.content_hash,
        } }
    else
        return { { count = 0, state = nil, task_text = nil, parent_id = nil, content_hash = nil } }
    end
end

-- Basic statement dispatcher
local function dispatch_execute(db, sql)
    sql = normalize_sql(sql)
    -- CREATE TABLE and CREATE INDEX are no-ops in stub (schema predefined or ignored)
    if sql:match("^CREATE TABLE") then
        return true
    end
    if sql:match("^ALTER TABLE task_events ADD COLUMN parent_id") then
        -- ensure column exists
        db.tables.task_events.columns.parent_id = db.tables.task_events.columns.parent_id or { type = "TEXT" }
        return true
    end
    if sql:match("^ALTER TABLE task_events ADD COLUMN content_hash") then
        db.tables.task_events.columns.content_hash = db.tables.task_events.columns.content_hash or { type = "TEXT" }
        return true
    end
    if sql:match("^CREATE INDEX") then
        return true
    end
    if sql:match("^PRAGMA ") then
        return true
    end
    -- Other DDL/DML ignored for tests
    return true
end

local function dispatch_eval(db, sql, params)
    sql = normalize_sql(sql)

    -- INSERT INTO task_events (...) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    if sql:match("^INSERT INTO task_events") then
        return exec_insert_task_events(db, params or {})
    end

    -- UPDATE task_events SET content_hash = ? WHERE event_id = ?
    if sql:match("^UPDATE task_events SET content_hash = %? WHERE event_id = %?") then
        local hash, event_id = params[1], params[2]
        exec_update_content_hash(db, hash, event_id)
        return true
    end

    -- SELECT COUNT(*) AS c FROM task_events WHERE event_type = ?
    if sql:match("^SELECT COUNT%(%*%) AS c FROM task_events WHERE event_type = %?") then
        local event_type = params[1]
        return eval_count_by_event_type(db, event_type)
    end

    -- SELECT event_id, task_text FROM task_events WHERE content_hash IS NULL OR content_hash = ''
    if sql:match("^SELECT event_id, task_text FROM task_events WHERE content_hash IS NULL OR content_hash = ''$") then
        return eval_event_id_task_text_where_missing_hash(db)
    end

    -- SELECT event_id, task_text, content_hash FROM task_events WHERE (content_hash IS NULL OR content_hash = '') AND COALESCE(task_text, '') != ''
    if sql:match("^SELECT event_id, task_text, content_hash FROM task_events WHERE %(content_hash IS NULL OR content_hash = ''%) AND COALESCE%(task_text, ''%) != ''$") then
        return eval_records_to_fix(db)
    end

    -- SELECT COUNT(*) as count, state, task_text, parent_id, content_hash FROM task_events WHERE task_id = ? ORDER BY event_id DESC LIMIT 1
    if sql:match("^SELECT COUNT%(%*%) as count, state, task_text, parent_id, content_hash FROM task_events WHERE task_id = %? ORDER BY event_id DESC LIMIT 1$") then
        local task_id = params[1]
        return eval_latest_for_task_id(db, task_id)
    end

    -- Unhandled SELECTs return empty
    if sql:match("^SELECT") then
        return {}
    end

    -- Fallback: treat as execute
    return dispatch_execute(db, sql)
end

-- sqlite API
function M.new(path)
    local o = {}
    o._path = path or ":memory:"
    o._db = get_db(o._path)

    function o:open()
        -- No-op for in-memory stub
        return true
    end

    -- Execute statements that don't return rows
    function o:execute(sql)
        return dispatch_execute(self._db, sql)
    end

    -- Eval statements that may return rows or perform parameterized changes
    function o:eval(sql, params)
        return dispatch_eval(self._db, sql, params or {})
    end

    function o:close()
        -- Keep memory persistent across tests for same path
        return true
    end

    return o
end

return M
