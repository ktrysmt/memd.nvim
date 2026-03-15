local M = {}

M.defaults = {
  -- Display mode: 'split' or 'floating'
  display_mode = 'split',

  -- Terminal split command for opening memd-cli (used when display_mode = 'split')
  terminal_split = 'rightbelow vnew',

  -- Floating window options (used when display_mode = 'floating')
  floating_opts = {
    relative = 'editor',
    width = 0.8,
    height = 0.8,
    row = 0.1,
    col = 0.1,
    border = 'rounded',
    title = ' Memd Preview ',
    title_pos = 'center',
  },

  -- Auto-reload method: 'fs_watcher' or 'autocmd'
  -- fs_watcher: detects changes from any editor (default)
  -- autocmd: only detects saves from within Neovim
  auto_reload_method = 'fs_watcher',

  -- memd CLI arguments
  memd_args = {
    no_pager = false,      -- disable pager (less)
    no_mouse = false,      -- disable mouse scroll in pager
    no_color = false,      -- disable colored output
    width = nil,           -- terminal width override; nil = not set, 'auto' = match window width
    ascii = false,         -- use pure ASCII mode for diagrams (default: unicode)
    theme = nil,           -- color theme (also sets MEMD_THEME env var for v2.1.0+)
                           -- e.g., 'nord', 'dracula', 'one-dark', 'github-dark', 'github-light',
                           -- 'solarized-dark', 'solarized-light', 'catppuccin-mocha', 'catppuccin-latte',
                           -- 'tokyo-night', 'tokyo-night-storm', 'tokyo-night-light',
                           -- 'nord-light', 'zinc-dark', 'zinc-light'
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})
end

return M
