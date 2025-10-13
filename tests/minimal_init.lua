-- Minimal init file for running tests with plenary.nvim

-- Add the plugin directory to the runtime path
vim.cmd([[set runtimepath+=.]])

-- Add plenary.nvim to the runtime path (assumes it's installed)
local plenary_dir = vim.fn.stdpath('data') .. '/lazy/plenary.nvim'
if vim.fn.isdirectory(plenary_dir) == 1 then
	vim.opt.runtimepath:append(plenary_dir)
else
	-- Try alternative paths
	local alt_paths = {
		vim.fn.expand('~/.local/share/nvim/lazy/plenary.nvim'),
		vim.fn.expand('~/.local/share/nvim/site/pack/packer/start/plenary.nvim'),
		vim.fn.expand('~/.config/nvim/pack/packer/start/plenary.nvim'),
	}

	for _, path in ipairs(alt_paths) do
		if vim.fn.isdirectory(path) == 1 then
			vim.opt.runtimepath:append(path)
			break
		end
	end
end

-- Add sqlite.lua to the runtime path (for task tracking tests)
local sqlite_dir = vim.fn.stdpath('data') .. '/lazy/sqlite.lua'
if vim.fn.isdirectory(sqlite_dir) == 1 then
	vim.opt.runtimepath:append(sqlite_dir)
else
	local alt_paths = {
		vim.fn.expand('~/.local/share/nvim/lazy/sqlite.lua'),
		vim.fn.expand('~/.local/share/nvim/site/pack/packer/start/sqlite.lua'),
	}

	for _, path in ipairs(alt_paths) do
		if vim.fn.isdirectory(path) == 1 then
			vim.opt.runtimepath:append(path)
			break
		end
	end
end

-- Set up test environment
vim.g.aufzeichnung_test = true

-- Minimal options for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.hidden = true
vim.opt.termguicolors = true

-- Disable some features that might interfere with tests
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Ensure we can require the plugin
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Print diagnostic info
print('Test environment initialized')
print('Neovim version: ' .. vim.version().major .. '.' .. vim.version().minor .. '.' .. vim.version().patch)
print('Runtime paths configured')

-- Load plenary
local ok, plenary = pcall(require, 'plenary')
if ok then
	print('✓ plenary.nvim loaded')
else
	print('✗ plenary.nvim not found - tests will fail')
	print('  Please install plenary.nvim first:')
	print('  https://github.com/nvim-lua/plenary.nvim')
end

-- Check for sqlite
local ok_sqlite, sqlite = pcall(require, 'sqlite')
if ok_sqlite then
	print('✓ sqlite.lua loaded')
else
	print('⚠ sqlite.lua not found - some integration tests may fail')
end
