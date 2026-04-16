# Using Graphify

A practical guide to the graphify knowledge-graph integration — letting subagents share structural context through a queryable graph of your codebase.

## What is the Graphify Integration?

Graphify is a separate tool that turns any folder of code, docs, and media into a queryable knowledge graph (nodes, edges, communities). Agent Flow ships an integration layer that:

- Auto-launches a graphify **MCP server** at session start (`.mcp.json`).
- Grants **Riko, Senku, and Lawliet** read-only access to 7 graph query tools.
- Detects `graphify-out/` during orchestration init and writes a `graph:` block into state files so the orchestrator knows the graph is available.
- Keeps **Loid and Alphonse** out of the graph-tool list — preserves the one-writer invariant and minimizes blast radius.

Result: subagents can query structure ("what calls this function?", "which community does this file belong to?") instead of grepping blind, without any change to how you invoke orchestrate.

## When to Use It

### Good Use Cases

- **Unfamiliar codebases**: Agents orient faster by querying communities and god nodes before grepping.
- **Large refactors**: Senku can check blast radius via `get_neighbors` before planning.
- **Architecture reviews**: Lawliet can verify that a change respects existing module boundaries.
- **Cross-cutting features**: When a task spans many files, the graph surfaces the right set.

### When to Skip

- **Tiny, localized changes**: Overhead isn't justified.
- **Fresh repos**: Not enough structure to benefit.
- **Highly dynamic code** (lots of metaprogramming): Graph extraction may miss relationships.

## Prerequisites

Install graphify with the `mcp` extra. The wrapper auto-detects both installation methods:

```bash
# Option A: system Python
pip install 'graphifyy[mcp]'

# Option B: isolated via pipx
pipx install graphifyy
pipx inject graphifyy mcp
```

Verify: `graphify --help` should work.

## Basic Usage

### 1. Build the Graph

From your project root, once per repo:

```
/graphify
```

> **Note**: `/graphify` is a user-level skill trigger defined in your personal `~/.claude/CLAUDE.md`, not a built-in Agent Flow plugin command. It invokes the graphify pipeline via the `graphify` CLI. The Agent Flow plugin provides the MCP integration layer (`.mcp.json`, `scripts/start-graphify-mcp.sh`) that makes the resulting graph queryable by subagents — these are separate concerns.

This creates `graphify-out/` containing:

| File | Purpose |
|------|---------|
| `graph.json` | NetworkX node-link data (queryable via MCP) |
| `GRAPH_REPORT.md` | Human-readable summary (god nodes, hyperedges, suggested questions) |
| `manifest.json` | File-to-mtime map for incremental updates |
| `cache/` | SHA256-keyed semantic extraction cache |

