# memd.nvim

A Neovim plugin for previewing Mermaid diagrams in Markdown files using [memd-cli](https://github.com/ktrysmt/memd).

## Features

- 🎨 Preview Mermaid diagrams as ASCII art in Neovim
- 🪟 Multiple display modes: floating window or split window
- ⚡ Caching for better performance
- 🔄 Auto-preview on save or cursor hold
- 📝 Visual selection preview support
- ⌨️ Customizable keymaps

## Requirements

- Neovim >= 0.9.0
- [memd-cli](https://github.com/ktrysmt/memd) installed globally

```bash
npm install -g memd-cli
```

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'username/memd.nvim',
  ft = 'markdown',  -- Lazy load on markdown files
  config = function()
    require('memd').setup({
      -- Default configuration
      display_mode = 'float',  -- 'float' or 'split'
      auto_preview = false,
      keymaps = {
        preview = '<leader>mp',
        toggle = '<leader>mt',
        clear_cache = '<leader>mc',
      },
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'username/memd.nvim',
  ft = 'markdown',
  config = function()
    require('memd').setup()
  end
}
```

## Configuration

Default configuration:

```lua
require('memd').setup({
  -- Display mode: 'float' or 'split'
  display_mode = 'float',

  -- Auto-preview on save/cursor hold
  auto_preview = false,

  -- Terminal width override (nil = auto-detect)
  width = nil,

  -- Use pure ASCII mode for diagrams
  use_ascii = false,

  -- Floating window options
  float_opts = {
    relative = 'editor',
    border = 'rounded',
  },

  -- Split window options
  split_opts = {
    position = 'right',  -- 'right', 'left', 'above', 'below'
    size = 80,           -- Width for vertical, height for horizontal
  },

  -- Cache configuration
  cache = {
    enabled = true,
  },

  -- Debounce time for auto-preview (ms)
  debounce_ms = 500,

  -- Keymaps (set to false to disable)
  keymaps = {
    preview = '<leader>mp',
    toggle = '<leader>mt',
    clear_cache = '<leader>mc',
  },
})
```

## Usage

### Commands

- `:MemdPreview` - Preview current buffer
- `:MemdPreviewSelection` - Preview visual selection
- `:MemdToggle` - Toggle auto-preview mode
- `:MemdClose` - Close preview windows
- `:MemdClearCache` - Clear render cache
- `:MemdCacheStats` - Show cache statistics

### Keymaps (default)

- `<leader>mp` - Preview (normal mode: buffer, visual mode: selection)
- `<leader>mt` - Toggle auto-preview
- `<leader>mc` - Clear cache

### Example Workflow

1. Open a markdown file with Mermaid diagrams
2. Press `<leader>mp` to preview
3. The rendered diagram appears in a floating window
4. Press `q` or `<Esc>` to close the preview
5. Enable auto-preview with `<leader>mt` for live updates

## Display Modes

### Floating Window (default)

Displays the preview in a centered floating window. Press `q` or `<Esc>` to close.

```lua
require('memd').setup({
  display_mode = 'float',
})
```

### Split Window

Displays the preview in a persistent split window that updates with new previews.

```lua
require('memd').setup({
  display_mode = 'split',
  split_opts = {
    position = 'right',  -- Position of the split
    size = 80,           -- Width in columns
  },
})
```

## Auto-Preview Mode

Enable automatic previews on file save or cursor hold:

```lua
require('memd').setup({
  auto_preview = true,  -- Enable by default
  debounce_ms = 500,    -- Wait time before preview
})
```

Or toggle at runtime with `:MemdToggle` or `<leader>mt`.

## Advanced Usage

### Programmatic API

```lua
local memd = require('memd')

-- Preview with custom options
memd.preview({
  display_mode = 'float',
  width = 100,
  use_ascii = true,
  no_cache = true,
})

-- Preview selection
memd.preview_selection()

-- Clear cache
memd.clear_cache()

-- Close all previews
memd.close()
```

### Custom Keymaps

Disable default keymaps and set your own:

```lua
require('memd').setup({
  keymaps = false,  -- Disable defaults
})

-- Set custom keymaps
vim.keymap.set('n', '<C-p>', require('memd').preview)
vim.keymap.set('v', '<C-p>', require('memd').preview_selection)
```

## Troubleshooting

### Command not found

If you see "memd command not found", ensure memd-cli is installed:

```bash
npm install -g memd-cli
which memd  # Should show the path
```

### Display issues

For better diagram display, ensure your terminal supports Unicode. If you experience issues, try ASCII mode:

```lua
require('memd').setup({
  use_ascii = true,
})
```

## License

MIT

## Related Projects

- [memd-cli](https://github.com/ktrysmt/memd) - CLI tool for rendering Mermaid diagrams
- [markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim) - Markdown preview in browser
