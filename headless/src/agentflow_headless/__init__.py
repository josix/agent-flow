"""Headless driver for the agent-flow Claude Code plugin.

Runs an agent-flow orchestration in a non-interactive Claude Agent SDK
session and exposes a start/resume lifecycle with machine-readable results,
so external systems (e.g. an Airflow ``DelegatedAgentToolset``) can delegate
work to agent-flow without a human at the keyboard.
"""

from agentflow_headless.result import DelegatedAgentResult, ResultStatus

__all__ = ["DelegatedAgentResult", "ResultStatus"]

__version__ = "0.1.0"
