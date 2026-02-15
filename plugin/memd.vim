" memd.nvim - Mermaid diagram preview in Neovim
" Maintainer: Your Name
" License: MIT

if exists('g:loaded_memd')
  finish
endif
let g:loaded_memd = 1

" Commands
command! -nargs=0 MemdPreview lua require('memd').preview()
command! -nargs=0 MemdPreviewSelection lua require('memd').preview_selection()
command! -nargs=0 MemdToggle lua require('memd').toggle_auto_preview()
command! -nargs=0 MemdClose lua require('memd').close()
command! -nargs=0 MemdClearCache lua require('memd').clear_cache()
command! -nargs=0 MemdCacheStats lua require('memd').cache_stats()
