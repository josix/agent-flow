# Query Patterns — AgentsView Decision Table

Maps recall-question types to tool sequences. For full tool signatures see [tool-reference.md](tool-reference.md).

Two standard flows:
- **Leverage flow** (Riko/Senku) — find and reuse a proven prior approach
- **Cross-verify flow** (Lawliet) — check current handling against precedent

---

## Primary Decision Table

| Question type | First tool | Follow-up | Notes |
|---|---|---|---|
| Has something like this been done before? | `search_sessions` (project=..., limit=10) | `get_session_overview` on the best match | Start broad, narrow with overview |
| What did I work on recently in this project? | `list_sessions` (project=..., limit=10) | `get_session_overview` on a candidate | Chronological browse, no search term |
| Full details on a known session | `get_session_overview` (id=...) | `get_messages` only if exact wording needed | Prefer overview over raw transcript |
| What exact commands/wording were used? | `get_messages` (id=..., around=..., limit=10) | — | Always paginate; never full-dump |
| Find every prior mention of a specific error/string | `search_content` (pattern=..., limit=10) | `get_messages` around the matched ordinal | Full-text across all sessions |
| Was a similar change reviewed/handled before? | `search_content` (pattern="<topic>", limit=10) | `get_session_overview` on matched session | Cross-verify flow (Lawliet) |

---

## Leverage Flow (Riko finds, Senku reuses)

Use when the goal is to find and apply a proven prior approach:

```
1. mcp__plugin_agent-flow_agentsview__search_sessions (project=<current project>, limit=10)
   → Learn: candidate prior sessions touching similar work

2. mcp__plugin_agent-flow_agentsview__get_session_overview (id=<best match>)
   → Learn: what that session did, outcome, health signals

3. (Optional) mcp__plugin_agent-flow_agentsview__get_messages (id=<session>, around=<key ordinal>, limit=10)
   → Read: exact prior approach/commands, only if overview is insufficient
```

Riko summarizes findings (session ID + one-line takeaway) and hands off to Senku, who incorporates the leveraged approach into the implementation plan while treating it as a prior, not a mandate.

---

## Cross-Verify Flow (Lawliet checks precedent)

Use when reviewing a change and checking whether it matches or diverges from how similar changes were handled before:

```
1. mcp__plugin_agent-flow_agentsview__search_content (pattern="<topic or symbol>", limit=10)
   → Learn: prior sessions that mentioned the same topic/symbol

2. mcp__plugin_agent-flow_agentsview__get_session_overview (id=<matched session>)
   → Learn: outcome and context of that prior handling

3. (Optional) mcp__plugin_agent-flow_agentsview__get_messages (id=<session>, around=<matched ordinal>, limit=10)
   → Read: exact precedent, only if the overview leaves the comparison ambiguous
```

If current handling conflicts with precedent, Lawliet flags the conflict explicitly rather than silently overriding either.

---

## Token Budget Guidelines

| Tool | Recommended settings |
|---|---|
| `search_sessions` | limit=10-20 for orientation |
| `list_sessions` | limit=10-20 |
| `get_session_overview` | No budget arg — single session, cheap |
| `get_messages` | Always set `limit`; use `around`/`before`/`after` windows, not full sequential dumps |
| `search_content` | limit=10-20, context=2-5 |
