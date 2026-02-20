# pytest-approve.nvim

A Neovim plugin that integrates with Python's [approvaltests](https://github.com/approvals/ApprovalTests.Python) library. Run pytest from within Neovim and review approval mismatches in a side-by-side diff popup.

## Features

- Async pytest execution (non-blocking)
- Side-by-side diff floating windows with scroll sync
- Approve or reject changes with a single keypress
- Navigate through multiple failures
- Auto-detects approval mismatches from pytest output

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "alielmasry/pytest-approve.nvim",
  config = function()
    require("approval").setup()
  end,
  ft = "python",
}
```

## Setup

Add a `conftest.py` to your test directory to prevent approvaltests from launching external diff tools:

```python
import pytest
from approvaltests import set_default_reporter
from approvaltests.reporters.report_quietly import ReportQuietly


@pytest.fixture(scope="session", autouse=True)
def disable_approval_diff_tools():
    """Prevent approvaltests from launching external diff tools."""
    set_default_reporter(ReportQuietly())
```

## Keymaps

| Key | Action |
|---|---|
| `<leader>tn` | Run nearest test |
| `<leader>tf` | Run all tests in file |
| `]a` / `[a` | Next / previous failure |

Inside the diff popup:

| Key | Action |
|---|---|
| `a` | Approve (rename `.received.txt` to `.approved.txt`) |
| `q` | Reject / close |
| `]a` / `[a` | Next / previous failure |

## Commands

- `:ApprovalRunNearest` — Run the test nearest to cursor
- `:ApprovalRunFile` — Run all tests in the current file
- `:ApprovalApprove` — Approve the current failure
- `:ApprovalReject` — Reject the current failure

## Configuration

```lua
require("approval").setup({
  pytest_cmd = "pytest",              -- pytest executable
  pytest_args = { "-v", "--tb=short" }, -- default pytest arguments
  keymaps = {
    run_nearest = "<leader>tn",
    run_file = "<leader>tf",
    next_failure = "]a",
    prev_failure = "[a",
  },
})
```

## How It Works

1. Open a Python test file that uses `approvaltests.verify()`
2. Press `<leader>tn` to run the nearest test
3. If no `.approved.txt` exists, the diff popup shows an empty left pane vs the received output
4. Press `a` to approve — the `.received.txt` is renamed to `.approved.txt`
5. Run the test again — it passes with a success notification
6. If the output changes, the popup shows the diff between the old approved and new received content
7. Press `q` to reject and keep the `.approved.txt` unchanged

## Requirements

- Neovim >= 0.9
- Python with [approvaltests](https://pypi.org/project/approvaltests/) installed
- pytest
