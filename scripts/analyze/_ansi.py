"""
Minimal ANSI color helpers.

Colors are emitted only when sys.stdout.isatty() is True AND
the NO_COLOR environment variable is not set (honoring https://no-color.org/).
"""
from __future__ import annotations

import os
import sys


def _use_color() -> bool:
    return sys.stdout.isatty() and not os.environ.get("NO_COLOR")


BOLD   = "\033[1m"
RED    = "\033[31m"
YELLOW = "\033[33m"
GREEN  = "\033[32m"
RESET  = "\033[0m"


def bold(text: str) -> str:
    return f"{BOLD}{text}{RESET}" if _use_color() else text


def red(text: str) -> str:
    return f"{RED}{text}{RESET}" if _use_color() else text


def yellow(text: str) -> str:
    return f"{YELLOW}{text}{RESET}" if _use_color() else text


def green(text: str) -> str:
    return f"{GREEN}{text}{RESET}" if _use_color() else text
