local M = {}

M.defaults = {
  pytest_cmd = "pytest",
  pytest_args = { "-v", "--tb=short" },
  approved_dir = nil, -- nil means same directory as test file
  inject_reporter_plugin = true,
  keymaps = {
    run_nearest = "<leader>tn",
    run_file = "<leader>tf",
    next_failure = "]a",
    prev_failure = "[a",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
