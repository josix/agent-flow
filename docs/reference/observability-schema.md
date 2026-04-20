# Observability Schema Reference

Complete reference for the Agent Flow observability database: table definitions, column descriptions, pre-built views, and example queries.

## Overview

The observability store is a SQLite database at `.claude/observability/events.db`. It is opened in WAL mode so that reads and writes can happen concurrently without blocking live-hook writes during a session.

The schema has five tables: `events`, `sessions`, `subagents`, `iterations`, and `labels`.

## Table DDL

### `sessions`

One row per Claude Code session.

```sql
CREATE TABLE IF NOT EXISTS sessions (
  session_id          TEXT PRIMARY KEY,
  started_at          TEXT,
  ended_at            TEXT,
  git_branch          TEXT,
  cwd                 TEXT,
  parent_jsonl_path   TEXT,
  event_count         INTEGER DEFAULT 0
);
```

| Column | Description |
|--------|-------------|
| `session_id` | Unique session identifier from Claude Code |
| `started_at` | ISO 8601 timestamp of session start |
| `ended_at` | ISO 8601 timestamp of session end (null if still running) |
| `git_branch` | Git branch active at session start |
| `cwd` | Working directory at session start |
| `parent_jsonl_path` | Path to the source JSONL transcript file |
| `event_count` | Cached count of events; updated on load |

### `subagents`

One row per subagent spawned within a session.

```sql
CREATE TABLE IF NOT EXISTS subagents (
  agent_id           TEXT PRIMARY KEY,
  session_id         TEXT NOT NULL,
  agent_type         TEXT,
  description        TEXT,
  parent_tool_use_id TEXT,
  spawned_at         TEXT,
  stopped_at         TEXT,
  input_prompt       TEXT,
  accepted_output    TEXT,
  model              TEXT
);
```

| Column | Description |
|--------|-------------|
| `agent_id` | Unique subagent identifier |
| `session_id` | Parent session |
| `agent_type` | Agent role label, e.g. `agent-flow:Loid` |
| `description` | Short description extracted from the Task/Agent tool call |
| `parent_tool_use_id` | Tool-use ID of the spawning call (links to `events.tool_use_id`) |
| `spawned_at` | Timestamp of the spawning event |
| `stopped_at` | Timestamp of the SubagentStop event |
| `input_prompt` | Full prompt sent to the subagent (redacted) |
| `accepted_output` | Final accepted output (redacted) |
| `model` | Model used by the subagent |

### `events`

One row per message or tool event in the transcript.

```sql
CREATE TABLE IF NOT EXISTS events (
  event_id              TEXT PRIMARY KEY,
  session_id            TEXT NOT NULL,
  parent_uuid           TEXT,
  agent_id              TEXT,
  agent_type            TEXT,
  role                  TEXT,
  tool_use_id           TEXT,
  tool_name             TEXT,
  tool_input_json       TEXT,
  tool_result_json      TEXT,
  decision              TEXT,
  thinking_text         TEXT,
  input_tokens          INTEGER,
  output_tokens         INTEGER,
  cache_read_tokens     INTEGER,
  cache_creation_tokens INTEGER,
  model                 TEXT,
  git_branch            TEXT,
  cwd                   TEXT,
  is_sidechain          INTEGER,
  ts                    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_session   ON events(session_id, ts);
CREATE INDEX IF NOT EXISTS idx_events_agent     ON events(agent_type, ts);
CREATE INDEX IF NOT EXISTS idx_events_tool      ON events(tool_name);
CREATE INDEX IF NOT EXISTS idx_events_sidechain ON events(is_sidechain);
```

| Column | Description |
|--------|-------------|
| `event_id` | Message UUID from the transcript, or a synthetic ID for hook events |
| `parent_uuid` | UUID of the parent message (for threaded events) |
| `agent_id` | Subagent that produced this event (null for orchestrator events) |
| `agent_type` | Denormalized copy of `subagents.agent_type` for fast GROUP BY |
| `role` | `user`, `assistant`, or `system` |
| `tool_use_id` | Correlates tool call with its result |
| `tool_name` | Name of the tool called (null for non-tool messages) |
| `tool_input_json` | JSON-encoded tool input (redacted) |
| `tool_result_json` | JSON-encoded tool result (redacted) |
| `decision` | Hook decision on stop events: `approve`, `block`, `deny`, or null. As of v1.2.3, populated from `PreToolUse.hookSpecificOutput.permissionDecision` or the top-level `decision` field. An all-NULL column across a session with PreToolUse events is treated by `analyze.py` as a regression signal. |
| `thinking_text` | Concatenated extended-thinking blocks for this event |
| `input_tokens` | Input token count from the usage block |
| `output_tokens` | Output token count |
| `cache_read_tokens` | Tokens served from the prompt cache |
| `cache_creation_tokens` | Tokens written to the prompt cache |
| `is_sidechain` | `1` if this event belongs to a subagent, `0` for orchestrator |

