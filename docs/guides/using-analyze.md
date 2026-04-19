# Using Analyze

A practical guide to surfacing subagent behavior, tool usage, and improvement opportunities with the `/agent-flow:analyze` command.

## Overview

The analyze command parses Claude Code session transcripts — either offline from stored JSONL files or live via hook-captured events — and loads them into a local SQLite database. From there, you can generate reports, run ad-hoc SQL queries, label subagent outputs for recall evaluation, and export data to external tools. All data stays on your machine; no network calls are made.

The command exists because raw transcripts are hard to query. A structured store lets you ask "which tools does Loid actually use?" or "how often does the orchestrator block a subagent?" across many sessions at once.

## Quick Start

```bash
# Slash command — load the current session and open an interactive report
/agent-flow:analyze

# CLI: load all past sessions, then generate a report
bash scripts/analyze.sh load --all-sessions && bash scripts/analyze.sh report

# CLI: report for a single session
bash scripts/analyze.sh report --session <session_id>
```

The report is written to `.claude/observability/report.md` and also printed to stdout.

## What You Will Learn from a Report

A report surfaces:

- **Tool usage by agent** — which tools each subagent actually calls, and how often
- **MCP / skill invocations** — frequency of `mcp__*` and `Skill` tool calls per agent
- **Iteration rate** — how many times each subagent type is dispatched per session on average
- **Rejection rate** — how often a subagent's output is blocked or denied by a hook
- **Thinking effort** — total and average thinking-block characters per agent
- **Token use** — input, output, cache-read, and cache-creation tokens per agent and model
- **Improvement opportunities** — heuristic findings with explanations, for example:
  - High iteration rate on a specific agent (possible planning or scope issue)
  - Tool calls that fall outside the expected allowlist for an agent
  - Missing MCP usage in agents expected to use the knowledge graph
  - Model mismatches (Opus used where Sonnet was intended, or vice versa)

## Subcommands

### `load`

Parses transcript files and writes events into the SQLite store.

```bash
# Load every session found in the Claude Code data directory
bash scripts/analyze.sh load --all-sessions

# Load a single session by ID
bash scripts/analyze.sh load --session <session_id>

# Print summary statistics after loading without generating a full report
bash scripts/analyze.sh load --all-sessions --stats

# Redact sensitive values before writing (enabled by default for live-hook events)
bash scripts/analyze.sh load --all-sessions --redact
```

The loader is idempotent — re-running it updates existing rows rather than duplicating them.

### `report`

Generates a Markdown report from whatever is already in the database.

```bash
# Report across all loaded sessions
bash scripts/analyze.sh report

# Report for one session only
bash scripts/analyze.sh report --session <session_id>
```

The report respects the `NO_COLOR` environment variable: set it to any non-empty value to suppress ANSI colour codes in terminal output.

Output is written to `.claude/observability/report.md` (all sessions) or `.claude/observability/<session_id>.md` (single session).

### `sessions`

Lists all sessions currently in the database with their start/end timestamps, branch, and event count.

```bash
bash scripts/analyze.sh sessions
```

Use this to find session IDs before running `report --session` or `label`.

### `sql`

Runs an arbitrary SQL query against the database and prints results as a table.

```bash
bash scripts/analyze.sh sql "SELECT agent_type, tool_name, COUNT(*) n FROM events GROUP BY agent_type, tool_name ORDER BY n DESC LIMIT 20"
```

!!! note
    By convention `sql` is read-only — there is no enforcement preventing writes, but mutating the store manually can corrupt report data.

Pre-built views are available (see [Observability Schema](../reference/observability-schema.md#views)) so you rarely need to write raw joins.

### `retention`

Prunes old events and sessions from the database.

```bash
# Delete sessions older than 30 days
bash scripts/analyze.sh retention --days 30

# Delete all sessions from the database
bash scripts/analyze.sh retention --all
```

!!! warning
    `retention --all` is irreversible. Export data first if you need it.

### `label`

Interactive stdin labeling for evaluating subagent recall quality (M5 milestone). You step through subagent outputs one at a time and assign a verdict.

```bash
bash scripts/analyze.sh label <session_id>
```

Keys during the interactive session:

| Key | Verdict |
|-----|---------|
| `c` | correct |
| `m` | missed |
| `e` | extra |
| `w` | wrong |
| `s` | skip |
| `q` | quit and save progress |

The session is resumable — quitting and re-running picks up where you left off.

#### `label export`

Exports labels to CSV for offline analysis.

```bash
# Export labels for one session
bash scripts/analyze.sh label export <session_id>

# Export all labels
bash scripts/analyze.sh label export --all
```

The CSV includes `label_id`, `session_id`, `agent_type`, `verdict`, `note`, and `ts` columns. Two derived metrics are computed per agent type:

- **precision** = `correct / (correct + extra + wrong)`
- **recall_proxy** = `correct / (correct + missed)`

### `export`

Exports events to an external sink. Behaviour is driven by `.claude/observability.json`.

```bash
bash scripts/analyze.sh export
```

Supported exporters:

- **jsonl** (default, no extra dependencies) — writes to `.claude/observability/export.jsonl`
- **mlflow** (opt-in) — requires `mlflow` installed; guarded with an `ImportError` so absence of the package does not break the default path

Configure exporters in `.claude/observability.json`:

```json
{
  "exporters": [
    { "type": "jsonl" },
    { "type": "mlflow", "tracking_uri": "http://localhost:5000", "experiment": "agent-flow" }
  ]
}
```

## Privacy

The loader applies redaction before writing to the database. Patterns covered:

- AWS access key IDs and secret keys
- Anthropic API keys (`sk-ant-` prefix)
- OpenAI API keys (`sk-` prefix)
- GitHub personal access tokens (classic `ghp_` and fine-grained `github_pat_`)
- Slack bot/user tokens (`xoxb-`, `xoxp-`)
- PEM private key blocks

Redacted values are replaced with a placeholder. To add your own patterns, edit `scripts/analyze/redact.py` — each pattern is a compiled regex with a named group `secret`.

## Data Locations

| Path | Description |
|------|-------------|
| `.claude/observability/events.db` | Primary SQLite WAL store (append-only by convention) |
| `.claude/observability/events.jsonl` | Fallback sink when the DB is locked (~30 ms p95 hook latency) |
| `.claude/observability/report.md` | Latest all-sessions report |
| `.claude/observability/<session_id>.md` | Per-session report |
| `.claude/observability/export.jsonl` | JSONL exporter output |
| `.claude/observability/labels-export.csv` | CSV from `label export` |
| `.claude/observability.json` | Exporter configuration |

All paths under `.claude/observability/` are gitignored.

## Turning Off Live Hooks

The live hook sink captures events automatically during every session. To stop collection:

- **Disable hooks**: Comment out the four observability entries in `hooks/hooks.json` (`PreToolUse:Agent|Task`, the matcherless `PostToolUse`, `SubagentStop`, `SessionEnd`).
- **Remove the database**: Delete `.claude/observability/events.db`; the hooks will recreate it on the next session unless disabled.

The offline transcript parser (`load` subcommand) works independently of live hooks — you can still load historical JSONL transcripts with hooks disabled.

## Related Documentation

- [Observability Schema](../reference/observability-schema.md) — full table DDL, views, and example queries
- [Hooks Reference](../reference/hooks.md) — the four observability hook entries
- [State Files Reference](../reference/state-files.md) — all observability file locations
