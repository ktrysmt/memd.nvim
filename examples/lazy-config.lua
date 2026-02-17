-- Example configuration for lazy.nvim
-- Place this in your ~/.config/nvim/lua/plugins/memd.lua

return {
  'ktrysmt/memd.nvim',

  -- Lazy load on markdown files
  ft = 'markdown',

  -- Or lazy load on commands
  -- cmd = { 'Memd', 'MemdToggle', 'MemdClose' },

  -- Or lazy load on keymaps
  -- keys = {
  --   { '<leader>mt', '<cmd>MemdToggle<cr>', desc = 'Memd: Toggle terminal' },
  -- },

  config = function()
    require('memd').setup({
      -- Display mode: 'split' or 'floating'
      display_mode = 'split',

      -- Terminal split command (used when display_mode = 'split')
      -- Options: 'rightbelow vnew', 'leftabove vnew', 'botright split', 'topleft split', 'tabnew'
      terminal_split = 'rightbelow vnew',

      -- Floating window options (used when display_mode = 'floating')
      floating_opts = {
        relative = 'editor',
        width = 0.8,          -- 80% of editor width
        height = 0.8,         -- 80% of editor height
        row = 0.1,            -- 10% from top
        col = 0.1,            -- 10% from left
        border = 'rounded',   -- 'none', 'single', 'double', 'rounded', 'solid', 'shadow'
        title = ' Memd Preview ',
        title_pos = 'center', -- 'left', 'center', 'right'
      },

      -- Auto-reload method: 'fs_watcher' or 'autocmd'
      -- fs_watcher: detects file changes from any editor (default)
      -- autocmd: only detects saves from within Neovim (BufWritePost)
      auto_reload_method = 'fs_watcher',
    })

    -- Set up keymaps (optional)
    vim.keymap.set('n', '<leader>mt', require('memd').toggle, { desc = 'Memd: Toggle preview' })
    vim.keymap.set('n', '<leader>mo', require('memd').open_terminal, { desc = 'Memd: Open preview' })
    vim.keymap.set('n', '<leader>mc', require('memd').close_terminal, { desc = 'Memd: Close preview' })
  end,
}
