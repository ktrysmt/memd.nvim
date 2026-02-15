local config = require('memd.config')
local renderer = require('memd.renderer')
local display = require('memd.display')
local utils = require('memd.utils')

local M = {}

-- Auto-preview state
local auto_preview_enabled = false
local auto_preview_timer = nil

-- Preview current buffer
function M.preview(opts)
  opts = opts or {}

  local rendered = renderer.render_buffer(nil, opts)
  if rendered then
    local mode = opts.display_mode or config.options.display_mode
    display.show(rendered, mode)
  end
end

-- Preview visual selection
function M.preview_selection(opts)
  opts = opts or {}

  local rendered = renderer.render_selection(opts)
  if rendered then
    local mode = opts.display_mode or config.options.display_mode
    display.show(rendered, mode)
  end
end

-- Toggle auto-preview
function M.toggle_auto_preview()
  auto_preview_enabled = not auto_preview_enabled

  if auto_preview_enabled then
    utils.notify('Auto-preview enabled')
    M.setup_auto_preview()
  else
    utils.notify('Auto-preview disabled')
    M.teardown_auto_preview()
  end
end

-- Setup auto-preview autocommands
function M.setup_auto_preview()
  if not auto_preview_enabled then
    return
  end

  local group = vim.api.nvim_create_augroup('MemdAutoPreview', { clear = true })

  -- Preview on save
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = '*.md',
    callback = function()
      if auto_preview_enabled then
        M.preview()
      end
    end,
  })

  -- Preview on cursor hold (debounced)
  vim.api.nvim_create_autocmd('CursorHold', {
    group = group,
    pattern = '*.md',
    callback = function()
      if not auto_preview_enabled then
        return
      end

      -- Stop existing timer
      if auto_preview_timer then
        auto_preview_timer:stop()
      end

      -- Create new timer
      auto_preview_timer = vim.defer_fn(function()
        if auto_preview_enabled and utils.is_markdown_buffer() then
          M.preview()
        end
      end, config.options.debounce_ms)
    end,
  })
end

-- Teardown auto-preview autocommands
function M.teardown_auto_preview()
  vim.api.nvim_create_augroup('MemdAutoPreview', { clear = true })

  if auto_preview_timer then
    auto_preview_timer:stop()
    auto_preview_timer = nil
  end
end

-- Clear cache
function M.clear_cache()
  renderer.clear_cache()
end

-- Show cache statistics
function M.cache_stats()
  local stats = renderer.cache_stats()
  utils.notify(string.format('Cache entries: %d', stats.entries))
end

-- Close preview windows
function M.close()
  display.close_all()
end

-- Setup plugin
function M.setup(opts)
  -- Setup configuration
  config.setup(opts)

  -- Check if memd is available
  if not utils.check_memd_command() then
    utils.notify('memd command not found. Please install: npm install -g memd-cli', vim.log.levels.WARN)
  end

  -- Setup keymaps if enabled
  if config.options.keymaps then
    local keymaps = config.options.keymaps

    if keymaps.preview then
      vim.keymap.set('n', keymaps.preview, M.preview, { desc = 'Memd: Preview' })
      vim.keymap.set('v', keymaps.preview, M.preview_selection, { desc = 'Memd: Preview selection' })
    end

    if keymaps.toggle then
      vim.keymap.set('n', keymaps.toggle, M.toggle_auto_preview, { desc = 'Memd: Toggle auto-preview' })
    end

    if keymaps.clear_cache then
      vim.keymap.set('n', keymaps.clear_cache, M.clear_cache, { desc = 'Memd: Clear cache' })
    end
  end

  -- Enable auto-preview if configured
  if config.options.auto_preview then
    auto_preview_enabled = true
    M.setup_auto_preview()
  end
end

return M
