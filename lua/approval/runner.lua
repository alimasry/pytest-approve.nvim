local config = require("approval.config")

local M = {}

--- Resolve the plugin's python/ directory from this file's location.
local function get_python_dir()
  local source = debug.getinfo(1, "S").source:sub(2) -- strip leading "@"
  -- source is <root>/lua/approval/runner.lua → go up 3 dirs to reach <root>
  local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
  return plugin_root .. "/python"
end

function M.run(target, on_complete)
  local cmd = config.options.pytest_cmd
  local args = vim.deepcopy(config.options.pytest_args)

  local env = nil

  if config.options.inject_reporter_plugin then
    -- Inject the bundled pytest plugin so users don't need a conftest.py
    local python_dir = get_python_dir()
    local existing = vim.env.PYTHONPATH or ""
    local sep = existing ~= "" and ":" or ""
    local new_pythonpath = python_dir .. sep .. existing

    table.insert(args, "-p")
    table.insert(args, "approval_pytest_plugin")

    env = { PYTHONPATH = new_pythonpath }
  end

  table.insert(args, target)

  -- Build the full command as a list for jobstart
  local full_cmd = vim.list_extend({ cmd }, args)

  local stdout_lines = {}
  local stderr_lines = {}

  local job_opts = {
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
  }

  if env then
    job_opts.env = env
  end

  local job_id = vim.fn.jobstart(full_cmd, job_opts)

  if job_id <= 0 then
    vim.notify("Failed to start pytest", vim.log.levels.ERROR)
    return nil
  end

  return job_id
end

return M
