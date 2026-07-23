# Tool Reference — agentsview MCP Tools

All granted tools are accessed via the prefix `mcp__plugin_agent-flow_agentsview__*`. These tools query the local AgentsView session archive (synced from Claude Code, Codex, and other supported agents by the `agentsview` CLI), NOT the current project's graph. For the current project's graph, see the `graphify-usage` skill.

Parameters below are derived from the equivalent `agentsview session <subcommand> --help` CLI flags; the MCP tool schemas are read-only wrappers over the same underlying queries.

---

## search_sessions

**Full MCP name**: `mcp__plugin_agent-flow_agentsview__search_sessions`

**Purpose**: Find past sessions matching filters such as project, agent, date range, or outcome. The primary tool for "has something like this been done before?"

**Signature** (params, analogous to `agentsview session list`):
```
project        (string, optional)  — filter by project name
agent          (string, optional)  — filter by agent (claude, codex, cursor, ...)
since          (string, optional)  — relative duration (e.g. "14d") or YYYY-MM-DD
outcome        (string, optional)  — filter by outcome (success, failure, ...)
limit          (integer, optional) — max sessions to return; keep low (10-20) for orientation
```

**When to use**: Open-ended recall where you don't know a specific session ID yet — "find sessions related to X."

**Cost profile**: Medium. Always set `limit` explicitly; avoid the default (200) for orientation queries.

---

## list_sessions

**Full MCP name**: `mcp__plugin_agent-flow_agentsview__list_sessions`

**Purpose**: Browse recent sessions without a specific search term — chronological or filtered listing.

**Signature**:
```
project   (string, optional)  — filter by project name
limit     (integer, optional) — max sessions to return
```

**When to use**: "What did I work on recently in this project?" or scoping before a targeted search.

**Cost profile**: Low-to-medium depending on `limit`.

---

## get_session_overview

**Full MCP name**: `mcp__plugin_agent-flow_agentsview__get_session_overview`

**Purpose**: Get metadata and signals for one known session — task summary, message counts, outcome, health signals — without pulling the full transcript.

**Signature** (analogous to `agentsview session get`):
```
id   (string, required) — session ID (from search_sessions/list_sessions results)
```

**When to use**: You have a session ID from `search_sessions` and want a summary before deciding whether to pull exact messages.

**Cost profile**: Low. Single session lookup; prefer this over `get_messages` whenever a summary suffices.

---

## get_messages

**Full MCP name**: `mcp__plugin_agent-flow_agentsview__get_messages`

**Purpose**: Read an exact window of messages from a specific session — precise wording, commands, or exchanges.

**Signature** (analogous to `agentsview session messages`):
```
id          (string, required)  — session ID
around      (integer, optional) — center a window on this message ordinal
before      (integer, optional) — messages before `around` (default 5)
after       (integer, optional) — messages after `around` (default 5)
from        (integer, optional) — starting ordinal (inclusive) for sequential paging
limit       (integer, optional) — maximum messages to return; ALWAYS set this
role        (string, optional)  — comma-separated roles to include (e.g. "user,assistant")
```

**When to use**: Only when `get_session_overview`/`search_content` snippets are insufficient and exact prior wording or commands are needed. ALWAYS paginate — never fetch an entire transcript.

**Cost profile**: High if unpaginated. Always set `limit` and prefer a narrow `around`/`before`/`after` window over a full sequential dump.

---

## search_content

**Full MCP name**: `mcp__plugin_agent-flow_agentsview__search_content`

**Purpose**: Full-text (or hybrid semantic) search across message and tool content spanning all sessions — find prior mentions of a specific string, error, or pattern regardless of which session it occurred in.

**Signature** (analogous to `agentsview session search`):
```
pattern   (string, required)  — search text or regex
project   (string, optional)  — filter by project name
since     (string, optional)  — relative duration or YYYY-MM-DD
limit     (integer, optional) — max results; keep low (10-20) for orientation
context   (integer, optional) — messages of context to include around each match (max 10)
```

**When to use**: You know a specific term (error message, function name, config key) and want every prior session that mentioned it, not just a topical match.

**Cost profile**: Medium-to-high depending on `limit`/`context`. Follow up with `get_messages` on the specific matched ordinal, not a full transcript pull.

---

## get_usage_summary (NOT GRANTED)

The `agentsview mcp` server also exposes `get_usage_summary` (token usage and cost accounting), but it is intentionally **excluded** from the tool grants above. No persona in agent-flow has access to it — session-history search is scoped to recall and precedent-checking, not cost/usage reporting.
