"""The normalized result contract returned by every headless invocation.

Mirrors the ``DelegatedAgentResult`` shape proposed for Airflow Common AI
delegated-agent capabilities, so the Airflow toolset can pass this through
with no translation layer.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from typing import Any


class ResultStatus:
    COMPLETED = "completed"
    FAILED = "failed"
    NEEDS_INPUT = "needs_input"
    NEEDS_APPROVAL = "needs_approval"

    ALL = (COMPLETED, FAILED, NEEDS_INPUT, NEEDS_APPROVAL)


# Everything in a result is re-read by an outer LLM on every subsequent
# model request, so the payload must stay small.
MAX_SUMMARY_CHARS = 2000


@dataclass
class DelegatedAgentResult:
    status: str
    summary: str
    session_id: str | None = None
    output: dict[str, Any] | None = None
    question: str | None = None
    approval_request: str | None = None
    error: str | None = None
    usage: dict[str, int] | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if self.status not in ResultStatus.ALL:
            raise ValueError(f"invalid status {self.status!r}; expected one of {ResultStatus.ALL}")
        if len(self.summary) > MAX_SUMMARY_CHARS:
            self.summary = self.summary[: MAX_SUMMARY_CHARS - 3] + "..."

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    def to_json(self, *, indent: int | None = None) -> str:
        return json.dumps(self.to_dict(), indent=indent, ensure_ascii=False, default=str)

    @property
    def exit_code(self) -> int:
        """CLI exit code for this outcome (documented in the CLI help)."""
        return {
            ResultStatus.COMPLETED: 0,
            ResultStatus.FAILED: 1,
            ResultStatus.NEEDS_INPUT: 10,
            ResultStatus.NEEDS_APPROVAL: 11,
        }[self.status]
