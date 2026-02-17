" memd.nvim - Mermaid diagram preview in Neovim
" Maintainer: Your Name
" License: MIT

if exists('g:loaded_memd')
  finish
endif
let g:loaded_memd = 1

" Commands
command! -nargs=0 Memd lua require('memd').open_terminal()
command! -nargs=0 MemdToggle lua require('memd').toggle()
command! -nargs=0 MemdClose lua require('memd').close_terminal()
