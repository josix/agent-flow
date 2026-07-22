# Using AgentsView Session-History Search

A practical guide to the built-in AgentsView integration — letting read-only subagents search prior session history to leverage proven approaches and cross-verify current handling against precedent.

## What This Integration Is

Agent Flow ships a built-in MCP integration for the `agentsview` CLI that lets Riko, Senku, and Lawliet search your prior Claude Code (and other supported agent) session history.

- **Riko** searches prior related sessions during exploration to surface how similar work was handled before.
- **Senku** leverages proven past approaches when designing an implementation plan.
- **Lawliet** cross-verifies current handling against precedent found in earlier sessions.
- **Loid and Alphonse are intentionally excluded** — they are write/verify-only agents; session-history recall is out of scope for their responsibilities.

Unlike `personal-kb`, this integration is a plugin-shipped `.mcp.json` entry — there is no manual MCP server registration step. It only requires the `agentsview` CLI to be installed.

## Prerequisites

- Install the `agentsview` CLI, v0.38 or later.
- The MCP server (`agentsview mcp`) reads through the local agentsview daemon, starting it automatically when needed — no separate daemon-start step is required.

If `agentsview` is not installed, the integration degrades gracefully (see [Graceful Degradation](#graceful-degradation) below) — no error, no broken startup.

## How It Works

1. `.mcp.json` registers an `agentsview` server entry pointing at `scripts/start-agentsview-mcp.sh`.
2. `start-agentsview-mcp.sh` is a guard wrapper: it exits 0 (no server) if `AGENT_FLOW_NO_AGENTSVIEW=1` is set or the `agentsview` binary is missing; otherwise it `exec`s `agentsview mcp`.
3. `scripts/detect-agentsview-context.sh` runs during orchestration init and emits an `agentsview:` state block:
   ```yaml
   agentsview:
     available: true
     binary: "/path/to/agentsview"
     archive_reachable: true
   ```
4. When `agentsview: available: true` is present in the state file, the orchestrator injects a one-line preamble into every `Task(...)` call for Riko, Senku, and Lawliet, telling them prior session history is searchable. See the `agentsview-usage` skill for query patterns.

## The Five Tools

All granted tools are accessed via the prefix `mcp__plugin_agent-flow_agentsview__*`:

| Tool | Purpose |
|---|---|
| `search_sessions` | Find past sessions matching filters (project, agent, date, outcome) |
| `list_sessions` | Browse recent sessions without a specific search term |
| `get_session_overview` | Get metadata/signals for one known session |
| `get_messages` | Read an exact (paginated) window of messages from a session |
| `search_content` | Full-text/semantic search across message and tool content spanning all sessions |

**Note**: `get_usage_summary` (token usage/cost accounting) is intentionally **not** granted to any persona — it is out of scope for session-history recall.

See `skills/agentsview-usage/SKILL.md` (in the repository) for the full query guide, tool decision table, and token hygiene rules.

## Opt-Out

Set `AGENT_FLOW_NO_AGENTSVIEW=1` before starting Claude Code (or for a specific run) to disable the integration entirely:

```bash
AGENT_FLOW_NO_AGENTSVIEW=1 claude
```

This disables **both**:
- The detector (`detect-agentsview-context.sh` emits `available: false` with `reason: opt-out via AGENT_FLOW_NO_AGENTSVIEW`).
- The MCP server (`start-agentsview-mcp.sh` exits 0 without starting `agentsview mcp`).

## Graceful Degradation

Every part of this integration is designed to degrade silently when `agentsview` is unavailable:

- `detect-agentsview-context.sh` always exits 0, emitting `agentsview: available: false` when the binary is missing, opted out, or the local archive is unreachable.
- `start-agentsview-mcp.sh` always exits 0 when the binary is missing or opted out — it never breaks Claude Code startup.
- When `available: false`, the orchestrator simply skips injecting the AgentsView preamble; Riko/Senku/Lawliet proceed without session-history search, with no errors surfaced to the user.

## Related Documentation

- [Installation](../getting-started/installation.md) — plugin setup
- `skills/agentsview-usage/SKILL.md` (in repository) — agent query guide
- [Using Your Personal Knowledge Base](using-personal-kb.md) — sibling integration for cross-project personal notes/decisions
