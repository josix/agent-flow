"""Run agent-flow orchestrations through the Claude Agent SDK.

This is the only module that touches the SDK; everything it decides with
(gate policy, outcome derivation, session records) lives in pure modules so
it can be tested without a Claude installation.

Flow for ``start``:

1. Create a session record for the workspace.
2. Open a streaming SDK session with the agent-flow plugin loaded
   (``--plugin-dir``) and cwd set to the workspace, so the plugin's own
   hooks (validation, completion verification, logging) apply unchanged.
3. Send ``/agent-flow:orchestrate <task>``.
4. Intercept ``AskUserQuestion`` via the ``can_use_tool`` callback per the
   gate policy; under ``escalate`` the run is interrupted and the question
   is returned as ``needs_input``.
5. After the stream ends, derive the outcome from the orchestration state
   file — never from the model's prose alone.

``resume`` reopens the same SDK conversation (``resume=<sdk session id>``)
and delivers the caller's answer as the next user message; agent-flow's
file-based state carries the orchestration forward from its current phase.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from agentflow_headless import gates, sessions
from agentflow_headless.result import DelegatedAgentResult, ResultStatus
from agentflow_headless.state import OrchestrationState, derive_outcome

DEFAULT_PERMISSION_MODE = "acceptEdits"
DEFAULT_COMMAND = "agent-flow:orchestrate"
# The orchestration spawns subagents that run tests and linters; a generous
# ceiling that still stops a runaway loop.
DEFAULT_MAX_TURNS = 300


@dataclass
class RunConfig:
    workspace: Path
    plugin_dir: Path
    policy: str = gates.POLICY_ESCALATE
    permission_mode: str = DEFAULT_PERMISSION_MODE
    command: str = DEFAULT_COMMAND
    max_turns: int = DEFAULT_MAX_TURNS
    timeout_seconds: float | None = None
    model: str | None = None


class _SdkRun:
    """One streaming SDK conversation, with gate interception."""

    def __init__(self, config: RunConfig, *, resume_sdk_session_id: str | None = None) -> None:
        self._config = config
        self._resume_sdk_session_id = resume_sdk_session_id
        self.pending_question: str | None = None
        self.pending_question_payload: dict[str, Any] | None = None
        self.sdk_session_id: str | None = None
        self.final_text: str = ""
        self.last_assistant_text: str = ""
        self.usage: dict[str, int] | None = None
        self.total_cost_usd: float | None = None
        self.is_error: bool = False
        self.num_turns: int = 0
        self._client: Any = None

    async def run(self, prompt: str) -> None:
        sdk = _import_sdk()

        async def can_use_tool(tool_name: str, tool_input: dict[str, Any], context: Any) -> Any:
            decision = gates.evaluate_tool_use(tool_name, tool_input, self._config.policy)
            if decision.kind == "allow":
                return sdk.PermissionResultAllow()
            if decision.kind == "escalate":
                self.pending_question = decision.question
                self.pending_question_payload = decision.question_payload
                if self._client is not None:
                    # Stop the run once the question is captured; the answer
                    # arrives via resume as the next user message.
                    asyncio.get_running_loop().create_task(self._client.interrupt())
            return sdk.PermissionResultDeny(message=decision.deny_message)

        options = sdk.ClaudeAgentOptions(
            cwd=str(self._config.workspace),
            permission_mode=self._config.permission_mode,
            can_use_tool=can_use_tool,
            max_turns=self._config.max_turns,
            model=self._config.model,
            resume=self._resume_sdk_session_id,
            # --plugin-dir is the stable CLI flag for loading a local plugin
            # (the same one the README documents for development), so this
            # does not depend on any particular SDK version's plugin API.
            extra_args={"plugin-dir": str(self._config.plugin_dir)},
        )

        async with sdk.ClaudeSDKClient(options=options) as client:
            self._client = client
            await client.query(prompt)
            async for message in client.receive_response():
                self._absorb(sdk, message)

    def _absorb(self, sdk: Any, message: Any) -> None:
        if isinstance(message, sdk.AssistantMessage):
            texts = [b.text for b in message.content if isinstance(b, sdk.TextBlock)]
            if texts:
                self.last_assistant_text = "\n".join(texts)
        elif isinstance(message, sdk.ResultMessage):
            self.sdk_session_id = message.session_id
            self.final_text = message.result or self.last_assistant_text
            self.is_error = bool(message.is_error)
            self.num_turns = message.num_turns
            self.total_cost_usd = message.total_cost_usd
            if isinstance(message.usage, dict):
                self.usage = {
                    k: v
                    for k, v in message.usage.items()
                    if isinstance(v, int) and k in ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")
                }


def _import_sdk() -> Any:
    try:
        import claude_agent_sdk
    except ImportError as exc:  # pragma: no cover - environment-dependent
        raise RuntimeError(
            "claude-agent-sdk is not installed. Install the headless driver's "
            "dependencies first: pip install agentflow-headless (or pip install "
            "claude-agent-sdk). A Claude Code CLI installation and credentials "
            "(ANTHROPIC_API_KEY or `claude login`) are also required."
        ) from exc
    return claude_agent_sdk


def _execute(config: RunConfig, record: sessions.SessionRecord, prompt: str, *, resume_sdk_id: str | None) -> DelegatedAgentResult:
    run = _SdkRun(config, resume_sdk_session_id=resume_sdk_id)
    run_error: str | None = None

    async def _go() -> None:
        if config.timeout_seconds:
            await asyncio.wait_for(run.run(prompt), timeout=config.timeout_seconds)
        else:
            await run.run(prompt)

    try:
        asyncio.run(_go())
    except asyncio.TimeoutError:
        run_error = f"time budget of {config.timeout_seconds}s exceeded; the session can be resumed"
    except RuntimeError:
        raise
    except Exception as exc:  # bounded: transport/SDK failures become a failed result
        run_error = f"{type(exc).__name__}: {exc}"

    if run.sdk_session_id:
        record.sdk_session_id = run.sdk_session_id

    state = OrchestrationState.load(config.workspace)
    outcome = derive_outcome(
        state,
        final_text=run.final_text,
        pending_question=run.pending_question is not None,
        run_error=run_error,
    )

    record.status = outcome.status
    record.pending_question = run.pending_question
    record.pending_question_payload = run.pending_question_payload
    sessions.save(record)

    summary = run.final_text or run.last_assistant_text or outcome.reason
    output: dict[str, Any] = dict(outcome.detail)
    output["resumable"] = outcome.resumable
    if run.total_cost_usd is not None:
        output["total_cost_usd"] = run.total_cost_usd

    return DelegatedAgentResult(
        status=outcome.status,
        summary=summary,
        session_id=record.session_id,
        output=output,
        question=run.pending_question,
        error=outcome.reason if outcome.status == ResultStatus.FAILED else None,
        usage=run.usage,
        metadata={"workspace": record.workspace, "num_turns": run.num_turns},
    )


def start(
    task: str,
    *,
    workspace: Path,
    plugin_dir: Path,
    policy: str = gates.POLICY_ESCALATE,
    permission_mode: str = DEFAULT_PERMISSION_MODE,
    max_turns: int = DEFAULT_MAX_TURNS,
    timeout_seconds: float | None = None,
    model: str | None = None,
) -> DelegatedAgentResult:
    if policy not in gates.POLICIES:
        raise ValueError(f"unknown policy {policy!r}; expected one of {gates.POLICIES}")
    workspace = Path(workspace).resolve()
    plugin_dir = Path(plugin_dir).resolve()
    if not workspace.is_dir():
        raise ValueError(f"workspace does not exist: {workspace}")
    if not (plugin_dir / ".claude-plugin" / "plugin.json").is_file():
        raise ValueError(f"not an agent-flow plugin directory (no .claude-plugin/plugin.json): {plugin_dir}")

    config = RunConfig(
        workspace=workspace,
        plugin_dir=plugin_dir,
        policy=policy,
        permission_mode=permission_mode,
        max_turns=max_turns,
        timeout_seconds=timeout_seconds,
        model=model,
    )
    record = sessions.SessionRecord.create(
        workspace=workspace,
        plugin_dir=plugin_dir,
        task=task,
        policy=policy,
        permission_mode=permission_mode,
    )
    sessions.save(record)
    prompt = f"/{config.command} {task}"
    return _execute(config, record, prompt, resume_sdk_id=None)


def resume(
    session_id: str,
    response: str,
    *,
    workspace: Path,
    max_turns: int = DEFAULT_MAX_TURNS,
    timeout_seconds: float | None = None,
    model: str | None = None,
) -> DelegatedAgentResult:
    workspace = Path(workspace).resolve()
    record = sessions.load(workspace, session_id)

    config = RunConfig(
        workspace=Path(record.workspace),
        plugin_dir=Path(record.plugin_dir),
        policy=record.policy,
        permission_mode=record.permission_mode,
        max_turns=max_turns,
        timeout_seconds=timeout_seconds,
        model=model,
    )

    if record.pending_question:
        prompt = (
            f"Answer to your escalated question: {response}\n\n"
            "Continue the orchestration from its current phase; consult "
            ".claude/orchestration.local.md for the current state. Do not restart "
            "completed phases."
        )
    else:
        prompt = (
            f"{response}\n\n"
            "Continue the orchestration from its current phase; consult "
            ".claude/orchestration.local.md for the current state. Do not restart "
            "completed phases."
        )
    record.pending_question = None
    record.pending_question_payload = None
    return _execute(config, record, prompt, resume_sdk_id=record.sdk_session_id)


def status(session_id: str, *, workspace: Path) -> DelegatedAgentResult:
    """Report a session's current state from disk without running anything."""
    workspace = Path(workspace).resolve()
    record = sessions.load(workspace, session_id)
    state = OrchestrationState.load(Path(record.workspace))
    outcome = derive_outcome(state, pending_question=record.pending_question is not None)
    output: dict[str, Any] = dict(outcome.detail)
    output["resumable"] = outcome.resumable
    return DelegatedAgentResult(
        status=outcome.status,
        summary=outcome.reason,
        session_id=record.session_id,
        output=output,
        question=record.pending_question,
        error=outcome.reason if outcome.status == ResultStatus.FAILED else None,
        metadata={"workspace": record.workspace, "recorded_status": record.status},
    )
