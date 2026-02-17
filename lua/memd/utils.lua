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

-- Notify user with message
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify('[memd] ' .. msg, level)
end

-- Check if buffer is a markdown file
function M.is_markdown_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype
  return filetype == 'markdown'
end

return M
