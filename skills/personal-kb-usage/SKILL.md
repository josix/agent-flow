---
name: personal-kb-usage
description: This skill should be used when querying the user's personal knowledge base (cross-project personal knowledge graph) for prior learnings, notes, or decisions that apply across projects.
---

# Personal KB Usage

Query the user's personal knowledge base effectively, interpret results accurately, and stay within token budgets.

## Overview

The personal-kb MCP server exposes the user's cross-project personal knowledge base as a pre-built knowledge graph stored at `$AGENT_FLOW_PERSONAL_KB_PATH/graphify-out/graph.json`. This is a graph built by the user from their own notes, journals, decision records, or any other personal documents — outside of any single project directory.

**Owner**: Riko (Explorer Agent) — Riko is the primary personal-kb query agent and owns interpretation of results.
**Consumers**: Senku (Planner Agent), Lawliet (Reviewer Agent) — both may consult the personal KB during planning and review to surface cross-project decisions and patterns.
**Out of scope**: Loid (Executor) and Alphonse (Verifier) do NOT have personal-kb access by design. This preserves the one-writer invariant and keeps write/verify agents focused on project artifacts.

All 7 tools are accessed via the MCP prefix `mcp__personal-kb__*`. See [references/tool-reference.md](references/tool-reference.md) for full signatures.

**Contrast with `graphify-usage`**:
- `graphify-usage` — queries the **current project's** graph at `graphify-out/graph.json` (relative to project root). Use for structural questions about THIS codebase.
- `personal-kb-usage` — queries the **user's personal** graph at an absolute path outside the project. Use for cross-project recall: prior decisions, anti-patterns encountered before, personal preferences, notes from past work.

---

## When to Query the Personal KB vs. Project Graph vs. Grep

| Trigger condition | Preferred approach |
|---|---|
| "Have I solved this problem before in another project?" | Personal KB: `query_graph` |
| "What did I decide about X in past projects?" | Personal KB: `query_graph` |
| "What patterns have I used for Y across codebases?" | Personal KB: `query_graph` |
| "What personal anti-patterns have I documented?" | Personal KB: `god_nodes` then `get_community` |
| "What is the dependency structure of THIS project?" | Project graph (`graphify-usage`) |
| "Which community does file F belong to in THIS repo?" | Project graph (`graphify-usage`) |
| "Find the string literal `TODO: fix`" | Grep |
| "What does a specific config key say in THIS project?" | Read the file directly |
| Personal KB is not configured (`available: false` in state) | Skip — use project graph or Grep |

**Rule of thumb**: Personal KB is for **memory across sessions and projects**. Project graph is for **structure within this session's codebase**. Grep/Read is for **current file content**.

---

## Tool Decision Table

Choose the right tool for the question type. See [references/query-patterns.md](references/query-patterns.md) for detailed decision sequences.

| Question type | Primary tool | Follow-up |
|---|---|---|
| What prior decisions exist on topic X? | `query_graph` (BFS, depth=2) | `get_node` on returned labels |
| What are my recurring patterns / hubs? | `god_nodes` | `get_community` to explore clusters |
| Which personal notes cluster around topic Y? | `get_community` | `get_node` on members |
| What connects concept A to decision B? | `get_neighbors` | `get_node` on connectors |
| Have I documented an anti-pattern like Z? | `query_graph` (BFS for broad, DFS for specific chain) | `get_node` on results |
| Full details on a known personal note/decision | `get_node` | — |
| Path between two cross-project concepts | `shortest_path` | `get_node` on intermediate nodes |
| Overall scale of personal KB | `graph_stats` | `god_nodes` for central concepts |

---

## Token Hygiene

Hard rules for staying within context budget:

1. **Always set `top_k` / `top_n`** when available. Default `god_nodes` returns 10 nodes — only request more if explicitly needed.
2. **Set `token_budget`** on `query_graph` calls. The default is 2000 tokens; lower it (e.g., 500) for quick orientation queries.
3. **Set `depth` conservatively**. Default depth is 3; start at 1-2 for narrow questions, increase only if the result is insufficient.
4. **Do NOT paste raw subgraph JSON downstream** into task prompts or summaries. Extract only node IDs, labels, and `source_location` fields.
5. **Summarize before handing off**. Convert graph results to bullet lists of `label → source_location` pairs. Downstream agents (Senku, Lawliet) need names and file paths, not raw graph output.
6. **Chain calls, don't parallelize blindly**. Run `graph_stats` first, then decide if `god_nodes` is needed. Avoid firing all 7 tools simultaneously.

---

## Result Interpretation

How to read and trust what the personal KB returns:

### Cite `source_location` fields with ABSOLUTE paths

Every node in the personal KB graph carries a `source_location` field (file path, sometimes line range). Because the personal KB lives **outside the current project root**, always report these as absolute paths:

```
Node: AuthDecision2025
source_location: /Users/you/personal/knowledge-base/decisions/auth-patterns.md:42
```

Never truncate these to relative paths — downstream agents working in a different project directory cannot resolve relative paths pointing into the personal KB.

### Surface confidence tags

The graph annotates edges with confidence labels:

| Tag | Meaning | Trust level |
|---|---|---|
| EXTRACTED | Directly observed in source text | High — treat as fact |
| INFERRED | Model-reasoned relationship | Medium — verify if load-bearing |
| AMBIGUOUS | Multiple interpretations possible | Low — always verify with Read |

When an edge is INFERRED or AMBIGUOUS, note this explicitly in your summary.

### Personal KB vs. project docs

The personal KB reflects the user's **personal notes and past decisions**, not authoritative project documentation. When personal KB content conflicts with current project docs:

- Project docs take precedence for THIS project's requirements.
- Personal KB is a useful prior but not a mandate.
- Note conflicts explicitly so Senku or Lawliet can resolve them.

### Trust-but-verify for recently updated notes

The personal KB graph is built once (at the user's last `/graphify` run on their KB) and is not updated during a session. If the user has recently added notes, those may not be indexed yet.

---

## What NOT to Do

- **Do not paste personal KB content into commit messages, PR descriptions, or other public artifacts** — user notes may contain private context or personal opinions not intended for external audiences.
- **Do not assume the personal KB is always authoritative over project docs** — personal priors should inform, not override, current requirements.
- **Do not skip the project graph query just because the personal KB has similar content** — the project graph reflects THIS codebase's actual structure; personal KB reflects past experience that may not apply.
- **Do not query the personal KB on freshly edited personal notes** expecting current content — the graph is a snapshot.
- **Do not set `depth` > 4** without a specific reason — output will overflow context.
- **Do not pass raw graph JSON blobs** in task descriptions or summaries to other agents.
- **Do not report INFERRED edges as facts** — always surface the confidence tag.
- **Do not skip `source_location` citations** — every claimed relationship needs a file anchor (absolute path).

---

## Cross-References

- [docs/guides/using-personal-kb.md](../../docs/guides/using-personal-kb.md) — setup instructions, env var contract, verification steps
- [references/tool-reference.md](references/tool-reference.md) — full MCP tool signatures, parameters, cost profiles
- [references/query-patterns.md](references/query-patterns.md) — decision table mapping question types to tool sequences
- [examples/worked-queries.md](examples/worked-queries.md) — end-to-end query scenarios with expected result shapes
- [skills/graphify-usage/SKILL.md](../graphify-usage/SKILL.md) — sibling skill for querying the current project's graph
