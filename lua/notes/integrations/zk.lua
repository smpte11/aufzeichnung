-- ⚡ ZK-NVIM INTEGRATION MODULE ⚡
-- Optional integration with zk-nvim for advanced note management
-- This module is only loaded if zk-nvim is available
--
-- DESIGN PHILOSOPHY:
--   Leverage zk's native configuration system (groups, templates) for note creation
--   Plugin handles task tracking and carryover logic, zk handles note formatting
--
-- CONFIGURATION:
--   Regular notes: Use zk's default [note] configuration
--   Journals: Use zk groups (personal-journal, work-journal) with content from plugin
--
-- EXPECTED ZK CONFIG (~/.config/zk/config.toml):
--   [note]
--   filename = "{{format-date now 'timestamp'}}-{{slug title}}"
--   template = "default.md"
--
--   [group.personal-journal]
--   paths = ["journal/daily"]
--   [group.personal-journal.note]
--   filename = "perso-{{format-date now '%Y-%m-%d'}}"
--   template = "personal-journal.md"
--
--   [group.work-journal]
--   paths = ["work"]
--   [group.work-journal.note]
--   filename = "work-{{format-date now '%Y-%m-%d'}}"
--   template = "work-journal.md"

local M = {}

-- Store references
M.zk = nil
M.is_available = false

-- ═══════════════════════════════════════════════════════════════════════
-- 🔧 SETUP
-- ═══════════════════════════════════════════════════════════════════════

function M.setup(notes_config, notes_module)
    -- Try to load zk-nvim
    local ok, zk = pcall(require, "zk")
    if not ok then
        M.is_available = false
        return false
    end

    M.zk = zk
    M.is_available = true
    M.notes = notes_module -- Store reference to parent module

    -- Basic zk setup
    local zk_config = {
        picker = notes_config.integrations.zk.picker or "minipick",
        lsp = {
            config = {
                cmd = { "zk", "lsp" },
                name = "zk",
                on_attach = function(_, bufnr)
                    M._setup_buffer_keymaps(bufnr, notes_config)
                end,
            }
        }
    }

    -- Merge any additional zk config
    for k, v in pairs(notes_config.integrations.zk) do
        if k ~= "enabled" and k ~= "picker" then
            zk_config[k] = v
        end
    end

    zk.setup(zk_config)

    -- Register commands
    M._register_commands(notes_config)

    return true
end

-- ═══════════════════════════════════════════════════════════════════════
-- ⌨️ BUFFER-SPECIFIC KEYMAPS
-- ═══════════════════════════════════════════════════════════════════════

function M._setup_buffer_keymaps(bufnr, config)
    local function map(mode, lhs, rhs, opts)
        vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { buffer = bufnr }, opts or {}))
    end

    local opts = { noremap = true, silent = false }
    local prefix = config.keymaps.prefix

    -- Selection-based note creation
    map("v", prefix .. config.keymaps.mappings.new_note .. "t",
        ":'<,'>ZkNewFromTitleSelection<CR>",
        vim.tbl_extend("force", opts, { desc = "Create note from title selection" }))

    map("v", prefix .. config.keymaps.mappings.new_note .. "c",
        ":'<,'>ZkNewFromContentSelection { title = vim.fn.input('Title: ') }<CR>",
        vim.tbl_extend("force", opts, { desc = "Create note from content selection" }))
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📂 DIRECTORY PICKER
-- ═══════════════════════════════════════════════════════════════════════