### `iterations`

Mirrors the iteration log from `.claude/orchestration.local.md`.

```sql
CREATE TABLE IF NOT EXISTS iterations (
  session_id  TEXT,
  phase       TEXT,
  iteration_n INTEGER,
  agent       TEXT,
  gate_result TEXT,
  message     TEXT,
  ts          TEXT
);
```

| Column | Description |
|--------|-------------|
| `phase` | Orchestration phase (exploration, planning, implementation, review, verification) |
| `iteration_n` | Iteration number within the phase |
| `gate_result` | Gate outcome for this iteration |

**Format note:** The ingest parser handles both legacy single-line format (`### Phase: X | Iteration N` with `- Agent: X | Gate: Y | msg` body lines) and the new multi-line format emitted by `scripts/update-orchestration-state.sh` (frontmatter `iteration: N` with `### Phase: X` headings and `- Agent:` / `- Result:` / `- Message:` body lines).

### `labels`

Manual evaluation labels for subagent recall quality (M5).

```sql
CREATE TABLE IF NOT EXISTS labels (
  label_id   TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  event_id   TEXT,
  agent_id   TEXT,
  agent_type TEXT,
  verdict    TEXT NOT NULL,
  note       TEXT,
  ts         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_labels_session ON labels(session_id);
CREATE INDEX IF NOT EXISTS idx_labels_verdict ON labels(verdict);
```

| Column | Description |
|--------|-------------|
| `verdict` | One of `correct`, `missed`, `extra`, `wrong` |
| `note` | Free-text annotation from the labeler |
| `event_id` | Optional: pins the label to a specific event |
| `agent_id` | Subagent this label evaluates |

## Views

Pre-built views are created when the database is initialised. Use them via `bash scripts/analyze.sh sql "SELECT * FROM <view>"`.

| View | Purpose |
|------|---------|
| `v_tool_usage_by_agent` | Tool call counts grouped by agent type and tool name |
| `v_skill_invocations` | MCP and Skill tool calls grouped by agent type |
| `v_thinking_by_agent` | Thinking-block event count, total chars, and average chars per agent |
| `v_tokens_by_agent` | Aggregated token usage (input, output, cache) per agent and model |
| `v_subagent_dispatch` | Count of Agent/Task tool calls per session and subagent type |
| `v_iteration_rate` | Dispatches per session averaged across all sessions, per subagent type |
| `v_rejection_rate` | Block, approve, and deny counts per agent from stop-hook decisions |
| `v_session_summary` | One row per session with event count, subagent count, and dispatch count |

## Example Queries

### Which tools does each subagent actually use?

```sql
SELECT agent_type, tool_name, n
FROM v_tool_usage_by_agent
ORDER BY agent_type, n DESC;
```

### Rejection rate per agent

```sql
SELECT agent_type, blocks, approves, denies,
       ROUND(100.0 * blocks / NULLIF(decided, 0), 1) AS block_pct
FROM v_rejection_rate
ORDER BY block_pct DESC;
```

### Sessions that ended in a block decision

```sql
SELECT DISTINCT e.session_id, s.started_at, s.git_branch
FROM events e
JOIN sessions s USING (session_id)
WHERE e.decision = 'block'
  AND e.ts = (SELECT MAX(ts) FROM events WHERE session_id = e.session_id);
```

### Average thinking characters per agent

```sql
SELECT agent_type,
       thinking_events,
       total_chars,
       ROUND(avg_chars) AS avg_chars
FROM v_thinking_by_agent
ORDER BY total_chars DESC;
```

### Token cost breakdown for the last session

```sql
SELECT agent_type, model, input, output, cache_read, cache_creation
FROM v_tokens_by_agent
WHERE EXISTS (
  SELECT 1 FROM events e
  WHERE e.agent_type = v_tokens_by_agent.agent_type
    AND e.session_id = (SELECT session_id FROM sessions ORDER BY started_at DESC LIMIT 1)
)
ORDER BY output DESC;
```

## Related Documentation

- [Using Analyze](../guides/using-analyze.md) — how-to guide for all subcommands
- [State Files Reference](state-files.md) — file locations for all observability outputs
- [Hooks Reference](hooks.md) — the four live-hook entries that feed the database
