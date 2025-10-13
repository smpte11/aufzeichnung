-- ⚡ ZK-NVIM INTEGRATION MODULE ⚡
-- Optional integration with zk-nvim for advanced note management
-- This module is only loaded if zk-nvim is available

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
-- 📝 COMMANDS
-- ═══════════════════════════════════════════════════════════════════════

function M._register_commands(config)
    local commands = require("zk.commands")

    -- Note creation commands
    commands.add("ZkNewAtDir", function(options)
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
        local content = M.notes._create_journal_content_with_carryover(target_dir, "personal")

        M.zk.new({ dir = dir, title = title, content = content })
    end)

    commands.add("ZkNewWorkJournal", function(options)
        local dir = vim.fn.input("Work journal directory: ", config.directories.work_journal)
        if dir == "" then return end

        local journal_config = config.journal.daily_template.work
        local date = os.date("%Y-%m-%d")
        local title = journal_config.prefix .. "-" .. date
        local target_dir = config.directories.notebook .. "/" .. dir
        local content = M.notes._create_journal_content_with_carryover(target_dir, "work")

        M.zk.new({ dir = dir, title = title, content = content })
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
            "<Cmd>ZkNewDailyJournal<CR>",
            vim.tbl_extend("force", opts, { desc = "New daily journal (zk)" }))
    end

    if mappings.work_journal then
        vim.keymap.set("n", prefix .. mappings.work_journal,
            "<Cmd>ZkNewWorkJournal<CR>",
            vim.tbl_extend("force", opts, { desc = "New work journal (zk)" }))
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
