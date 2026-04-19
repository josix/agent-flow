---
name: analyze
description: Analyze Claude Code transcripts to surface subagent behavior and improvement opportunities
argument-hint: [--all-sessions | --session <id>] [--report | --sessions | --sql <query>]
---

# Analyze Command

Parse Claude Code session transcripts offline and surface subagent behavior metrics,
tool usage patterns, token costs, and improvement opportunities — all stored in a local
SQLite database with no network calls.

## Arguments

- `--all-sessions` (default for first run): Load all sessions from the auto-detected transcripts directory
- `--session <id>`: Restrict loading to one session UUID
- `--report`: Generate a full markdown report (default action after loading)
- `--sessions`: List loaded sessions with event counts
- `--sql <query>`: Run ad-hoc SQL against the events database
- `--transcripts-dir <path>`: Override the auto-detected transcripts directory
- `--db <path>`: Override the database path (default: `.claude/observability/events.db`)
- `--redact`: Mask credential patterns (AWS keys, OpenAI keys, GitHub PATs) before storing

## Workflow

**FIRST RUN** — Load transcripts and generate a report:

```bash
bash scripts/analyze.sh load --all-sessions
bash scripts/analyze.sh report
```

**Or as a two-step invocation:**

```bash
bash scripts/analyze.sh load --all-sessions && bash scripts/analyze.sh report
```

**Inspect sessions:**

```bash
bash scripts/analyze.sh sessions
```

**Ad-hoc SQL:**

```bash
bash scripts/analyze.sh sql "SELECT agent_type, COUNT(*) FROM events GROUP BY agent_type"
```

## What You'll See

### Report Sections

| Section | Description |
|---------|-------------|
| Session Overview | All loaded sessions with timestamps, branch, event count, subagent count |
| Tool Usage by Agent | Which tools each agent called and how often |
| Skill / MCP Invocations | MCP tool calls per agent (graphify, personal-kb, etc.) |
| Thinking Effort | Thinking block count and character totals by agent |
| Token Usage | Input/output/cache tokens by agent and model |
| Subagent Dispatches & Iteration Rate | How many times each subagent type was dispatched per session |
| Rejection Rate | Stop-hook block/approve/deny decisions per agent |
| Improvement Opportunities | Automated heuristics (see below) |

### Improvement Heuristics

The report automatically flags:

- **High iteration rate** — any subagent with >1.5 dispatches/session → check prompt clarity / verification gates
- **High block rate** — agent with >30% stop-hook blocks → review verification-hook strictness or agent output contract
- **Unused tools** — tools declared in agent `tools:` allowlist but never invoked → consider removing
- **Tool overreach** — tools invoked but not in declared allowlist → check agent definition
- **No MCP usage** — Riko/Senku/Lawliet with zero `mcp__*` calls → graphify/personal-kb not connected
- **Model mismatch** — declared model in agent frontmatter differs from actual events model

### Output Files

- `.claude/observability/events.db` — SQLite database (local, gitignored)
- `.claude/observability/report.md` — Latest report (local, gitignored)

## Database Schema

Events, sessions, subagents, and iteration logs are stored in SQLite.
Analytical views are available for ad-hoc queries:

```
v_tool_usage_by_agent    v_skill_invocations   v_thinking_by_agent
v_tokens_by_agent        v_subagent_dispatch   v_iteration_rate
v_rejection_rate         v_session_summary
```

Example queries:

```bash
# Top tools across all agents
bash scripts/analyze.sh sql "SELECT tool_name, COUNT(*) n FROM events WHERE tool_name IS NOT NULL GROUP BY tool_name ORDER BY n DESC LIMIT 20"

# Token spend by model
bash scripts/analyze.sh sql "SELECT model, SUM(input_tokens) input, SUM(output_tokens) output FROM events WHERE role='assistant' GROUP BY model"
```

## Live Hook Sink (M2)

Events are also captured live as Claude Code runs via hooks in `hooks/hooks.json`.
Every tool use, subagent dispatch, and session end is written to the same
`.claude/observability/events.db` by `hooks/scripts/log-event.sh`. Secrets in
tool inputs are redacted automatically using the shared patterns in `scripts/analyze/redact.py`.

## Retention

Delete old events to keep the database size manageable:

```bash
# Delete events older than 30 days
bash scripts/analyze.sh retention --days 30

# Wipe everything
bash scripts/analyze.sh retention --all
```

Both commands vacuum the database afterward. Safe to re-run.

## Task

Parse transcripts and surface insights for: $ARGUMENTS

Start with:

```bash
bash scripts/analyze.sh load --all-sessions
bash scripts/analyze.sh report
```
