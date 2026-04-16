---
name: graphify-usage
description: This skill should be used when querying the graphify knowledge graph for structural codebase information, choosing between graph tools and grep, or interpreting graph query results.
---

# Graphify Usage

Query the knowledge graph effectively, interpret results accurately, and stay within token budgets.

## Overview

The graphify MCP server exposes the codebase as a pre-built knowledge graph stored in `graphify-out/graph.json`. The graph encodes structural relationships between concepts, modules, and files extracted by the graphify pipeline. This skill governs when, how, and with what discipline agents should query it.

**Owner**: Riko (Explorer Agent) — Riko is the primary graph query agent and owns interpretation of results.
**Consumers**: Senku (Planner Agent), Lawliet (Reviewer Agent) — both may consult the graph during planning and review, but Riko is the preferred query agent for deep exploration.
**Out of scope**: Loid (Executor) and Alphonse (Verifier) do NOT have graph access by design. Loid performs file writes and needs test output, not structural queries; Alphonse runs verification commands that cannot rely on graph freshness. This enforces the one-writer invariant: only agents that need structural context hold graph tool permissions.

All 7 tools are accessed via the MCP prefix `mcp__plugin_agent-flow_graphify__*`. See [references/tool-reference.md](references/tool-reference.md) for full signatures.

---

## When to Query the Graph vs. Grep

Use the graph when you need structural relationships. Use grep when you need literal text matches.

| Trigger condition | Preferred approach |
|---|---|
| "What modules import X?" / dependency mapping | Graph: `get_neighbors` with `relation_filter` |
| "What is the main entry point?" / orientation | Graph: `graph_stats` then `god_nodes` |
| "How does component A connect to component B?" | Graph: `shortest_path` |
| "Which community does file F belong to?" | Graph: `get_community` on node label |
| "Find the string literal `TODO: fix`" | Grep |
| "Find all files that define function `parse_args`" | Grep (pattern match) |
| "What does a specific config key say?" | Read the file directly |
| File is freshly edited (within this session) | Grep/Read — graph may be stale |
| Graph does not exist at `graphify-out/graph.json` | Grep/Read only |

**Rule of thumb**: If the answer requires traversal (who calls what, what clusters together, how far apart are two concepts), use the graph. If the answer is a literal substring or you need up-to-the-edit accuracy, use Grep or Read.

---

## Tool Decision Table

Choose the right tool for the question type. See [references/query-patterns.md](references/query-patterns.md) for detailed decision sequences.

| Question type | Primary tool | Follow-up |
|---|---|---|
| How large is this codebase? | `graph_stats` | `god_nodes` for core abstractions |
| What are the central concepts? | `god_nodes` | `get_community` to explore clusters |
| Which modules are in the same cluster? | `get_community` | `get_node` on members |
| What does this node connect to? | `get_neighbors` | `get_node` on callers/callees |
| Blast radius of changing X | `get_neighbors` then `shortest_path` | Manual review of connected files |
| Full structural/semantic question | `query_graph` (BFS for broad, DFS for path) | `get_node` on returned labels |
| Specific node details | `get_node` | — |
| Path between two concepts | `shortest_path` | `get_node` on intermediate nodes |

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

How to read and trust what the graph returns:

### Cite `source_location` fields

Every node in the graph carries a `source_location` field (file path, sometimes line range). When reporting a finding, always cite this field:

```
Node: AgentOrchestrator
source_location: commands/orchestrate.md:1
```

Never report a concept without its `source_location` — downstream agents cannot verify unsourced claims.

### Surface confidence tags

The graph annotates edges with confidence labels:

| Tag | Meaning | Trust level |
|---|---|---|
| EXTRACTED | Directly observed in source text | High — treat as fact |
| INFERRED | Model-reasoned relationship | Medium — verify if load-bearing |
| AMBIGUOUS | Multiple interpretations possible | Low — always verify with Read/Grep |

When an edge is INFERRED or AMBIGUOUS, note this explicitly in your summary. Do not present inferred relationships as certainties.

### Trust-but-verify for freshly edited files

The graph is built once (at `/graphify` time) and is not updated during a session. If Loid has modified a file in the current session, graph data for that node is stale. For any file touched in this session:
- Use the graph for structural orientation only
- Use Read or Grep for current content

---

## What NOT to Do

- **Do not query the graph on freshly edited files** expecting current content — it will be stale.
- **Do not set `depth` > 4** without a specific reason — the output will overflow context.
- **Do not pass raw graph JSON blobs** in task descriptions or summaries to other agents.
- **Do not fire `query_graph` for questions answerable by `get_node` or `get_neighbors`** — cheaper specific tools first.
- **Do not report INFERRED edges as facts** — always surface the confidence tag.
- **Do not skip `source_location` citations** — every claimed relationship needs a file anchor.
- **Do not use graph results as a substitute for reading changed files** — the graph captures structure, not current content.

---

## Cross-References

- [docs/guides/using-graphify.md](../../docs/guides/using-graphify.md) — installation, build steps, and how to run the graphify pipeline
- [references/tool-reference.md](references/tool-reference.md) — full MCP tool signatures, parameters, cost profiles
- [references/query-patterns.md](references/query-patterns.md) — decision table mapping question types to tool sequences
- [examples/worked-queries.md](examples/worked-queries.md) — end-to-end query scenarios with expected result shapes
