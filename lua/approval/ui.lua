local fs = require("approval.fs")

local M = {}

-- Track UI state
local ui_state = {
  win_ids = {},
  buf_ids = {},
  status_win = nil,
  status_buf = nil,
  autocmd_id = nil,
}

local function close_ui()
  -- Remove autocmd
  if ui_state.autocmd_id then
    pcall(vim.api.nvim_del_autocmd, ui_state.autocmd_id)
    ui_state.autocmd_id = nil
  end

  -- Close windows
  for _, win in ipairs(ui_state.win_ids) do
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  if ui_state.status_win and vim.api.nvim_win_is_valid(ui_state.status_win) then
    pcall(vim.api.nvim_win_close, ui_state.status_win, true)
  end

  -- Wipe buffers
  for _, buf in ipairs(ui_state.buf_ids) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  if ui_state.status_buf and vim.api.nvim_buf_is_valid(ui_state.status_buf) then
    pcall(vim.api.nvim_buf_delete, ui_state.status_buf, { force = true })
  end

  ui_state.win_ids = {}
  ui_state.buf_ids = {}
  ui_state.status_win = nil
  ui_state.status_buf = nil
end

function M.is_open()
  return #ui_state.win_ids > 0
end

function M.close()
  close_ui()
end

function M.show(failures, index, on_approve, on_reject, on_navigate)
  -- Close any existing UI
  close_ui()

  if #failures == 0 then
    return
  end

  local failure = failures[index]
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines

  -- Floating window dimensions (~80% of editor)
  local width = math.floor(editor_width * 0.8)
  local height = math.floor(editor_height * 0.8)
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)

  -- Split width for two panes
  local pane_width = math.floor((width - 1) / 2) -- -1 for separator

  -- Read file contents
  local approved_lines = fs.read_file(failure.approved_path)
  local received_lines = fs.read_file(failure.received_path)

  -- Create approved buffer (left pane)
  local approved_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(approved_buf, 0, -1, false, approved_lines)
  vim.api.nvim_buf_set_option(approved_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(approved_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_name(approved_buf, "approved://" .. failure.approved_path)

  -- Create received buffer (right pane)
  local received_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(received_buf, 0, -1, false, received_lines)
  vim.api.nvim_buf_set_option(received_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(received_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_name(received_buf, "received://" .. failure.received_path)

  -- Create left floating window (approved)
  local left_win = vim.api.nvim_open_win(approved_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = pane_width,
    height = height - 3, -- Reserve space for status line
    style = "minimal",
    border = "rounded",
    title = " Approved ",
    title_pos = "center",
  })

  -- Enable diff mode on left window
  vim.api.nvim_win_call(left_win, function()
    vim.cmd("diffthis")
  end)

  -- Create right floating window (received)
  local right_win = vim.api.nvim_open_win(received_buf, false, {
    relative = "editor",
    row = row,
    col = col + pane_width + 1,
    width = pane_width,
    height = height - 3,
    style = "minimal",
    border = "rounded",
    title = " Received ",
    title_pos = "center",
  })

  -- Enable diff mode on right window
  vim.api.nvim_win_call(right_win, function()
    vim.cmd("diffthis")
  end)

  -- Create status line buffer and window
  local status_buf = vim.api.nvim_create_buf(false, true)
  local status_text = string.format(
    "  Failure %d/%d  [a]pprove  [q]uit  ]a next  [a prev",
    index,
    #failures
  )
  vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { status_text })
  vim.api.nvim_buf_set_option(status_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(status_buf, "buftype", "nofile")

  local status_win = vim.api.nvim_open_win(status_buf, false, {
    relative = "editor",
    row = row + height - 2,
    col = col,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
  })

  -- Store UI state
  ui_state.win_ids = { left_win, right_win }
  ui_state.buf_ids = { approved_buf, received_buf }
  ui_state.status_win = status_win
  ui_state.status_buf = status_buf

  -- Set up keymaps on both diff buffers
  local bufs = { approved_buf, received_buf }
  for _, buf in ipairs(bufs) do
    vim.keymap.set("n", "a", function()
      on_approve()
    end, { buffer = buf, nowait = true, desc = "Approve change" })

    vim.keymap.set("n", "q", function()
      on_reject()
    end, { buffer = buf, nowait = true, desc = "Reject change" })

    vim.keymap.set("n", "]a", function()
      on_navigate(1)
    end, { buffer = buf, nowait = true, desc = "Next failure" })

    vim.keymap.set("n", "[a", function()
      on_navigate(-1)
    end, { buffer = buf, nowait = true, desc = "Previous failure" })
  end

  -- Auto-cleanup on window close
  ui_state.autocmd_id = vim.api.nvim_create_autocmd("WinClosed", {
    callback = function(ev)
      local closed_win = tonumber(ev.match)
      for _, win in ipairs(ui_state.win_ids) do
        if closed_win == win then
          close_ui()
          return
        end
      end
    end,
  })

  -- Focus the left window
  vim.api.nvim_set_current_win(left_win)
end

function M.show_raw_output(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_name(buf, "pytest-output")

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  local width = math.floor(editor_width * 0.8)
  local height = math.floor(editor_height * 0.8)

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((editor_height - height) / 2),
    col = math.floor((editor_width - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Pytest Output ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
end

return M
