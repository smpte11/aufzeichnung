" aufzeichnung.nvim - A comprehensive note-taking and task tracking plugin for Neovim
" Maintainer: Based on notes module from smpte11/nvim
" License: MIT

if exists('g:loaded_aufzeichnung')
  finish
endif
let g:loaded_aufzeichnung = 1

" The plugin is primarily configured through the Lua API
" Users should call require('notes').setup({...}) in their init.lua
