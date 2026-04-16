# Query Patterns — Decision Table

Maps question types to tool sequences. For full tool signatures see [tool-reference.md](tool-reference.md).

**BFS vs DFS** (from `graphify/graphify/skill.md:917-944`):
- BFS (default) — "What is X connected to?" — broad context, nearest neighbors first
- DFS — "How does X reach Y?" — trace a specific chain or dependency path

---

## Primary Decision Table

| Question type | First tool | Follow-up | Notes |
|---|---|---|---|
| Orient me in this repo | `graph_stats` | `god_nodes` | Check node/edge counts first for scope |
| What are the core abstractions? | `god_nodes` (top_n=10) | `get_community` on interesting community IDs | God nodes reveal structural hubs |
| Which modules cluster together? | `god_nodes` → read community IDs | `get_community` | Use community IDs from god_nodes result |
| Who calls X? / What imports X? | `get_neighbors` (label=X, relation_filter="calls") | `get_node` on callers for source_location | Filter by relation type |
| What does X call / depend on? | `get_neighbors` (label=X, relation_filter="imports") | `get_node` on dependencies | Outbound edges |
| Blast radius of changing Y | `get_neighbors` (label=Y) | `shortest_path` from Y to suspected downstream | Combine for full picture |
| How are concept A and B related? | `shortest_path` (source=A, target=B) | `get_node` on intermediate nodes | Lower max_hops for tight coupling check |
| What is the main entry point? | `query_graph` (question="main entry point orchestration", mode=bfs) | `get_node` on top result | Keyword-based search |
| Does changing X break module boundary? | `get_node` (label=X) → read community_id | `get_community` on that community_id, check if callers share it | Lawliet boundary check |
| What concepts relate to "authentication"? | `query_graph` (question="authentication", mode=bfs, depth=2) | `get_node` on returned labels | Open-ended keyword search |
| Trace execution from A to B | `shortest_path` (source=A, target=B) or `query_graph` (mode=dfs) | `get_node` on path nodes | DFS if chain is the goal |
| Full details on a known node | `get_node` (label=exact_label) | — | Always cite source_location |

---

## Orientation Sequence (Standard Opening)

Use this sequence when starting exploration in an unfamiliar repo:

```
1. mcp__plugin_agent-flow_graphify__graph_stats
   → Learn: node count, edge count, community count, confidence breakdown

2. mcp__plugin_agent-flow_graphify__god_nodes (top_n=10)
   → Learn: top 10 structural hubs with community IDs

3. mcp__plugin_agent-flow_graphify__get_community (community_id=<largest community>)
   → Learn: all concepts in the dominant cluster
```

Stop after step 3 unless a specific question remains.

---

## Blast Radius Sequence

Use before a refactor to understand downstream impact:

```
1. mcp__plugin_agent-flow_graphify__get_neighbors (label=<target>, relation_filter=optional)
   → Learn: direct dependencies and dependents (1-hop)

2. mcp__plugin_agent-flow_graphify__shortest_path (source=<target>, target=<suspected downstream>)
   → Learn: chain of relationships connecting the change to its effects
```

If no path is found, the concepts are structurally independent.

---

## Module Boundary Check Sequence (Lawliet)

Use during review to verify a changed node does not cross community boundaries:

```
1. mcp__plugin_agent-flow_graphify__get_node (label=<changed node>)
   → Read: community_id field

2. mcp__plugin_agent-flow_graphify__get_community (community_id=<from step 1>)
   → List: all nodes in the same community

3. mcp__plugin_agent-flow_graphify__get_neighbors (label=<changed node>)
   → Check: do all callers share the same community_id?
```

If callers span multiple communities, flag as a potential boundary violation.

---

## Token Budget Guidelines

| Tool | Recommended settings |
|---|---|
| `graph_stats` | No args — always cheap |
| `god_nodes` | top_n=10 (default) — keep low |
| `get_node` | No budget arg — single node, cheap |
| `get_neighbors` | Use relation_filter to reduce output |
| `get_community` | Avoid community 0 (largest) without a reason |
| `query_graph` | token_budget=500 for orientation, 1000-2000 for deep dives; depth=2 to start |
| `shortest_path` | max_hops=4-6 for architectural questions, default 8 for discovery |
