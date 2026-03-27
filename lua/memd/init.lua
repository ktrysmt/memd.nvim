local config = require('memd.config')
local utils = require('memd.utils')

local M = {}

-- Build memd CLI command with configured arguments
local function build_memd_cmd(filepath, win)
  local args = { 'memd' }
  local memd_args = config.options.memd_args or {}

  if memd_args.no_pager then
    table.insert(args, '--no-pager')
  end
  if memd_args.no_mouse then
    table.insert(args, '--no-mouse')
  end
  if memd_args.no_color then
    table.insert(args, '--no-color')
  end
  if memd_args.width == 'auto' and win and vim.api.nvim_win_is_valid(win) then
    local win_width = vim.api.nvim_win_get_width(win)
    table.insert(args, '--width')
    table.insert(args, tostring(win_width))
  elseif type(memd_args.width) == 'number' then
    table.insert(args, '--width')
    table.insert(args, tostring(memd_args.width))
  end
  if memd_args.ascii then
    table.insert(args, '--ascii')
  end
  if memd_args.theme then
    table.insert(args, '--theme')
    table.insert(args, memd_args.theme)
  end

  -- Use filename only (relative to cwd) to avoid memd v2's path traversal restriction
  table.insert(args, vim.fn.shellescape(vim.fn.fnamemodify(filepath, ':t')))
  return table.concat(args, ' ')
end

-- Terminal state for interactive preview
local terminal_state = {
  bufnr = nil,
  win = nil,
  job_id = nil,
  source_file = nil,
  fs_watcher = nil,
  watched_file = nil,
  saved_width = nil,
  saved_height = nil,
  reload_timer = nil,
  reload_lock = false,
  last_mtime = nil,
}

