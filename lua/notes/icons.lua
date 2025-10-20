-- Icon system with Nerd Font / Unicode emoji toggle support

local M = {}

-- Icon definitions with both Unicode and Nerd Font variants
local icons = {
    -- Stats and charts
    stats = { unicode = "📊", nerd = "" },
    chart = { unicode = "📈", nerd = "" },
    chart_down = { unicode = "📉", nerd = "" },

    -- States
    check = { unicode = "✅", nerd = "" },
    rocket = { unicode = "🚀", nerd = "" },
    note = { unicode = "📝", nerd = "" },
    trash = { unicode = "🗑️", nerd = "" },
    x = { unicode = "❌", nerd = "" },
    blocked = { unicode = "🚫", nerd = "" },
    pause = { unicode = "⏸️", nerd = "" },

    -- Sections
    calendar = { unicode = "📅", nerd = "" },
    clipboard = { unicode = "📋", nerd = "" },
    target = { unicode = "🎯", nerd = "" },
    lightbulb = { unicode = "💡", nerd = "" },
    fire = { unicode = "🔥", nerd = "" },
    book = { unicode = "📚", nerd = "" },
    link = { unicode = "🔗", nerd = "" },

    -- Actions
    new = { unicode = "✨", nerd = "" },
    save = { unicode = "💾", nerd = "" },
    search = { unicode = "🔍", nerd = "" },
    info = { unicode = "ℹ️", nerd = "" },
    warning = { unicode = "⚠️", nerd = "" },
    error = { unicode = "❗", nerd = "" },

    -- Journal types
    folder = { unicode = "📁", nerd = "" },
    briefcase = { unicode = "💼", nerd = "" },

    -- Misc
    star = { unicode = "⭐", nerd = "" },
    clock = { unicode = "🕒", nerd = "" },
    bell = { unicode = "🔔", nerd = "" },
    tag = { unicode = "🏷️", nerd = "" },
    pin = { unicode = "📌", nerd = "" },

    -- Journal templates - Personal
    focus = { unicode = "🎯", nerd = "" },
    tasks = { unicode = "☑️", nerd = "" },
    ideas = { unicode = "💭", nerd = "󰛨" },
    reflection = { unicode = "🪞", nerd = "" },

    -- Journal templates - Work
    sprint = { unicode = "🏃", nerd = "󰜎" },
    action = { unicode = "⚡", nerd = "" },
    team = { unicode = "👥", nerd = "" },
    progress = { unicode = "📊", nerd = "" },
}

-- Default configuration: use nerd font glyphs
M.config = {
    icon_style = "nerd_font", -- Options: "nerd_font", "unicode", "none"
}

--- Setup the icon system with user configuration
---@param config table|nil Configuration table with icon_style option
function M.setup(config)
    M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

--- Get an icon by name
---@param name string The icon name
---@return string The icon character or empty string
function M.get(name)
    if M.config.icon_style == "none" then
        return ""
    end

    local icon_def = icons[name]
    if not icon_def then
        return ""
    end

    if M.config.icon_style == "nerd_font" then
        return icon_def.nerd
    elseif M.config.icon_style == "unicode" then
        return icon_def.unicode
    else
        return ""
    end
end

--- Get icon with space suffix for convenience
---@param name string The icon name
---@return string The icon with space or empty string
function M.get_with_space(name)
    local icon = M.get(name)
    return icon ~= "" and (icon .. " ") or ""
end

--- Get state icon based on state name
---@param state string The state name (e.g., "FINISHED", "IN_PROGRESS")
---@return string The appropriate icon
function M.get_state_icon(state)
    local upper_state = string.upper(tostring(state or ""))
    local state_map = {
        FINISHED = "check",
        COMPLETED = "check",
        IN_PROGRESS = "rocket",
        STARTED = "rocket",
        CREATED = "note",
        NEW = "note",
        DELETED = "trash",
        CANCELLED = "x",
        BLOCKED = "blocked",
        PAUSED = "pause",
    }

    local icon_name = state_map[upper_state]
    return icon_name and M.get(icon_name) or ""
end

--- Convenience functions for common icons
function M.stats()
    return M.get("stats")
end

function M.chart()
    return M.get("chart")
end

function M.check()
    return M.get("check")
end

function M.rocket()
    return M.get("rocket")
end

function M.note()
    return M.get("note")
end

function M.calendar()
    return M.get("calendar")
end

function M.clipboard()
    return M.get("clipboard")
end

function M.target()
    return M.get("target")
end

function M.lightbulb()
    return M.get("lightbulb")
end

function M.fire()
    return M.get("fire")
end

function M.book()
    return M.get("book")
end

function M.link()
    return M.get("link")
end

return M
