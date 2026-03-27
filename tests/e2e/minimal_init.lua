-- Minimal Neovim config for E2E testing
-- Usage: nvim --clean -u tests/e2e/minimal_init.lua <file>

local init_path = debug.getinfo(1, 'S').source:sub(2)
local project_root = vim.fn.fnamemodify(init_path, ':h:h:h')

vim.opt.rtp:prepend(project_root)
vim.cmd('filetype plugin indent on')
vim.cmd('runtime! plugin/**/*.vim')

require('memd').setup({
  auto_reload_method = 'fs_watcher',
  auto_reload_focus = false,
  memd_args = {
    no_pager = true,
  },
})

-- Terminal mode keymaps for E2E testing
-- <C-w>h sequence fails when sent as separate tuistory presses due to timing
vim.keymap.set('t', '<F2>', '<C-\\><C-n><C-w>h', { silent = true })
