---
name: agentsview-usage
description: Search prior session history to recall how similar work was handled before. Use when you want to leverage a past approach, check prior experience on a topic, answer "how was this handled before", or cross-verify current handling against precedent from earlier sessions.
---

# AgentsView Usage

Search prior session history effectively, interpret results accurately, and stay within token budgets.

## Overview

The agentsview MCP server exposes prior AI coding agent session history (synced by the `agentsview` CLI into a local SQLite archive) as read-only search tools, started via `agentsview mcp`.

All five granted tools are accessed via the MCP prefix `mcp__plugin_agent-flow_agentsview__*`.

**Owner**: Riko (Explorer Agent) — Riko is the primary session-history search agent and owns interpretation of results.
**Consumers**:
- Senku (Planner Agent) — leverages past approaches when designing an implementation strategy: "has a similar feature been built before, and how?"
- Lawliet (Reviewer Agent) — cross-verifies current handling against precedent: "does this change match or diverge from how similar changes were handled previously?"

**Out of scope**: Loid (Executor) and Alphonse (Verifier) do NOT have agentsview access by design. This preserves the write/verify separation and keeps write/verify agents focused on the current diff and verification commands, not historical recall.

---

## When to Query Session History vs. Graph vs. Grep

| Trigger condition | Preferred approach |
|---|---|
| "How was a similar task handled before?" | AgentsView: `search_sessions` |
| "What was decided/done in a specific prior session?" | AgentsView: `get_session_overview` |
| "What exact messages/commands were used before?" | AgentsView: `get_messages` (paginated) |
| "Find prior mentions of a specific string/error/pattern" | AgentsView: `search_content` |
| "What sessions ran recently on this project?" | AgentsView: `list_sessions` |
| "What is the dependency structure of THIS project?" | Project graph (`graphify-usage`) |
| "Find the string literal `TODO: fix`" in current files | Grep |
| "What does a specific config key say in THIS project?" | Read the file directly |
| AgentsView is not available (`agentsview: available: false` in state) | Skip — proceed without session-history search |

**Rule of thumb**: AgentsView is for **recall of how prior work was actually done across past sessions**. Project graph is for **structure within this session's codebase**. Grep/Read is for **current file content**.

---

## Tool Decision Table

Choose the right tool for the question type. See [references/query-patterns.md](references/query-patterns.md) for detailed decision sequences.

| Question type | Primary tool | Follow-up |
|---|---|---|
| Find past sessions on a topic | `search_sessions` | `get_session_overview` on the best match |
| Browse recent sessions (no specific topic) | `list_sessions` | `get_session_overview` on a candidate |
| Summarize one known session | `get_session_overview` | `get_messages` if exact wording is needed |
| Read exact prior messages/commands | `get_messages` (always `limit`/paginate) | — |
| Full-text search across message/tool content | `search_content` | `get_messages` around the matched ordinal |

Note: `get_usage_summary` is intentionally **not** granted to any persona — token/cost accounting is out of scope for session-history recall.

---

## Token Hygiene

Hard rules for staying within context budget:

1. **Always set `--limit`/`limit`** on `search_sessions`, `list_sessions`, and `search_content` calls — do not request the default/max unless you need breadth.
2. **Always paginate `get_messages`**. Never fetch a whole transcript in one call; use `--around`/`--before`/`--after` or `--from` windows.
3. **Prefer `get_session_overview` or `search_content` snippets over full transcript dumps.** Only call `get_messages` when exact wording matters.
4. **Extract session IDs and short snippets only.** Do not paste raw multi-message transcripts downstream — summarize into bullet findings with session ID + one-line takeaway.
5. **Chain calls, don't parallelize blindly.** Run `search_sessions` or `search_content` first, then decide if `get_session_overview`/`get_messages` is needed for the top match.

---

## Result Interpretation

How to read and trust what AgentsView returns:

### History is a prior, not a mandate

A prior session shows how something *was* handled — not how it *must* be handled now. Requirements, codebase state, and constraints may have changed since. Always treat precedent as informative context, not binding instruction.

### Flag precedent-vs-current-requirement conflicts

When a prior session's approach conflicts with the current task's explicit requirements or constraints, surface the conflict explicitly rather than silently following either one:

```
Precedent (session <id>, <date>): used approach X.
Current requirement: approach Y is specified.
Flagging conflict for the orchestrator/user to resolve.
```

### Trust-but-verify

Session history reflects what happened in that session, not necessarily what was correct or still applies. Cross-check any recalled approach against the current codebase before relying on it — a pattern that worked in a past session may since have been refactored away or found to be wrong.

---

## What NOT to Do

- **Do not treat prior handling as binding** — a past session's approach is a data point, not a requirement.
- **Do not paste raw transcripts downstream** — summarize into session ID + snippet + takeaway; downstream agents need conclusions, not full logs.
- **Do not substitute recall for reading current files** — always verify prior approaches still apply by reading the current codebase state.
- **Do not fetch full transcripts (`get_messages` without pagination) when `search_sessions`/`get_session_overview` already answers the question.**
- **Do not call `get_usage_summary`** — it is not granted; token/cost accounting is out of scope.

---

## Cross-References

- [docs/guides/using-agentsview.md](../../docs/guides/using-agentsview.md) — setup instructions, opt-out, graceful degradation
- [references/tool-reference.md](references/tool-reference.md) — full MCP tool purposes, parameters, cost profiles
- [references/query-patterns.md](references/query-patterns.md) — decision table mapping question types to tool sequences
- [examples/worked-queries.md](examples/worked-queries.md) — end-to-end query scenarios with expected result shapes
- [skills/personal-kb-usage/SKILL.md](../personal-kb-usage/SKILL.md) — sibling skill for cross-project personal knowledge recall (notes/decisions, not session transcripts)
