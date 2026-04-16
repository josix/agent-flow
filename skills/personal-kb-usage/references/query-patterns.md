# Query Patterns — Personal KB Decision Table

Maps cross-project recall question types to tool sequences. For full tool signatures see [tool-reference.md](tool-reference.md).

**BFS vs DFS**:
- BFS (default) — "What is X connected to?" — broad context, nearest neighbors first
- DFS — "How does X reach Y?" — trace a specific chain or decision path through personal notes

---

## Primary Decision Table

| Question type | First tool | Follow-up | Notes |
|---|---|---|---|
| Have I solved this problem before? | `query_graph` (mode=bfs, depth=2) | `get_node` on returned labels for source_location | Start broad, narrow with get_node |
| What did I decide about X in past projects? | `query_graph` (question="X decision", mode=bfs) | `get_neighbors` on best match | Add "decision" or "pattern" to keyword |
| What patterns have I used for Y? | `query_graph` (question="Y pattern", mode=bfs, depth=2) | `get_community` on returned community IDs | Patterns often cluster in personal KB |
| What personal anti-patterns have I documented? | `god_nodes` (top_n=10) | `get_community` on clusters with "anti-pattern" nodes | Central nodes often encode recurring lessons |
| What are my personal core concepts? | `god_nodes` (top_n=10) | `get_community` on community IDs | Reveals dominant themes in personal knowledge |
| Are two personal concepts related? | `shortest_path` (source=A, target=B) | `get_node` on intermediate nodes | Unexpected paths reveal cross-domain links |
| Full details on a specific personal note | `get_node` (label=exact_label) | — | Always cite absolute source_location |
| What connects to a specific personal decision? | `get_neighbors` (label=decision_node) | `get_node` on neighbors for source_location | Use relation_filter to narrow |
| What is the scale of my personal KB? | `graph_stats` | `god_nodes` | Run first to scope the KB |
| Which notes cluster around topic Z? | `query_graph` (question=Z, mode=bfs, depth=2) → read community_id | `get_community` on that community_id | Cluster = topically related notes |

---

## Orientation Sequence (Standard Opening)

Use this sequence when starting cross-project recall in a new session:

```
1. mcp__personal-kb__graph_stats
   → Learn: node count, edge count, community count, confidence breakdown

2. mcp__personal-kb__god_nodes (top_n=10)
   → Learn: top 10 central personal concepts with community IDs

3. mcp__personal-kb__get_community (community_id=<most relevant>)
   → Learn: all personal notes in the target cluster
```

Stop after step 3 unless a specific question remains.

---

## Prior-Decision Recall Sequence

Use when asking "have I solved this before?" or "what did I decide about X?":

```
1. mcp__personal-kb__query_graph (question="<problem or topic>", mode="bfs", depth=2, token_budget=500)
   → Learn: personal notes and decisions related to the topic

2. mcp__personal-kb__get_node (label=<best match from step 1>)
   → Read: full note details and absolute source_location

3. (Optional) mcp__personal-kb__get_neighbors (label=<node from step 2>)
   → Learn: related personal decisions and notes
```

---

## Anti-Pattern / Style Preference Recall Sequence

Use when Lawliet wants to compare current code to documented personal anti-patterns:

```
1. mcp__personal-kb__query_graph (question="anti-pattern <technology or domain>", mode="bfs", depth=2)
   → Learn: personal anti-patterns related to current review concern

2. mcp__personal-kb__get_node (label=<anti-pattern node>)
   → Read: full description and absolute source_location in personal notes

3. mcp__personal-kb__get_neighbors (label=<anti-pattern node>)
   → Check: which other personal concepts are linked (e.g., better alternatives)
```

---

## Cross-Project Connection Sequence

Use when Senku wants to understand if a current design decision relates to past work:

```
1. mcp__personal-kb__shortest_path (source="<current concept>", target="<past project concept>", max_hops=4)
   → Learn: whether concepts are linked in personal knowledge

2. mcp__personal-kb__get_node (label=<intermediate node on path>)
   → Read: what bridges the two concepts
```

If no path is found, the concepts are not linked in personal knowledge.

---

## Token Budget Guidelines

| Tool | Recommended settings |
|---|---|
| `graph_stats` | No args — always cheap |
| `god_nodes` | top_n=10 (default) — keep low |
| `get_node` | No budget arg — single node, cheap |
| `get_neighbors` | Use relation_filter to reduce output |
| `get_community` | Avoid community 0 (largest) without a reason |
| `query_graph` | token_budget=500 for orientation, 1000-2000 for deep recall; depth=2 to start |
| `shortest_path` | max_hops=4-6 for tighter questions, default 8 for discovery |
