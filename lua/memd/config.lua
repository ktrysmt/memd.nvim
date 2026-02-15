local M = {}

M.defaults = {
  -- Display mode: 'float', 'split', or 'replace'
  display_mode = 'float',

  -- Automatically preview on save
  auto_preview = false,

  -- Terminal width override (nil = auto-detect)
  width = nil,

  -- Use pure ASCII mode for diagrams
  use_ascii = false,

  -- Floating window configuration
  float_opts = {
    relative = 'editor',
    border = 'rounded',
    -- Width/height will be calculated dynamically
  },

  -- Split window configuration
  split_opts = {
    position = 'right', -- 'right', 'left', 'above', 'below'
    size = 80,          -- Width for vertical, height for horizontal
  },

  -- Cache configuration
  cache = {
    enabled = true,
  },

  -- Debounce time for auto-preview (ms)
  debounce_ms = 500,

  -- Keymaps (set to false to disable default keymaps)
  keymaps = {
    preview = '<leader>mp',
    toggle = '<leader>mt',
    clear_cache = '<leader>mc',
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})
end

return M