-- Get all directories in the notebook recursively
function M._get_notebook_directories(notebook_dir, max_depth)
    max_depth = max_depth or 3
    local directories = {}

    local function scan_dir(path, depth)
        if depth > max_depth then return end

        local handle = vim.loop.fs_scandir(path)
        if not handle then return end

        while true do
            local name, typ = vim.loop.fs_scandir_next(handle)
            if not name then break end

            -- Skip hidden directories and common ignore patterns
            if typ == "directory" and not name:match("^%.") then
                local full_path = path .. "/" .. name
                local relative_path = full_path:sub(#notebook_dir + 2) -- Remove notebook_dir prefix
                table.insert(directories, relative_path)
                scan_dir(full_path, depth + 1)
            end
        end
    end

    -- Also add the root directory option
    table.insert(directories, ".")
    scan_dir(notebook_dir, 1)

    -- Sort directories alphabetically
    table.sort(directories, function(a, b)
        if a == "." then return true end
        if b == "." then return false end
        return a < b
    end)

    return directories
end

-- Show directory picker using mini.pick
function M._pick_directory(notebook_dir, callback)
    local ok, MiniPick = pcall(require, "mini.pick")
    if not ok then
        -- Fallback to vim.fn.input if mini.pick not available
        local dir = vim.fn.input("Directory: ", notebook_dir)
        if dir ~= "" then
            callback(dir)
        end
        return
    end

    local directories = M._get_notebook_directories(notebook_dir)

    if #directories == 0 then
        vim.notify("No directories found in notebook", vim.log.levels.WARN)
        return
    end

    -- Create items for picker
    local utils = require('notes.utils')
    local items = {}
    for _, dir in ipairs(directories) do
        local display = dir == "." and utils.icons.folder .. " (root)" or utils.icons.folder .. " " .. dir
        table.insert(items, {
            text = display,
            path = dir == "." and notebook_dir or dir
        })
    end

    MiniPick.start({
        source = {
            name = "Select Directory",
            items = items,
            choose = function(item)
                if item and item.path then
                    callback(item.path)
                end
            end
        },
        window = {
            config = function()
                local height = math.min(15, #items + 2)
                local width = 50

                return {
                    relative = "editor",
                    anchor = "NW",
                    height = height,
                    width = width,
                    row = math.floor(vim.o.lines * 0.2),
                    col = math.floor((vim.o.columns - width) / 2),
                    border = "rounded",
                    style = "minimal"
                }
            end
        }
    })
end

-- Show journal type picker using mini.pick
function M._pick_journal_type(callback)
    local ok, MiniPick = pcall(require, "mini.pick")
    if not ok then
        -- Fallback to vim.fn.input if mini.pick not available
        local choice = vim.fn.input("Journal type (p)ersonal or (w)ork: ")
        if choice == "p" or choice == "personal" then
            callback("personal")
        elseif choice == "w" or choice == "work" then
            callback("work")
        end
        return
    end

    local utils = require('notes.utils')
    local items = {
        { text = utils.icons.file_text .. " Personal Journal", type = "personal" },
        { text = utils.icons.briefcase .. " Work Journal", type = "work" }
    }

    MiniPick.start({
        source = {
            name = "Select Journal Type",
            items = items,
            choose = function(item)
                if item and item.type then
                    callback(item.type)
                end
            end
        },
        window = {
            config = function()
                local height = 4 -- Just 2 options + border
                local width = 30

                return {
                    relative = "editor",
                    anchor = "NW",
                    height = height,
                    width = width,
                    row = math.floor(vim.o.lines * 0.2),
                    col = math.floor((vim.o.columns - width) / 2),
                    border = "rounded",
                    style = "minimal"
                }
            end
        }
    })
end

-- ═══════════════════════════════════════════════════════════════════════
-- 📝 COMMANDS
-- ═══════════════════════════════════════════════════════════════════════
--
-- TEMPLATE REQUIREMENTS:
--
-- 1. ~/.config/zk/templates/default.md (for regular notes)
--    # {{title}}
--    
--    {{content}}
--
-- 2. ~/.config/zk/templates/personal-journal.md
--    # {{format-date now "%Y-%m-%d"}} - Personal Journal
--    
--    {{content}}
--
-- 3. ~/.config/zk/templates/work-journal.md
--    # {{format-date now "%Y-%m-%d"}} - Work Journal
--    
--    {{content}}
--
-- The plugin generates the body content (with task carryover) which templates
-- insert via {{content}}. This keeps formatting/frontmatter in zk templates
-- while keeping complex carryover logic in the plugin.

function M._register_commands(config)
    local commands = require("zk.commands")

    -- Note creation commands
    commands.add("ZkNewAtDir", function(options)
        M._pick_directory(config.directories.notebook, function(dir)
            local title = vim.fn.input("Title: ")
            if title == "" then return end

            M.zk.new({ dir = dir, title = title })
        end)
    end)

    -- Journal commands
    -- Unified journal command with type and directory pickers
    commands.add("ZkNewJournal", function(options)
        M._pick_journal_type(function(journal_type)
            M._pick_directory(config.directories.notebook, function(dir)
                local target_dir = config.directories.notebook .. "/" .. dir
                local content = M.notes._create_journal_content_with_carryover(target_dir, journal_type)
                local group = journal_type == "personal" and "personal-journal" or "work-journal"

                M.zk.new({ dir = dir, group = group, content = content })
            end)
        end)
    end)

    -- Legacy commands kept for backward compatibility and quick shortcuts
    commands.add("ZkNewDailyJournal", function(options)
        M._pick_directory(config.directories.notebook, function(dir)
            local target_dir = config.directories.notebook .. "/" .. dir
            local content = M.notes._create_journal_content_with_carryover(target_dir, "personal")

            M.zk.new({ dir = dir, group = "personal-journal", content = content })
        end)
    end)

    commands.add("ZkNewWorkJournal", function(options)
        M._pick_directory(config.directories.notebook, function(dir)
            local target_dir = config.directories.notebook .. "/" .. dir
            local content = M.notes._create_journal_content_with_carryover(target_dir, "work")

            M.zk.new({ dir = dir, group = "work-journal", content = content })
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- ⌨️ KEYMAPS
-- ═══════════════════════════════════════════════════════════════════════

function M.setup_keymaps(config)
    if not M.is_available then return end

    local prefix = config.keymaps.prefix
    local mappings = config.keymaps.mappings or {}
    local opts = { noremap = true, silent = false }

    -- Note creation
    if mappings.new_note then
        vim.keymap.set("n", prefix .. mappings.new_note,
            "<Cmd>ZkNew { title = vim.fn.input('Title: ') }<CR>",
            vim.tbl_extend("force", opts, { desc = "New note (zk)" }))
    end

    if mappings.new_at_dir then
        vim.keymap.set("n", prefix .. mappings.new_at_dir,
            "<Cmd>ZkNewAtDir<CR>",
            vim.tbl_extend("force", opts, { desc = "New note at directory (zk)" }))
    end

    -- Journal creation
    if mappings.daily_journal then
        vim.keymap.set("n", prefix .. mappings.daily_journal,
            "<Cmd>ZkNewJournal<CR>",
            vim.tbl_extend("force", opts, { desc = "New journal (zk)" }))
    end

    -- Optional: Keep work_journal mapping as a direct shortcut to work journals
    if mappings.work_journal then
        vim.keymap.set("n", prefix .. mappings.work_journal,
            "<Cmd>ZkNewWorkJournal<CR>",
            vim.tbl_extend("force", opts, { desc = "New work journal shortcut (zk)" }))
    end

    -- Note browsing
    if mappings.open_notes then
        vim.keymap.set("n", prefix .. mappings.open_notes,
            "<Cmd>ZkNotes { sort = { 'modified' } }<CR>",
            vim.tbl_extend("force", opts, { desc = "Open notes (zk)" }))
    end

    if mappings.find_notes then
        vim.keymap.set("n", prefix .. mappings.find_notes,
            "<Cmd>ZkNotes { sort = { 'modified' }, match = { vim.fn.input('Search: ') } }<CR>",
            vim.tbl_extend("force", opts, { desc = "Find notes (zk)" }))
    end

    if mappings.browse_tags then
        vim.keymap.set("n", prefix .. mappings.browse_tags,
            "<Cmd>ZkTags<CR>",
            vim.tbl_extend("force", opts, { desc = "Browse tags (zk)" }))
    end
end

return M
