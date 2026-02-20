local config = require("approval.config")
local runner = require("approval.runner")
local parser = require("approval.parser")
local ui = require("approval.ui")
local fs = require("approval.fs")

local M = {}

local state = {
  failures = {},
  current_index = 0,
  job_id = nil,
}

local function reset_state()
  state.failures = {}
  state.current_index = 0
  state.job_id = nil
end

local function on_complete(exit_code, lines)
  state.job_id = nil

  -- Get test file directory for fallback scanning
  local test_dir = vim.fn.expand("%:p:h")

  -- Check for pytest errors (not test failures)
  -- exit_code 2 means pytest usage error, 3 means internal error
  if exit_code == 2 or exit_code == 3 then
    vim.notify("Pytest encountered an error (exit code " .. exit_code .. ")", vim.log.levels.ERROR)
    ui.show_raw_output(lines)
    return
  end

  local failures = parser.find_failures(lines, test_dir)

  if #failures == 0 then
    if exit_code == 0 then
      vim.notify("All tests passed!", vim.log.levels.INFO)
    else
      -- Tests failed but no approval mismatches detected
      vim.notify("Tests failed (no approval mismatches detected)", vim.log.levels.WARN)
      ui.show_raw_output(lines)
    end
    return
  end

  state.failures = failures
  state.current_index = 1
  M._show_current()
end

function M._show_current()
  if state.current_index < 1 or state.current_index > #state.failures then
    return
  end

  ui.show(
    state.failures,
    state.current_index,
    M.approve,
    M.reject,
    function(direction)
      M.navigate(direction)
    end
  )
end

function M.setup(opts)
  config.setup(opts)

  local maps = config.options.keymaps
  vim.keymap.set("n", maps.run_nearest, function()
    M.run_nearest()
  end, { desc = "Approval: run nearest test" })
  vim.keymap.set("n", maps.run_file, function()
    M.run_file()
  end, { desc = "Approval: run file tests" })
  vim.keymap.set("n", maps.next_failure, function()
    M.navigate(1)
  end, { desc = "Approval: next failure" })
  vim.keymap.set("n", maps.prev_failure, function()
    M.navigate(-1)
  end, { desc = "Approval: prev failure" })
end

function M.run_nearest()
  if state.job_id then
    vim.notify("A test run is already in progress", vim.log.levels.WARN)
    return
  end

  -- Close any open UI
  if ui.is_open() then
    ui.close()
    reset_state()
  end

  -- Check for unsaved changes
  if vim.bo.modified then
    vim.notify("Saving file before running tests...", vim.log.levels.INFO)
    vim.cmd("write")
  end

  -- Find nearest test function by searching backward for `def test_`
  local cursor_line = vim.fn.line(".")
  local lines = vim.api.nvim_buf_get_lines(0, 0, cursor_line, false)
  local test_name = nil

  for i = #lines, 1, -1 do
    local match = lines[i]:match("def%s+(test_%w+)")
    if match then
      test_name = match
      break
    end
  end

  if not test_name then
    vim.notify("No test function found above cursor", vim.log.levels.WARN)
    return
  end

  local file = vim.fn.expand("%:p")
  local target = file .. "::" .. test_name

  vim.notify("Running: " .. test_name, vim.log.levels.INFO)
  state.job_id = runner.run(target, on_complete)
end

function M.run_file()
  if state.job_id then
    vim.notify("A test run is already in progress", vim.log.levels.WARN)
    return
  end

  -- Close any open UI
  if ui.is_open() then
    ui.close()
    reset_state()
  end

  -- Check for unsaved changes
  if vim.bo.modified then
    vim.notify("Saving file before running tests...", vim.log.levels.INFO)
    vim.cmd("write")
  end

  local file = vim.fn.expand("%:p")
  vim.notify("Running tests in: " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
  state.job_id = runner.run(file, on_complete)
end

function M.approve()
  if #state.failures == 0 or state.current_index < 1 then
    return
  end

  local failure = state.failures[state.current_index]
  local ok = fs.copy_received_to_approved(failure)

  if ok then
    vim.notify(
      string.format("Approved (%d/%d): %s", state.current_index, #state.failures, vim.fn.fnamemodify(failure.approved_path, ":t")),
      vim.log.levels.INFO
    )
  end

  -- Advance to next failure or close
  if state.current_index < #state.failures then
    state.current_index = state.current_index + 1
    M._show_current()
  else
    ui.close()
    reset_state()
    vim.notify("All failures reviewed", vim.log.levels.INFO)
  end
end

function M.reject()
  if #state.failures == 0 or state.current_index < 1 then
    return
  end

  -- Advance to next failure or close
  if state.current_index < #state.failures then
    state.current_index = state.current_index + 1
    M._show_current()
  else
    ui.close()
    reset_state()
    vim.notify("All failures reviewed", vim.log.levels.INFO)
  end
end

function M.navigate(direction)
  if #state.failures == 0 then
    return
  end

  local new_index = state.current_index + direction
  if new_index < 1 then
    new_index = #state.failures
  elseif new_index > #state.failures then
    new_index = 1
  end

  state.current_index = new_index
  M._show_current()
end

return M
