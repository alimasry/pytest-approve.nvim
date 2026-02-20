import pytest
from approvaltests import set_default_reporter
from approvaltests.reporters.report_quietly import ReportQuietly


@pytest.fixture(scope="session", autouse=True)
def disable_approval_diff_tools():
    """Prevent approvaltests from launching external diff tools (e.g. VS Code)."""
    set_default_reporter(ReportQuietly())
