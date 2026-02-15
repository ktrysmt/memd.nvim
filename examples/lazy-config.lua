-- Example configuration for lazy.nvim
-- Place this in your ~/.config/nvim/lua/plugins/memd.lua

return {
  'username/memd.nvim',

  -- Lazy load on markdown files
  ft = 'markdown',

  -- Or lazy load on commands
  -- cmd = { 'MemdPreview', 'MemdToggle' },

  -- Or lazy load on keymaps
  -- keys = {
  --   { '<leader>mp', '<cmd>MemdPreview<cr>', desc = 'Memd: Preview' },
  --   { '<leader>mt', '<cmd>MemdToggle<cr>', desc = 'Memd: Toggle auto-preview' },
  -- },

  config = function()
    require('memd').setup({
      -- Display mode: 'float' or 'split'
      display_mode = 'float',

      -- Automatically preview on save
      auto_preview = false,

      -- Terminal width (nil = auto)
      width = nil,

      -- Use ASCII-only characters
      use_ascii = false,

      -- Floating window options
      float_opts = {
        relative = 'editor',
        border = 'rounded',
      },

      -- Split window options
      split_opts = {
        position = 'right',  -- 'right', 'left', 'above', 'below'
        size = 80,
      },

      -- Enable caching
      cache = {
        enabled = true,
      },

      -- Debounce time for auto-preview (ms)
      debounce_ms = 500,

      -- Keymaps
      keymaps = {
        preview = '<leader>mp',
        toggle = '<leader>mt',
        clear_cache = '<leader>mc',
      },
    })
  end,
}
