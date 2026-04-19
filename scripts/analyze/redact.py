"""
redact.py — shared credential redaction patterns for agent-flow observability.

Used by both the offline transcript loader (analyze.py) and the live hook
sink (hooks/scripts/log-event.py).
"""
from __future__ import annotations

import re
from typing import Optional

REDACT_PATTERNS = [
    r"AKIA[0-9A-Z]{16}",                              # AWS access key
    r"sk-ant-[A-Za-z0-9\-_]{20,}",                    # Anthropic
    r"sk-[A-Za-z0-9]{20,}",                           # OpenAI-style
    r"ghp_[A-Za-z0-9]{36}",                           # GitHub PAT
    r"github_pat_[A-Za-z0-9_]{40,}",                  # GitHub fine-grained PAT
    r"xoxb-[A-Za-z0-9\-]{10,}",                       # Slack bot
    r"xoxp-[A-Za-z0-9\-]{10,}",                       # Slack user
    r"-----BEGIN (RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----",  # PEM
]
REDACT_RE = re.compile("|".join(REDACT_PATTERNS))


def redact(s: Optional[str]) -> Optional[str]:
    if s is None:
        return None
    return REDACT_RE.sub("[REDACTED]", s)
