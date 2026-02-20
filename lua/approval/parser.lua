local fs = require("approval.fs")

local M = {}

function M.parse_output(lines)
  local failures = {}
  local seen = {}

  for i, line in ipairs(lines) do
    if line:match("Approval Mismatch") then
      local approved_path, received_path
      -- Look ahead for Approved: and Received: lines
      for j = i + 1, math.min(i + 10, #lines) do
        local ap = lines[j]:match("Approved:%s*(.+)")
        if ap then
          approved_path = vim.trim(ap)
        end
        local rp = lines[j]:match("Received:%s*(.+)")
        if rp then
          received_path = vim.trim(rp)
        end
        if approved_path and received_path then
          break
        end
      end

      if received_path and not seen[received_path] then
        seen[received_path] = true
        table.insert(failures, {
          received_path = received_path,
          approved_path = approved_path or received_path:gsub("%.received%.txt$", ".approved.txt"),
        })
      end
    end
  end

  return failures
end

function M.scan_received_files(dir)
  local received_files = fs.find_received_files(dir)
  local failures = {}

  for _, received_path in ipairs(received_files) do
    local approved_path = received_path:gsub("%.received%.txt$", ".approved.txt")
    table.insert(failures, {
      received_path = received_path,
      approved_path = approved_path,
    })
  end

  return failures
end

function M.find_failures(lines, test_dir)
  local failures = M.parse_output(lines)

  -- Fallback: scan filesystem for .received.txt files
  if #failures == 0 and test_dir then
    failures = M.scan_received_files(test_dir)
  end

  -- Deduplicate by received_path
  local seen = {}
  local unique = {}
  for _, f in ipairs(failures) do
    if not seen[f.received_path] then
      seen[f.received_path] = true
      table.insert(unique, f)
    end
  end

  return unique
end

return M
