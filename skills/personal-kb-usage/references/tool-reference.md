# Tool Reference — personal-kb MCP Tools

All tools are accessed via the prefix `mcp__personal-kb__*`. These tools query the user's personal knowledge base graph (stored at `$AGENT_FLOW_PERSONAL_KB_PATH/graphify-out/graph.json`), NOT the current project's graph. For the current project's graph, see the `graphify-usage` skill.

---

## query_graph

**Full MCP name**: `mcp__personal-kb__query_graph`

**Purpose**: Search the personal knowledge base graph using a natural language question or keyword. Returns relevant nodes and edges as text context. The primary general-purpose tool for cross-project recall queries.

**Signature**:
```
question       (string, required)  — natural language question or keyword search
mode           (string, optional)  — "bfs" (default) or "dfs"
depth          (integer, optional) — traversal depth 1–6, default 3
token_budget   (integer, optional) — max output tokens, default 2000
```

**Mode guidance**:
- **BFS** (default): "What is X connected to?" — broad context, nearest neighbors first. Use for orientation and discovering connected personal notes.
- **DFS**: "How does X reach Y?" — trace a specific chain or decision path. Use when you need to follow a single thread of related personal notes.

**When to use**: Open-ended cross-project recall where you don't know the exact node label. Prefer specific tools (`get_node`, `get_neighbors`) when you have a label.

**Cost profile**: Medium-to-high. Always set `token_budget` explicitly. Start with `depth=2` for orientation, increase to 3-4 only if needed.

---

## get_node

**Full MCP name**: `mcp__personal-kb__get_node`

**Purpose**: Get full details for a specific personal KB node by its label or ID. Returns all properties including `source_location` (absolute path), confidence tags, and edge list.

**Signature**:
```
label   (string, required) — node label or ID to look up
```

**When to use**: When you know the exact node name (from a prior `query_graph`, `god_nodes`, or `get_neighbors` result) and need its full details and `source_location` (absolute path into personal KB).

**Cost profile**: Low. Single node lookup; always safe to call.

---

## get_neighbors

**Full MCP name**: `mcp__personal-kb__get_neighbors`

**Purpose**: Get all direct neighbors of a personal KB node with edge relation details. Reveals what a personal concept connects to and how (edge relation type, confidence tag).

**Signature**:
```
label             (string, required) — node label or ID
relation_filter   (string, optional) — filter by relation type (e.g., "references", "supersedes", "relates_to")
```

**When to use**: Finding related personal decisions, notes that reference a concept, or understanding how personal notes cluster around a topic. The `relation_filter` parameter narrows results.

**Cost profile**: Low-to-medium depending on node degree. High-degree (central) nodes may return many neighbors — consider `relation_filter` to narrow.

---

## get_community

**Full MCP name**: `mcp__personal-kb__get_community`

**Purpose**: Get all nodes that belong to a specific community (cluster) by community ID in the personal KB. Communities are 0-indexed by size (community 0 is largest).

**Signature**:
```
community_id   (integer, required) — community ID (0-indexed by size)
```

**When to use**: Exploring all personal notes around a topic cluster, understanding which personal concepts group together. Community IDs come from `god_nodes` results or `get_node` properties.

**Cost profile**: Low-to-medium depending on community size. Large communities (ID 0, 1, 2) may be verbose.

---

## god_nodes

**Full MCP name**: `mcp__personal-kb__god_nodes`

**Purpose**: Return the most connected nodes in the personal KB — the central concepts of the user's personal knowledge, ranked by degree centrality. These are the structural "hubs" of personal notes.

**Signature**:
```
top_n   (integer, optional) — number of nodes to return, default 10
```

**When to use**: Initial orientation in the personal KB, finding central personal themes before a deeper recall query, understanding what concepts dominate the user's personal knowledge.

**Cost profile**: Low. Always keep `top_n` at 10 or below unless you have a specific reason. Returns node labels, degree counts, and community IDs.

---

## graph_stats

**Full MCP name**: `mcp__personal-kb__graph_stats`

**Purpose**: Return summary statistics for the entire personal KB graph: node count, edge count, community count, and confidence breakdown (EXTRACTED / INFERRED / AMBIGUOUS counts).

**Signature**: No arguments.

**When to use**: First call in any personal KB session to scope the personal knowledge base size. Also useful for determining how much to trust the graph (high AMBIGUOUS count = lower trust). Takes under 1 second — always safe to call first.

**Cost profile**: Minimal. No arguments, instant response.

---

## shortest_path

**Full MCP name**: `mcp__personal-kb__shortest_path`

**Purpose**: Find the shortest path between two concepts in the personal KB graph. Returns the chain of nodes and edges connecting source to target personal concepts.

**Signature**:
```
source     (string, required)  — source concept label or keyword
target     (string, required)  — target concept label or keyword
max_hops   (integer, optional) — maximum hops to consider, default 8
```

**When to use**: Understanding how two seemingly unrelated personal concepts or decisions are connected in the user's knowledge base. Useful for discovering unexpected cross-domain links in personal notes.

**Cost profile**: Low-to-medium. If no path exists within `max_hops`, returns empty. Lower `max_hops` (e.g., 4) for tighter conceptual coupling checks.
