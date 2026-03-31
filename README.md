# memd.nvim

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Neovim](https://img.shields.io/badge/NeoVim-%E2%89%A5%200.9.0-green.svg)

A Neovim plugin wrapper for [memd-cli](https://github.com/ktrysmt/memd) - preview Mermaid diagrams in Markdown files directly in your terminal.

## Features

- Quick terminal preview of Mermaid diagrams using memd-cli
- Multiple display modes: split window or floating window
- Auto-reload on file changes (fs_watcher or autocmd)
- Preserves window size across auto-reloads and reopens
- Customizable split window positioning and floating window options
- Simple keymaps for toggling terminal preview
- Lightweight wrapper around memd-cli

## Requirements

- Neovim >= 0.9.0
- **[memd-cli](https://github.com/ktrysmt/memd)** - Required CLI tool for rendering Mermaid diagrams

### Installing memd-cli

**This plugin requires memd-cli to be installed first:**

```bash
npm install -g memd-cli
```

Verify installation:
```bash
which memd
memd --version
```

If you encounter permission issues with global npm install:
```bash
# Install to user directory
npm install -g --prefix ~/.local memd-cli

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"
```

## Installation

### Setting up

* Using [lazy.nvim](https://github.com/folke/lazy.nvim)

**Minimal:**
```lua
{
  'ktrysmt/memd.nvim',
  ft = 'markdown',
  config = function()
    require('memd').setup()
  end,
}
```

**Default full configuration:**
```lua
{
  'ktrysmt/memd.nvim',
  ft = 'markdown',
  config = function()
    require('memd').setup({
      -- Display mode: 'split' or 'floating'
      display_mode = 'split',

      -- Terminal split command (used when display_mode = 'split')
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

      -- memd CLI arguments
      memd_args = {
        no_pager = false,      -- disable pager (less)
        no_mouse = false,      -- disable mouse scroll in pager
        no_color = false,      -- disable colored output
        width = nil,           -- terminal width override; nil = not set, 'auto' = match window width
        ascii = false,         -- use pure ASCII mode for diagrams (default: unicode)
        theme = nil,           -- color theme (also sets MEMD_THEME env var for v2.1.0+)
      },
    })

    -- Set up keymaps (optional)
    vim.keymap.set('n', '<leader>mt', require('memd').toggle, { desc = 'Memd: Toggle preview' })
  end,
}
```

## Configuration

### Display Modes

**Split Mode (default):**
```lua
require('memd').setup({
  display_mode = 'split',
  terminal_split = 'rightbelow vnew',  -- Customize split command
})
```

**Floating Window Mode:**
```lua
require('memd').setup({
  display_mode = 'floating',
  floating_opts = {
    width = 0.9,     -- 90% of screen width
    height = 0.9,    -- 90% of screen height
    border = 'double',
  },
})
```

### Terminal Split Options

When using `display_mode = 'split'`, customize how the terminal window opens:

| Option | Description |
|--------|-------------|
| `'rightbelow vnew'` | Open on the right (default) |
| `'leftabove vnew'` | Open on the left |
| `'botright split'` | Open at the bottom |
| `'topleft split'` | Open at the top |
| `'tabnew'` | Open in a new tab |

You can use any valid Neovim window split command.

### Auto-reload Methods

**fs_watcher (default):**
- Uses Neovim's file system watcher
- Detects changes from any editor or external tools
- More responsive to external changes

```lua
require('memd').setup({
  auto_reload_method = 'fs_watcher',
})
```

**autocmd:**
- Uses Neovim's BufWritePost autocmd
- Only detects saves within Neovim
- More predictable, less system overhead

```lua
require('memd').setup({
  auto_reload_method = 'autocmd',
})
```

### memd CLI Arguments

Pass options directly to the memd CLI via `memd_args`:

```lua
require('memd').setup({
  memd_args = {
    no_pager = true,       -- disable pager (less); recommended true inside Neovim
    no_mouse = false,      -- disable mouse scroll in pager
    no_color = false,      -- disable colored output
    width = nil,           -- terminal width override; nil = not set, 'auto' = match window width
    ascii = false,         -- use pure ASCII mode for diagrams (default: unicode)
    theme = nil,           -- color theme (also sets MEMD_THEME env var for v2.1.0+)
  },
})
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `no_pager` | boolean | `false` | Disable pager (less) |
| `no_mouse` | boolean | `false` | Disable mouse scroll in pager |
| `no_color` | boolean | `false` | Disable colored output and syntax highlighting |
| `width` | number/string/nil | `nil` | Terminal width override. `nil` = not set, `'auto'` = match preview window width |
| `ascii` | boolean | `false` | Use pure ASCII mode for diagrams instead of Unicode |
| `theme` | string/nil | `nil` | Color theme. Also sets `MEMD_THEME` env var (v2.1.0+). Available themes: `'nord'`, `'dracula'`, `'one-dark'`, `'github-dark'`, `'github-light'`, `'solarized-dark'`, `'solarized-light'`, `'catppuccin-mocha'`, `'catppuccin-latte'`, `'tokyo-night'`, `'tokyo-night-storm'`, `'tokyo-night-light'`, `'nord-light'`, `'zinc-dark'`, `'zinc-light'` |

## Usage

### Commands

- `:Memd` - Open interactive terminal preview with memd-cli
- `:MemdToggle` - Toggle terminal preview (open if closed, close if open)
- `:MemdClose` - Close terminal preview

### Keymaps

No default keymaps are provided. Set up your own keymaps:

```lua
-- Toggle preview
vim.keymap.set('n', '<leader>mt', require('memd').toggle, { desc = 'Memd: Toggle preview' })

-- Open preview
vim.keymap.set('n', '<leader>mo', require('memd').open_terminal, { desc = 'Memd: Open preview' })

-- Close preview
vim.keymap.set('n', '<leader>mc', require('memd').close_terminal, { desc = 'Memd: Close preview' })
```

### Window Behavior

The plugin automatically preserves your window size when you:
- Manually resize the preview window
- Save the file and trigger auto-reload
- Close and reopen the preview

This ensures a consistent viewing experience without having to resize the window every time.

## Troubleshooting

### Auto-reload not working

Auto-reload uses fs_watcher to detect file changes. Ensure:
- Your file has the `.md` extension
- The file is being saved to disk (not just the buffer)

## Testing

### E2E Tests

E2E tests use [tuistory](https://www.npmjs.com/package/tuistory) to drive Neovim in a virtual terminal.

Prerequisites:

- Node.js + `npm install` (tuistory をローカルインストール)
- `nvim`
- `memd` (memd-cli)

Run:

```bash
bash tests/e2e/run.sh
```

Tests launch Neovim with a minimal config (`tests/e2e/minimal_init.lua`) and verify plugin behavior via terminal snapshots. Temporary files created during tests are prefixed with `tmp_` and gitignored.

## License

MIT

## Related Projects

- [memd-cli](https://github.com/ktrysmt/memd) - CLI tool for rendering Mermaid diagrams
