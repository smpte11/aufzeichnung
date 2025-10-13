-- Org-mode style progress counters for markdown headings using virtual text
-- Scans buffer for headings and nested checkbox tasks and annotates each heading
-- with a progress cookie like: [3/10 30%]
-- Design goals: O(n) per refresh, debounced, no mutations, safe failures.
-- General markdown enhancement, works with any markdown files.

local M = {}

local NS = vim.api.nvim_create_namespace("MarkdownTaskCounter")

local default_config = {
  filetypes = { "markdown", "vimwiki", "telekasten", "quarto" }, -- Support various markdown-like formats
  path_patterns = {},               -- Optional: restrict to specific paths (e.g., { "*/notes/*", "*/journal/*" })
  debounce_ms = 120,                -- Debounce interval
  show_percent = true,              -- Show percentage after fraction
  min_tasks_for_counter = 1,        -- Minimum tasks in subtree to show counter
  virt_text_hl = "Comment",         -- Highlight group for virtual text
  virt_text_prefix = " ",           -- Prefix before progress cookie
  enable = true,                    -- Master enable flag
  priority = 90,                    -- Extmark priority (lower than render-markdown)
  -- Task patterns (customizable for different task formats)
  task_patterns = {
    "^%s*[%-%*%+]%s+%[(.?)%]",      -- Standard markdown: - [ ] task
    "^%s*%d+%.%s+%[(.?)%]",         -- Numbered lists: 1. [ ] task
  }
}

M._config = vim.deepcopy(default_config)
M._timers = {} -- per-buffer timers

local function matches_path_patterns(path, patterns)
  if not patterns or #patterns == 0 then return true end
  for _, pattern in ipairs(patterns) do
    if vim.fn.glob2regpat(pattern) then
      if path:match(vim.fn.glob2regpat(pattern)) then
        return true
      end
    end
  end
  return false
end

local function eligible(bufnr)
  if not M._config.enable then return false end
  if not vim.api.nvim_buf_is_loaded(bufnr) then return false end
  if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ~= "" then return false end
  if not vim.tbl_contains(M._config.filetypes, vim.bo[bufnr].filetype) then return false end
  
  -- Check path patterns if specified
  local path = vim.api.nvim_buf_get_name(bufnr)
  if not matches_path_patterns(path, M._config.path_patterns) then return false end
  
  return true
end

-- Parse buffer collecting heading task counts in a single pass.
-- Returns array of heading objects: { line, level, done, total }
local function collect(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local headings = {}
  local stack = {} -- stack of active headings (each references table in headings)

  local function pop_until(level)
    while #stack > 0 and stack[#stack].level >= level do
      stack[#stack] = nil
    end
  end

  local function is_task_line(line)
    for _, pattern in ipairs(M._config.task_patterns) do
      if line:match(pattern) then
        return line:match(pattern)
      end
    end
    return nil
  end

  for i, l in ipairs(lines) do
    local hashes = l:match("^(#+)%s+")
    if hashes then
      local level = #hashes
      pop_until(level)
      local h = { line = i - 1, level = level, done = 0, total = 0 }
      headings[#headings + 1] = h
      stack[#stack + 1] = h
    else
      -- Check if line is a task using configurable patterns
      local box = is_task_line(l)
      if box and #stack > 0 then
        for _, h in ipairs(stack) do
          h.total = h.total + 1
          if box == "x" or box == "X" then
            h.done = h.done + 1
          end
        end
      end
    end
  end

  return headings
end

local function render(bufnr)
  if not eligible(bufnr) then
    -- Clear any previous marks if buffer no longer eligible
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, NS, 0, -1)
    end
    return
  end

  local ok, headings = pcall(collect, bufnr)
  if not ok then return end

  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)

  for _, h in ipairs(headings) do
    if h.total >= M._config.min_tasks_for_counter then
      local total = h.total == 0 and 1 or h.total
      local percent = (h.done / total) * 100
      local pct_str = M._config.show_percent and string.format(" %d%%", math.floor(percent + 0.5)) or ""
      local text = string.format("%s[%d/%d%s]", M._config.virt_text_prefix, h.done, h.total, pct_str)
      pcall(vim.api.nvim_buf_set_extmark, bufnr, NS, h.line, -1, {
        virt_text = { { text, M._config.virt_text_hl } },
        virt_text_pos = "eol",
        hl_mode = "combine",
        priority = M._config.priority,
      })
    end
  end
end

local function debounced_render(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local existing = M._timers[bufnr]
  if existing and not existing:is_closing() then
    existing:stop(); existing:close()
  end
  local timer = vim.uv.new_timer()
  M._timers[bufnr] = timer
  timer:start(M._config.debounce_ms, 0, vim.schedule_wrap(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      render(bufnr)
    end
  end))
end

function M.refresh(bufnr)
  debounced_render(bufnr or vim.api.nvim_get_current_buf())
end

function M.setup(opts)
  if opts then
    M._config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts)
  end

  local group = vim.api.nvim_create_augroup("MarkdownTaskCounter", { clear = true })
  local events = { "BufEnter", "TextChanged", "TextChangedI", "InsertLeave" }
  for _, ev in ipairs(events) do
    vim.api.nvim_create_autocmd(ev, {
      group = group,
      callback = function(args)
        if eligible(args.buf) then
          debounced_render(args.buf)
        end
      end,
    })
  end
  
  -- Set up buffer-local keymaps for markdown files
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = M._config.filetypes,
    callback = function(args)
      local bufnr = args.buf
      -- Only set keymaps if the buffer is eligible (respects path patterns)
      if eligible(bufnr) then
        -- Buffer-local keymaps that only work in markdown files
        vim.keymap.set('n', '<leader>tt', function()
          vim.cmd("MarkdownTaskCounterToggle")
        end, { 
          buffer = bufnr, 
          desc = '[T]ask Counter [T]oggle',
          silent = false 
        })
        
        vim.keymap.set('n', '<leader>tr', function()
          vim.cmd("MarkdownTaskCounterRefresh")  
        end, { 
          buffer = bufnr, 
          desc = '[T]ask Counter [R]efresh',
          silent = false 
        })
        
        -- Add MiniClue entries for task counter toggles
        if _G.MiniClue and MiniClue.config then
          local task_clue = { mode = "n", keys = "<leader>t", desc = "☑ task counter" }
          table.insert(MiniClue.config.clues, task_clue)
        end
      end
    end
  })
  
  -- Remove MiniClue entry when leaving markdown files
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      if vim.tbl_contains(M._config.filetypes, vim.bo[bufnr].filetype) then
        if _G.MiniClue and MiniClue.config then
          -- Remove our task counter clue
          for i = #MiniClue.config.clues, 1, -1 do
            local clue = MiniClue.config.clues[i]
            if clue.keys == "<leader>t" and clue.desc == "☑ task counter" then
              table.remove(MiniClue.config.clues, i)
              break
            end
          end
        end
      end
    end
  })

  vim.api.nvim_create_user_command("MarkdownTaskCounterRefresh", function()
    M.refresh()
  end, { desc = "Refresh heading task counters" })

  vim.api.nvim_create_user_command("MarkdownTaskCounterToggle", function()
    M._config.enable = not M._config.enable
    local status = M._config.enable and "enabled" or "disabled"
    vim.notify("Markdown task counters " .. status, vim.log.levels.INFO)
    
    -- Clear all counters when disabling
    if not M._config.enable then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.api.nvim_buf_clear_namespace, buf, NS, 0, -1)
        end
      end
    else
      -- Refresh current buffer when enabling
      M.refresh()
    end
  end, { desc = "Toggle heading task counters" })
end

return M
