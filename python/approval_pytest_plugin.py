from approvaltests import set_default_reporter
from approvaltests.reporters.report_quietly import ReportQuietly


def pytest_configure(config):
    set_default_reporter(ReportQuietly())
