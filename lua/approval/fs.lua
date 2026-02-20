local M = {}

function M.read_file(path)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  return vim.fn.readfile(path)
end

function M.file_exists(path)
  return vim.fn.filereadable(path) == 1
end

function M.copy_received_to_approved(failure)
  local received = failure.received_path
  local approved = failure.approved_path

  if not M.file_exists(received) then
    vim.notify("Received file no longer exists: " .. received, vim.log.levels.WARN)
    return false
  end

  -- Create parent directory if needed
  local parent = vim.fn.fnamemodify(approved, ":h")
  if vim.fn.isdirectory(parent) == 0 then
    vim.fn.mkdir(parent, "p")
  end

  local result = vim.fn.rename(received, approved)
  if result ~= 0 then
    vim.notify("Failed to rename received to approved", vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.find_received_files(dir)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    return {}
  end
  return vim.fn.glob(dir .. "/**/*.received.txt", false, true)
end

return M