-- Open terminal with memd-cli
function M.open_terminal(opts)
  opts = opts or {}

  -- Get file path: use provided path (for reload) or current buffer
  local filepath = opts.filepath
  if not filepath then
    filepath = vim.api.nvim_buf_get_name(0)
    if filepath == '' or not utils.is_markdown_buffer() then
      utils.notify('Current buffer is not a markdown file', vim.log.levels.WARN)
      return
    end
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
  vim.bo[bufnr].filetype = 'memd'
  vim.api.nvim_buf_set_name(bufnr, 'memd://' .. vim.fn.fnamemodify(filepath, ':t'))

  local win
  local prev_win = vim.api.nvim_get_current_win()
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
  local memd_cmd = build_memd_cmd(filepath, win)

  terminal_state.bufnr = bufnr
  terminal_state.win = win

  local term_opts = { cwd = file_dir }

  -- Set MEMD_THEME env var if theme is configured (memd v2.1.0+)
  local memd_args = config.options.memd_args or {}
  if memd_args.theme then
    term_opts.env = { MEMD_THEME = memd_args.theme }
  end

  terminal_state.job_id = vim.fn.termopen(memd_cmd, term_opts)

  -- Restore saved window size if available
  if terminal_state.saved_width and terminal_state.saved_height then
    vim.api.nvim_win_set_width(win, terminal_state.saved_width)
    vim.api.nvim_win_set_height(win, terminal_state.saved_height)
  end

  -- Setup auto-reload based on method
  local auto_reload_method = config.options.auto_reload_method or 'fs_watcher'

  if auto_reload_method == 'fs_watcher' then
    -- Recreate watcher only when watching a different file
    if terminal_state.fs_watcher and terminal_state.watched_file ~= filepath then
      terminal_state.fs_watcher:stop()
      terminal_state.fs_watcher:close()
      terminal_state.fs_watcher = nil
      terminal_state.watched_file = nil
    end

    if not terminal_state.fs_watcher then
      local watcher = vim.loop.new_fs_event()
      local function watcher_callback(err, filename, events)
        if err then
          return
        end
        -- Restart watcher to track new inode.
        -- On macOS/Linux, :w may replace the file (new inode via rename),
        -- so the watcher must be restarted on the current path.
        watcher:stop()
        watcher:start(filepath, {}, vim.schedule_wrap(watcher_callback))
        -- Only reload when file content actually changed (mtime check).
        -- kqueue (macOS) fires NOTE_ATTRIB on atime updates (e.g. reads),
        -- which would cause spurious reloads on every focus change.
        local stat = vim.loop.fs_stat(filepath)
        if not stat then
          return
        end
        if terminal_state.last_mtime
            and stat.mtime.sec == terminal_state.last_mtime.sec
            and (stat.mtime.nsec or 0) == (terminal_state.last_mtime.nsec or 0) then
          return
        end
        terminal_state.last_mtime = stat.mtime
        -- Skip if reload is in progress (prevents self-triggered loops)
        if terminal_state.reload_lock then
          return
        end
        if not (terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win)) then
          return
        end
        -- Debounce: cancel pending timer and schedule new one
        if terminal_state.reload_timer then
          terminal_state.reload_timer:stop()
          terminal_state.reload_timer:close()
          terminal_state.reload_timer = nil
        end
        local timer = vim.loop.new_timer()
        terminal_state.reload_timer = timer
        timer:start(200, 0, vim.schedule_wrap(function()
          timer:stop()
          timer:close()
          terminal_state.reload_timer = nil
          if not (terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win)) then
            return
          end
          terminal_state.reload_lock = true
          M.open_terminal({
            focus = config.options.auto_reload_focus,
            filepath = terminal_state.source_file,
          })
          vim.defer_fn(function()
            terminal_state.reload_lock = false
          end, 500)
        end))
      end
      watcher:start(filepath, {}, vim.schedule_wrap(watcher_callback))
      terminal_state.fs_watcher = watcher
      terminal_state.watched_file = filepath
      -- Record initial mtime to avoid spurious reload on first event
      local init_stat = vim.loop.fs_stat(filepath)
      if init_stat then
        terminal_state.last_mtime = init_stat.mtime
      end
    end
  end
  -- Note: autocmd method is set up in M.setup() if auto_reload_method == 'autocmd'

  -- Setup WinResized autocmd to track manual resizing
  local augroup = vim.api.nvim_create_augroup('Memd_' .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd('WinResized', {
    group = augroup,
    callback = function()
      -- Check if the resized window is our memd terminal window
      if terminal_state.win and vim.api.nvim_win_is_valid(terminal_state.win) then
        local buf = vim.api.nvim_win_get_buf(terminal_state.win)
        if buf == bufnr then
          terminal_state.saved_width = vim.api.nvim_win_get_width(terminal_state.win)
          terminal_state.saved_height = vim.api.nvim_win_get_height(terminal_state.win)
        end
      end
    end
  })

  -- Cleanup autocmd when buffer is deleted
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = bufnr,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_name, 'Memd_' .. bufnr)
    end,
    once = true,
  })

  -- Save initial window size if not already saved
  if not terminal_state.saved_width then
    terminal_state.saved_width = vim.api.nvim_win_get_width(win)
    terminal_state.saved_height = vim.api.nvim_win_get_height(win)
  end

  -- Focus terminal window and enter Insert mode (skip on auto-reload)
  if opts.focus ~= false then
    vim.api.nvim_set_current_win(win)
    vim.cmd('startinsert')
  else
    -- Restore focus to the previous window
    if prev_win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end
end

-- Close terminal
function M.close_terminal()
  -- Stop reload timer
  if terminal_state.reload_timer then
    terminal_state.reload_timer:stop()
    terminal_state.reload_timer:close()
    terminal_state.reload_timer = nil
  end
  terminal_state.reload_lock = false

  -- Stop file system watcher
  if terminal_state.fs_watcher then
    terminal_state.fs_watcher:stop()
    terminal_state.fs_watcher:close()
    terminal_state.fs_watcher = nil
  end
  terminal_state.watched_file = nil
  terminal_state.last_mtime = nil

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
    M.open_terminal({
      focus = config.options.auto_reload_focus,
      filepath = terminal_state.source_file,
    })
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
