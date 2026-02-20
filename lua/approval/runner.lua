local config = require("approval.config")

local M = {}

function M.run(target, on_complete)
  local cmd = config.options.pytest_cmd
  local args = vim.deepcopy(config.options.pytest_args)
  table.insert(args, target)

  -- Build the full command as a list for jobstart
  local full_cmd = vim.list_extend({ cmd }, args)

  local stdout_lines = {}
  local stderr_lines = {}

  local job_id = vim.fn.jobstart(full_cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout_lines, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_lines, data)
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        -- Merge stdout and stderr for full output
        local all_lines = vim.list_extend(vim.deepcopy(stdout_lines), stderr_lines)
        on_complete(exit_code, all_lines)
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start pytest", vim.log.levels.ERROR)
    return nil
  end

  return job_id
end

return M
