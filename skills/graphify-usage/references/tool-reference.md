# Tool Reference — graphify MCP Tools

Authoritative signatures derived from `graphify/graphify/serve.py:156-226`. All tools are accessed via the prefix `mcp__plugin_agent-flow_graphify__`.

---

## query_graph

**Full MCP name**: `mcp__plugin_agent-flow_graphify__query_graph`

**Purpose**: Search the knowledge graph using a natural language question or keyword. Returns relevant nodes and edges as text context. The primary general-purpose tool for exploratory questions.

**Signature**:
```
question       (string, required)  — natural language question or keyword search
mode           (string, optional)  — "bfs" (default) or "dfs"
depth          (integer, optional) — traversal depth 1–6, default 3
token_budget   (integer, optional) — max output tokens, default 2000
```

**Mode guidance** (from `graphify/graphify/skill.md:917-944`):
- **BFS** (default): "What is X connected to?" — broad context, nearest neighbors first. Use for orientation and discovering connected concepts.
- **DFS**: "How does X reach Y?" — trace a specific chain or dependency path. Use when you need to follow a single chain of relationships.

**When to use**: Open-ended structural questions where you don't know the exact node label. Prefer specific tools (`get_node`, `get_neighbors`) when you have a label.

**Cost profile**: Medium-to-high. Always set `token_budget` explicitly. Start with `depth=2` for orientation, increase to 3-4 only if needed.

---

## get_node

**Full MCP name**: `mcp__plugin_agent-flow_graphify__get_node`

**Purpose**: Get full details for a specific node by its label or ID. Returns all properties including `source_location`, confidence tags, and edge list.

**Signature**:
```
label   (string, required) — node label or ID to look up
```

**When to use**: When you know the exact node name (from a prior `query_graph`, `god_nodes`, or `get_neighbors` result) and need its full details and `source_location`.

**Cost profile**: Low. Single node lookup; always safe to call.

---

## get_neighbors

**Full MCP name**: `mcp__plugin_agent-flow_graphify__get_neighbors`

**Purpose**: Get all direct neighbors of a node with edge relation details. Reveals what a concept connects to and how (edge relation type, confidence tag).

**Signature**:
```
label             (string, required) — node label or ID
relation_filter   (string, optional) — filter by relation type (e.g., "calls", "imports", "uses")
```

**When to use**: Dependency mapping, blast-radius estimation, finding callers/callees of a concept. The `relation_filter` parameter is key for narrowing results (e.g., only `imports` edges).

**Cost profile**: Low-to-medium depending on node degree. High-degree (god) nodes may return many neighbors — consider `relation_filter` to narrow.

---

## get_community

**Full MCP name**: `mcp__plugin_agent-flow_graphify__get_community`

**Purpose**: Get all nodes that belong to a specific community (cluster) by community ID. Communities are 0-indexed by size (community 0 is largest).

**Signature**:
```
community_id   (integer, required) — community ID (0-indexed by size)
```

**When to use**: Module boundary verification (Lawliet use case), understanding which concepts cluster together, checking if a changed node's callers stay within the same community. Community IDs come from `god_nodes` results or `get_node` properties.

**Cost profile**: Low-to-medium depending on community size. Large communities (ID 0, 1, 2) may be verbose — consider whether you need all members.

---

## god_nodes

**Full MCP name**: `mcp__plugin_agent-flow_graphify__god_nodes`

**Purpose**: Return the most connected nodes — the core abstractions of the knowledge graph, ranked by degree centrality. These are the structural "hubs" of the codebase.

**Signature**:
```
top_n   (integer, optional) — number of nodes to return, default 10
```

**When to use**: Initial orientation in an unfamiliar repo, finding central abstractions before a deep dive, understanding the dominant concepts the codebase revolves around.

**Cost profile**: Low. Always keep `top_n` at 10 or below unless you have a specific reason. Returns node labels, degree counts, and community IDs.

---

## graph_stats

**Full MCP name**: `mcp__plugin_agent-flow_graphify__graph_stats`

**Purpose**: Return summary statistics for the entire graph: node count, edge count, community count, and confidence breakdown (EXTRACTED / INFERRED / AMBIGUOUS counts).

**Signature**: No arguments.

**When to use**: First call in any graph session to scope the codebase size. Also useful for determining how much to trust the graph (high AMBIGUOUS count = lower trust). Takes under 1 second and costs almost nothing — always safe to call first.

**Cost profile**: Minimal. No arguments, instant response.

---

## shortest_path

**Full MCP name**: `mcp__plugin_agent-flow_graphify__shortest_path`

**Purpose**: Find the shortest path between two concepts in the knowledge graph. Returns the chain of nodes and edges connecting source to target.

**Signature**:
```
source     (string, required)  — source concept label or keyword
target     (string, required)  — target concept label or keyword
max_hops   (integer, optional) — maximum hops to consider, default 8
```

**When to use**: Blast-radius analysis (how does changing X eventually affect Y?), understanding the coupling between two seemingly unrelated concepts, verifying architectural boundaries.

**Cost profile**: Low-to-medium. If no path exists within `max_hops`, returns empty. Lower `max_hops` (e.g., 4) for tighter architectural questions.
