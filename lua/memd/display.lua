local config = require('memd.config')

local M = {}

-- Store references to preview windows/buffers
local state = {
  float_win = nil,
  float_buf = nil,
  split_win = nil,
  split_buf = nil,
}

-- Close floating window
local function close_float_window()
  if state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
    vim.api.nvim_win_close(state.float_win, true)
  end
  if state.float_buf and vim.api.nvim_buf_is_valid(state.float_buf) then
    vim.api.nvim_buf_delete(state.float_buf, { force = true })
  end
  state.float_win = nil
  state.float_buf = nil
end

-- Create or update floating window
function M.show_floating(rendered_text)
  if not rendered_text then
    return
  end

  -- Close existing float window
  close_float_window()

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  state.float_buf = buf

  -- Set buffer content
  local lines = vim.split(rendered_text, '\n')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'memd-preview')

  -- Calculate window size
  local width = math.min(vim.o.columns - 4, 120)
  local height = math.min(vim.o.lines - 4, #lines + 2)

  -- Window options
  local win_opts = vim.tbl_extend('force', config.options.float_opts, {
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
  })

  -- Create window
  local win = vim.api.nvim_open_win(buf, false, win_opts)
  state.float_win = win

  -- Set window options
  vim.api.nvim_win_set_option(win, 'wrap', true)
  vim.api.nvim_win_set_option(win, 'linebreak', true)

  -- Set keymaps for closing
  local close_keys = { 'q', '<Esc>' }
  for _, key in ipairs(close_keys) do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '', {
      noremap = true,
      silent = true,
      callback = close_float_window,
    })
  end

  return win, buf
end

-- Create or update split window
function M.show_split(rendered_text)
  if not rendered_text then
    return
  end

  -- Check if split already exists
  local should_create = not state.split_win or not vim.api.nvim_win_is_valid(state.split_win)

  if should_create then
    -- Create new split
    local split_cmd
    local split_opts = config.options.split_opts

    if split_opts.position == 'right' then
      split_cmd = 'vsplit'
    elseif split_opts.position == 'left' then
      split_cmd = 'leftabove vsplit'
    elseif split_opts.position == 'above' then
      split_cmd = 'split'
    else -- below
      split_cmd = 'belowright split'
    end

    vim.cmd(split_cmd)

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buf)

    state.split_win = vim.api.nvim_get_current_win()
    state.split_buf = buf

    -- Set window size
    if split_opts.position == 'right' or split_opts.position == 'left' then
      vim.api.nvim_win_set_width(state.split_win, split_opts.size)
    else
      vim.api.nvim_win_set_height(state.split_win, split_opts.size)
    end

    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'memd-preview')

    -- Go back to previous window
    vim.cmd('wincmd p')
  end

  -- Update content
  local lines = vim.split(rendered_text, '\n')
  vim.api.nvim_buf_set_option(state.split_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.split_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.split_buf, 'modifiable', false)

  return state.split_win, state.split_buf
end

-- Show preview based on configured display mode
function M.show(rendered_text, mode)
  mode = mode or config.options.display_mode

  if mode == 'float' then
    return M.show_floating(rendered_text)
  elseif mode == 'split' then
    return M.show_split(rendered_text)
  else
    -- Default to float if mode is unknown
    return M.show_floating(rendered_text)
  end
end

-- Close all preview windows
function M.close_all()
  close_float_window()

  if state.split_win and vim.api.nvim_win_is_valid(state.split_win) then
    vim.api.nvim_win_close(state.split_win, true)
  end

  state.split_win = nil
  state.split_buf = nil
end

-- Check if preview is visible
function M.is_visible()
  return (state.float_win and vim.api.nvim_win_is_valid(state.float_win))
    or (state.split_win and vim.api.nvim_win_is_valid(state.split_win))
end

return M
