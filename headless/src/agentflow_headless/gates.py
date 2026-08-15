"""Unattended policy for agent-flow's human-interaction gates.

agent-flow calls ``AskUserQuestion`` at four deliberately rate-limited
points (prompt-refinement clarification, assumption escalation after
planning/implementation, post-plan confirmation for complex tasks, and the
Codex review-divergence cap). Headless runs have no human to answer, so
every ``AskUserQuestion`` is intercepted and resolved by policy:

- ``escalate`` (default): capture the question, interrupt the run, and
  surface it to the caller as a ``needs_input`` result. The caller answers
  via ``resume``.
- ``auto``: deny the tool with an instruction to proceed with the gate's
  documented default (the pattern the Codex divergence cap already defines:
  its unanswered default favors Lawliet).

The decision logic is pure so it can be tested without the Claude Agent SDK.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

ASK_USER_QUESTION = "AskUserQuestion"

POLICY_ESCALATE = "escalate"
POLICY_AUTO = "auto"
POLICIES = (POLICY_ESCALATE, POLICY_AUTO)

AUTO_DENY_MESSAGE = (
    "This is an unattended headless run; no human is available to answer. "
    "Do not call AskUserQuestion again. Proceed with this gate's documented "
    "default option (for the review-divergence gate that is option B, favor "
    "Lawliet), or with the most conservative assumption, and record the "
    "choice and its rationale in the orchestration state log."
)


@dataclass
class GateDecision:
    """What the can_use_tool callback should do for one tool call."""

    kind: str  # "allow" | "deny" | "escalate"
    deny_message: str = ""
    question: str = ""
    question_payload: dict[str, Any] = field(default_factory=dict)


def format_question(tool_input: dict[str, Any]) -> str:
    """Render AskUserQuestion input as one plain-text question for the caller."""
    questions = tool_input.get("questions") or []
    parts: list[str] = []
    for entry in questions:
        if not isinstance(entry, dict):
            continue
        text = str(entry.get("question", "")).strip()
        if not text:
            continue
        options = entry.get("options") or []
        rendered_options = []
        for opt in options:
            if isinstance(opt, dict) and opt.get("label"):
                label = str(opt["label"])
                description = str(opt.get("description", "")).strip()
                rendered_options.append(f"- {label}: {description}" if description else f"- {label}")
        if rendered_options:
            parts.append(text + "\nOptions:\n" + "\n".join(rendered_options))
        else:
            parts.append(text)
    return "\n\n".join(parts) if parts else "The orchestration asked for input (unstructured question)."


def evaluate_tool_use(tool_name: str, tool_input: dict[str, Any], policy: str) -> GateDecision:
    if tool_name != ASK_USER_QUESTION:
        return GateDecision(kind="allow")
    if policy == POLICY_AUTO:
        return GateDecision(kind="deny", deny_message=AUTO_DENY_MESSAGE)
    if policy == POLICY_ESCALATE:
        return GateDecision(
            kind="escalate",
            deny_message=(
                "This question has been escalated to the external caller. "
                "The run will pause now; when it resumes, the caller's answer "
                "will arrive as the next user message. Do not ask again."
            ),
            question=format_question(tool_input),
            question_payload=tool_input,
        )
    raise ValueError(f"unknown gate policy {policy!r}; expected one of {POLICIES}")
