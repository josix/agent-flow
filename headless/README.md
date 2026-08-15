# agentflow-headless

Run agent-flow orchestrations **non-interactively**, with a start/resume
lifecycle and machine-readable results — so external systems (an Airflow
`AgentOperator` toolset, CI, a script) can delegate work to agent-flow
without a human at the keyboard.

Interactively, agent-flow's orchestrator *is* your Claude Code session and
you type `/agent-flow:orchestrate`. This package replaces the human side of
that loop with a Claude Agent SDK session:

```text
caller (Airflow toolset / CI / script)
  → agentflow-headless start --task "..." --workspace ... --plugin-dir ...
      → Claude Agent SDK session (plugin loaded via --plugin-dir)
          → /agent-flow:orchestrate  (explore → plan → implement → review → verify)
      ← DelegatedAgentResult JSON on stdout
```

## Install

```bash
pip install ./headless          # from a repo checkout
```

Requires Python ≥ 3.10, the Claude Code CLI, and credentials
(`ANTHROPIC_API_KEY` or `claude login`).

## Usage

```bash
agentflow-headless start \
  --task "Implement JIRA-123: add rate limiting to the API client" \
  --workspace /workspaces/repo \
  --plugin-dir /opt/agent-flow \
  --timeout 3600

# → {"status": "needs_input", "session_id": "3f9c...", "question": "...", ...}

agentflow-headless resume \
  --session-id 3f9c... \
  --workspace /workspaces/repo \
  --response "Keep existing API-key authentication."

# → {"status": "completed", "summary": "...", "output": {"gates": {...}}, ...}
```

Every command prints one result JSON object to stdout. Exit codes:
`0` completed, `1` failed, `10` needs_input, `11` needs_approval,
`2` usage error.

## How the human gates behave headlessly

agent-flow asks a human (`AskUserQuestion`) at four rate-limited points.
Headless runs resolve them by policy (`--policy`):

- **`escalate`** (default) — the run pauses, the question is returned as a
  `needs_input` result, and the caller answers via `resume`.
- **`auto`** — the orchestrator is told to proceed with the gate's
  documented default option (the review-divergence gate already defines
  one) and record the choice in the orchestration log.

## Truth comes from state, not prose

Following the plugin's "Subagents LIE" principle, the run outcome is
derived from `.claude/orchestration.local.md` (gate statuses, `active`,
research short-circuit), never from the model's final message alone. The
plugin's own hooks — including the Stop-hook test verification — run
unchanged inside the headless session.

## Isolation

The orchestration edits files and runs commands in `--workspace`. Give each
concurrent session its own workspace (container, git worktree, or volume);
two sessions must never share a working tree.