Add `graphify-out/` to your `.gitignore` (Agent Flow's `.gitignore` already covers it).

### 2. Refresh After Changes

```
/graphify --update          # incremental, uses manifest
/graphify --watch           # auto-rebuild on save (optional)
```

### 3. Start a Claude Session

No flags needed. On session start, Agent Flow's `.mcp.json` launches `scripts/start-graphify-mcp.sh`, which exposes these 7 MCP tools:

| Tool | Purpose |
|------|---------|
| `query_graph` | Natural-language query against the graph |
| `get_node` | Fetch a specific node by id |
| `get_neighbors` | Adjacent nodes (1-hop) |
| `get_community` | Nodes in a detected community |
| `god_nodes` | Highest-centrality nodes (architectural hotspots) |
| `graph_stats` | Node/edge/community counts |
| `shortest_path` | Path between two nodes |

Confirm the server connected:

```
/mcp
```

`graphify` should appear as connected.

### 4. Orchestrate — Graph-Aware Mode Activates Automatically

```
/agent-flow:orchestrate <your task>
```

What happens under the hood:

1. `init-orchestration.sh` calls `detect-graph-context.sh`, which writes a `graph:` block into `.claude/orchestration.local.md`.
2. The orchestrator reads that block and injects a one-line preamble into each `Task(...)` call telling Riko/Senku/Lawliet the graph is available and how to query.
3. Subagents use MCP tools for structural queries, falling back to `Grep`/`Read` for fine-grained lookups.

Same behavior for `/agent-flow:team-orchestrate` and `/agent-flow:deep-dive`.

## Ad-Hoc Queries

You don't need to orchestrate to use the graph. In any session:

> What are the god nodes in this repo?
> Show me neighbors of `init-orchestration.sh`.
> Find the shortest path between `Riko.md` and `verify-completion.sh`.

Claude calls the MCP tools directly.

## How Access is Scoped

| Agent | Graph Tools? | Rationale |
|-------|--------------|-----------|
| **Riko** | Yes | Explorer — orients faster via god nodes / communities |
| **Senku** | Yes | Planner — checks blast radius and dependencies |
| **Lawliet** | Yes | Reviewer — verifies module boundary adherence |
| **Loid** | No | Executor writes code; graph is a read model |
| **Alphonse** | No | Verifier runs tests; doesn't reason about structure |

The graph is a **read-only snapshot**. Only the orchestrator ever writes (via `/graphify --update`). Teammate sessions get read-only access — this avoids the write-race problem since graphify has no concurrency primitives.

## The `graph:` State Block

When `graphify-out/` exists, the state file gains:

```yaml
graph:
  available: true
  path: "graphify-out/graph.json"
  generated: "2026-04-13T22:15:00Z"
  nodes: 1626
  edges: 2346
  communities: 135
```

When it doesn't exist:

```yaml
graph:
  available: false
  path: ""
  generated: ""
  nodes: 0
  edges: 0
  communities: 0
```

See [State Files Reference](../reference/state-files.md#graph-object) for the full schema.

## Best Practices

### 1. Keep the Graph Fresh

After significant changes — merged PRs, large refactors, new modules — run `/graphify --update`. For active sessions with frequent edits, `/graphify --watch` keeps it live.

Rule of thumb: update if structure changed, skip if only behavior changed.

### 2. Don't Paste `graph.json` into Prompts

The file is large (thousands of nodes). Use MCP tools for targeted queries, or include excerpts from `GRAPH_REPORT.md` — never the raw JSON.

### 3. Trust but Verify

The graph reflects state at extraction time. If a subagent answers based on graph data, spot-check by reading the actual files. Especially true for recent edits that haven't been re-indexed.

### 4. Don't Commit `graphify-out/`

It's generated and user-specific (caches include local paths). Agent Flow's `.gitignore` already excludes it.

### 5. Let the Orchestrator Drive Updates

Don't fire `/graphify --update` from a subagent. Only the parent Claude session updates the graph — this preserves the one-writer invariant for parallel team modes.

## Architecture Notes

### Why MCP + Skill, Not One or the Other

- **MCP server** (`scripts/start-graphify-mcp.sh` + `.mcp.json`): primary access path for subagents. Works even for tool-restricted agents like Senku (which doesn't have `Bash`).
- **`/graphify` skill**: used by the orchestrator for lifecycle ops (`--update`, full rebuilds). Not suitable for mid-task subagent queries because it's a user-level trigger.

See the [design decision](../architecture/design-decisions.md) for the full rationale.

### Portability

`.mcp.json` invokes a wrapper script, not a hardcoded Python path. The wrapper tries `python3`, `python`, and — as a fallback — parses the shebang of the `graphify` CLI on `PATH` to locate a pipx venv's Python. Works for any user's install layout.

### Failure Modes with Targeted Guidance

If the MCP server fails to start, running the wrapper manually gives a specific error:

| State | Error | Fix |
|-------|-------|-----|
| graphify not installed | "graphify is not installed." | `pip install 'graphifyy[mcp]'` or `pipx install graphifyy && pipx inject graphifyy mcp` |
| Installed via pip, no `mcp` extra | "'mcp' extra is missing." | `pip install 'graphifyy[mcp]'` |
| Installed via pipx, no `mcp` extra | "'mcp' extra is missing." | `pipx inject graphifyy mcp` |
| All good, graph missing | "Graph file not found" | Run `/graphify` |

## Troubleshooting

### `/mcp` Shows `graphify` as Failed

Run the wrapper directly from your project root:

```bash
./scripts/start-graphify-mcp.sh
```

The stderr output will tell you exactly what's missing.

### Subagents Ignore the Graph

Check the state file:

```bash
grep -A6 '^graph:' .claude/orchestration.local.md
```

If `available: false`, run `/graphify` to build it.

### Stale Answers

The graph is a snapshot. Refresh with `/graphify --update`.

### Want to See What the Graph Knows

```bash
cat graphify-out/GRAPH_REPORT.md
```

Shows god nodes, hyperedges, and suggested questions.

### Graph Build Takes Too Long

For very large repos, scope it:

```
/graphify --update          # incremental only changed files
```

Or use watch mode during active sessions instead of full rebuilds.

## Example Session

```
# First-time setup
User: pip install 'graphifyy[mcp]'
User: /graphify
[graph built in graphify-out/]

# Now every orchestration is graph-aware
User: /agent-flow:orchestrate Refactor auth middleware to use new token format

[Riko uses query_graph to find auth-related nodes]
Found: 12 nodes in community "auth", centered on src/middleware/auth.ts

[Senku uses get_neighbors to check blast radius]
Blast: 8 files import auth-middleware; 3 tests depend on token format

[Loid implements changes]
Modified: src/middleware/auth.ts, src/types/token.ts, 3 callers

[Lawliet uses get_community to verify boundaries]
Verdict: APPROVED — changes stay within auth community

[Alphonse runs tests]
Tests: 47/47 passed | Types: clean | Lint: clean

<orchestration-complete>TASK VERIFIED</orchestration-complete>
```

## Related Documentation

- [Installation](../getting-started/installation.md) — plugin setup
- [State Files Reference](../reference/state-files.md#graph-object) — `graph:` block schema
- [Using Orchestrate](using-orchestrate.md) — the main workflow
- [Agents Reference](../reference/agents.md) — which agents have MCP tools
