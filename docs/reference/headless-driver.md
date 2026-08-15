# Headless Driver

The headless driver (`headless/`, package `agentflow-headless`) runs
agent-flow orchestrations without a human in the loop. It exists so
external orchestrators — the reference use case is an Apache Airflow
`AgentOperator` delegating a software-engineering task — can invoke
agent-flow as a **delegated agent runtime** with a standardized
start/resume lifecycle and machine-readable results.

## What it does

Interactively, the orchestrator is your Claude Code session and the program
it executes is `commands/orchestrate.md`. The headless driver keeps all of
that unchanged and replaces only the human side:

1. **Session** — opens a streaming Claude Agent SDK session with the plugin
   loaded (`--plugin-dir`) and `cwd` set to the target workspace, then sends
   `/agent-flow:orchestrate <task>`. All plugin hooks (path guards,
   delegation nudges, observability logging, the Stop-hook test
   verification) apply exactly as in an interactive session.
2. **Gates** — intercepts `AskUserQuestion` through the SDK's
   `can_use_tool` callback. Under the default `escalate` policy the run is
   interrupted and the question is returned to the caller as a
   `needs_input` result; under `auto` the orchestrator is instructed to
   proceed with the gate's documented default (the pattern the
   review-divergence cap already defines) and log the choice.
3. **Resume** — `resume` reopens the same SDK conversation and delivers the
   caller's answer as the next user message. Orchestration continuity is
   double-anchored: the SDK resumes the conversation, and agent-flow's own
   state file (`.claude/orchestration.local.md`) carries the current phase,
   so completed phases are not re-run.
4. **Outcome** — after the stream ends, the result status is derived from
   the orchestration state file, not from the model's final prose
   (the [Subagents LIE principle](../concepts/subagents-lie.md)):
   `verification.status: passed` + `active: false` → `completed`; the
   research short-circuit (`report_requested` / research-tier tasks) →
   `completed`; an interrupted `active: true` run → `failed` but
   resumable; a captured question → `needs_input`. The
   `<orchestration-complete>` sentinel is recorded as corroborating
   evidence only.

## Result contract

Every invocation prints one JSON object shaped like the
`DelegatedAgentResult` proposed for Airflow Common AI delegated-agent
capabilities:

```json
{
  "status": "completed | failed | needs_input | needs_approval",
  "summary": "bounded human-readable summary",
  "session_id": "3f9c0a1b2c3d",
  "output": {"current_phase": "...", "gates": {"verification": "passed"}, "resumable": false},
  "question": null,
  "approval_request": null,
  "error": null,
  "usage": {"input_tokens": 0, "output_tokens": 0},
  "metadata": {"workspace": "...", "num_turns": 42}
}
```

`needs_approval` is reserved for contract parity with the Airflow proposal;
agent-flow's gates are questions, so the driver currently emits
`needs_input` for all escalations.

## Session records

Each headless session is a JSON record under
`<workspace>/.claude/headless-sessions/<session_id>.json` binding the
caller-facing session ID, the workspace, the plugin path, the gate policy,
the SDK session ID (for resume), and any pending escalated question. The
records live next to the orchestration state file so wiping a workspace
wipes both.

## CLI

```bash
agentflow-headless start  --task "..." --workspace DIR --plugin-dir DIR \
                          [--policy escalate|auto] [--permission-mode MODE] \
                          [--max-turns N] [--timeout SECONDS] [--model MODEL]
agentflow-headless resume --session-id ID --workspace DIR --response "..." \
                          [--max-turns N] [--timeout SECONDS]
agentflow-headless status --session-id ID --workspace DIR
```

Exit codes: `0` completed, `1` failed, `10` needs_input,
`11` needs_approval, `2` usage error.

## Isolation and safety

- The orchestration mutates files and runs commands in the workspace. Give
  every concurrent session an isolated workspace (ephemeral container,
  per-task git worktree, or dedicated volume).
- The default permission mode is `acceptEdits`; the driver's tool callback
  then allows the orchestration's tools within the session. The plugin's
  own `validate-changes.sh` guard still blocks path traversal and
  credential-file writes. Harden further at the container boundary, not by
  weakening the plugin.
- A `--timeout` expiry stops the run with a `failed`-but-resumable result;
  the session can be picked up with `resume`.

## Testing

The decision logic (gate policy, state parsing, outcome derivation, session
records) is pure Python with no SDK dependency:

```bash
cd headless
python -m pytest tests/
```
