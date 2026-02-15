local utils = require('memd.utils')
local config = require('memd.config')

local M = {}

-- Cache storage
local cache = {}

-- Execute memd command
local function execute_memd(markdown_text, opts)
  opts = opts or {}

  -- Build command
  local cmd = { 'memd', '--no-pager' }

  -- Add options
  if opts.width then
    table.insert(cmd, '--width')
    table.insert(cmd, tostring(opts.width))
  end

  if opts.use_ascii then
    table.insert(cmd, '--ascii')
  end

  -- Neovim 0.10+ uses vim.system
  if vim.system then
    local result = vim.system(cmd, {
      stdin = markdown_text,
      text = true,
    }):wait()

    if result.code == 0 then
      return { success = true, output = result.stdout }
    else
      return { success = false, error = result.stderr or 'Unknown error' }
    end
  else
    -- Fallback for older Neovim versions using jobstart
    local output = {}
    local error_output = {}

    local job_id = vim.fn.jobstart(cmd, {
      stdin = 'pipe',
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if data then
          vim.list_extend(output, data)
        end
      end,
      on_stderr = function(_, data)
        if data then
          vim.list_extend(error_output, data)
        end
      end,
    })

    if job_id <= 0 then
      return { success = false, error = 'Failed to start memd command' }
    end

    -- Send input via stdin
    vim.fn.chansend(job_id, markdown_text)
    vim.fn.chanclose(job_id, 'stdin')

    -- Wait for completion
    local exit_code = vim.fn.jobwait({ job_id }, 5000)[1]

    if exit_code == 0 then
      return { success = true, output = table.concat(output, '\n') }
    else
      return { success = false, error = table.concat(error_output, '\n') }
    end
  end
end

-- Render markdown content
function M.render(content, opts)
  opts = opts or {}

  -- Check if memd is available
  if not utils.check_memd_command() then
    utils.notify('memd command not found. Please install memd-cli: npm install -g memd-cli', vim.log.levels.ERROR)
    return nil
  end

  -- Check cache if enabled
  local use_cache = config.options.cache.enabled and not opts.no_cache
  if use_cache then
    local cache_key = utils.calculate_hash(content)
    if cache[cache_key] then
      return cache[cache_key]
    end
  end

  -- Prepare options for memd
  local memd_opts = {
    width = opts.width or config.options.width,
    use_ascii = opts.use_ascii or config.options.use_ascii,
  }

  -- Execute memd
  local result = execute_memd(content, memd_opts)

  if not result.success then
    utils.notify('Failed to render: ' .. (result.error or 'Unknown error'), vim.log.levels.ERROR)
    return nil
  end

  -- Cache result
  if use_cache then
    local cache_key = utils.calculate_hash(content)
    cache[cache_key] = result.output
  end

  return result.output
end

-- Render current buffer
function M.render_buffer(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not utils.is_markdown_buffer(bufnr) then
    utils.notify('Current buffer is not a markdown file', vim.log.levels.WARN)
    return nil
  end

  local content = utils.get_buffer_content(bufnr)
  return M.render(content, opts)
end

-- Render visual selection
function M.render_selection(opts)
  local content = utils.get_visual_selection()

  if not content or content == '' then
    utils.notify('No selection found', vim.log.levels.WARN)
    return nil
  end

  return M.render(content, opts)
end

-- Clear cache
function M.clear_cache()
  cache = {}
  utils.notify('Cache cleared')
end

-- Get cache statistics
function M.cache_stats()
  local count = 0
  for _ in pairs(cache) do
    count = count + 1
  end
  return { entries = count }
end

return M
