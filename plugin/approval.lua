if vim.g.loaded_approval then
  return
end
vim.g.loaded_approval = true

vim.api.nvim_create_user_command("ApprovalRunNearest", function()
  require("approval").run_nearest()
end, { desc = "Run nearest approval test" })

vim.api.nvim_create_user_command("ApprovalRunFile", function()
  require("approval").run_file()
end, { desc = "Run approval tests in current file" })

vim.api.nvim_create_user_command("ApprovalApprove", function()
  require("approval").approve()
end, { desc = "Approve current failure" })

vim.api.nvim_create_user_command("ApprovalReject", function()
  require("approval").reject()
end, { desc = "Reject current failure" })
