local config = require('memd.config')
local utils = require('memd.utils')

local M = {}

-- Terminal state for interactive preview
local terminal_state = {
  bufnr = nil,
  win = nil,
  job_id = nil,
  source_file = nil,
  fs_watcher = nil,
}

-- Open terminal with memd-cli
function M.open_terminal(opts)
  opts = opts or {}

  -- Get current file path
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == '' or not utils.is_markdown_buffer() then
    utils.notify('Current buffer is not a markdown file', vim.log.levels.WARN)
    return
  end

  -- Save source file
  terminal_state.source_file = filepath

  -- Close existing terminal if any
  if terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win) then
    vim.api.nvim_win_close(terminal_state.win, true)
  end

  -- Delete existing buffer if any
  if terminal_state.bufnr and vim.api.nvim_buf_is_valid(terminal_state.bufnr) then
    vim.api.nvim_buf_delete(terminal_state.bufnr, { force = true })
  end

  -- Create buffer and set options
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.api.nvim_buf_set_name(bufnr, 'memd://' .. vim.fn.fnamemodify(filepath, ':t'))

  local win
  local display_mode = opts.display_mode or config.options.display_mode or 'split'

  if display_mode == 'floating' then
    -- Create floating window
    local floating_opts = vim.tbl_deep_extend('force', config.options.floating_opts or {}, opts.floating_opts or {})
    
    -- Calculate window size
    local width = floating_opts.width
    local height = floating_opts.height
    
    if type(width) == 'number' and width > 0 and width <= 1 then
      width = math.floor(vim.o.columns * width)
    end
    if type(height) == 'number' and height > 0 and height <= 1 then
      height = math.floor(vim.o.lines * height)
    end
    
    local row = floating_opts.row
    local col = floating_opts.col
    
    if type(row) == 'number' and row > 0 and row <= 1 then
      row = math.floor(vim.o.lines * row)
    end
    if type(col) == 'number' and col > 0 and col <= 1 then
      col = math.floor(vim.o.columns * col)
    end
    
    win = vim.api.nvim_open_win(bufnr, false, {
      relative = floating_opts.relative or 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      border = floating_opts.border or 'rounded',
      title = floating_opts.title or ' Memd Preview ',
      title_pos = floating_opts.title_pos or 'center',
      style = 'minimal',
    })
  else
    -- Create split window
    local split_cmd = opts.split_cmd or config.options.terminal_split or 'rightbelow vnew'
    vim.cmd(split_cmd)
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, bufnr)
  end

  -- Open terminal with memd-cli
  local file_dir = vim.fn.fnamemodify(filepath, ':h')
  local memd_cmd = string.format('cd %s && memd %s', vim.fn.shellescape(file_dir), vim.fn.shellescape(filepath))

  terminal_state.bufnr = bufnr
  terminal_state.win = win
  terminal_state.job_id = vim.fn.termopen(memd_cmd, {
    cwd = file_dir
  })

  -- Setup auto-reload based on method
  local auto_reload_method = config.options.auto_reload_method or 'fs_watcher'
  
  if auto_reload_method == 'fs_watcher' then
    -- Stop existing fs_watcher if any
    if terminal_state.fs_watcher then
      terminal_state.fs_watcher:stop()
    end

    -- Start file system watcher
    local watcher = vim.loop.new_fs_event()
    watcher:start(filepath, {}, vim.schedule_wrap(function(err, filename, events)
      if err then
        return
      end
      -- Reload terminal on file change
      if terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win) then
        M.open_terminal()
      end
    end))

    terminal_state.fs_watcher = watcher
  end
  -- Note: autocmd method is set up in M.setup() if auto_reload_method == 'autocmd'

  -- Go back to previous window
  vim.cmd('wincmd p')
end

-- Close terminal
function M.close_terminal()
  -- Stop file system watcher
  if terminal_state.fs_watcher then
    terminal_state.fs_watcher:stop()
    terminal_state.fs_watcher = nil
  end

  -- Close window if valid
  if terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win) then
    vim.api.nvim_win_close(terminal_state.win, true)
  end

  -- Delete buffer if valid
  if terminal_state.bufnr and vim.api.nvim_buf_is_valid(terminal_state.bufnr) then
    vim.api.nvim_buf_delete(terminal_state.bufnr, { force = true })
  end

  -- Reset state
  terminal_state.bufnr = nil
  terminal_state.win = nil
  terminal_state.job_id = nil
  terminal_state.source_file = nil
end

-- Toggle terminal (open if closed, close if open)
function M.toggle()
  if terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win) then
    -- Terminal is open, close it
    M.close_terminal()
  else
    -- Terminal is closed, open it
    M.open_terminal()
  end
end

-- Reopen terminal (for auto-reload on save)
function M.reopen_terminal()
  -- Only reload if terminal window is open
  if terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win) then
    M.open_terminal()
  end
end

-- Setup autocmd for terminal auto-reload
function M.setup_terminal_autoreload()
  local group = vim.api.nvim_create_augroup('MemdTerminalReload', { clear = true })

  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = '*.md',
    callback = function()
      M.reopen_terminal()
    end,
  })
end

-- Setup plugin
function M.setup(opts)
  -- Setup configuration
  config.setup(opts)

  -- Check if memd is available
  if not utils.check_memd_command() then
    utils.notify('memd command not found. Please install: npm install -g memd-cli', vim.log.levels.WARN)
  end

  -- Enable terminal auto-reload if using autocmd method
  if config.options.auto_reload_method == 'autocmd' then
    M.setup_terminal_autoreload()
  end
end

return M
