local M = {}

-- Check if memd command is available
function M.check_memd_command()
  local handle = io.popen('which memd 2>/dev/null')
  if not handle then
    return false
  end

  local result = handle:read('*a')
  handle:close()

  return result ~= ''
end

-- Get buffer content as string
function M.get_buffer_content(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, '\n')
end

-- Get visual selection content
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2] - 1
  local end_line = end_pos[2]

  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  return table.concat(lines, '\n')
end

-- Calculate hash for caching
function M.calculate_hash(content)
  return vim.fn.sha256(content)
end

-- Get cache key for buffer
function M.get_cache_key(bufnr, content)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  content = content or M.get_buffer_content(bufnr)
  local hash = M.calculate_hash(content)
  return string.format('%d:%s', bufnr, hash)
end

-- Notify user with message
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify('[memd] ' .. msg, level)
end

-- Check if buffer is a markdown file
function M.is_markdown_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  return filetype == 'markdown'
end

return M
