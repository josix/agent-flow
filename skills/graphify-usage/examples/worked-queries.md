# Worked Query Examples

End-to-end scenarios showing question → tool call → result shape → how to use.

---

## Scenario 1 — Riko orienting in an unfamiliar repo

**Question**: "I've never seen this codebase before. Give me a structural overview."

**Tool sequence**:

**Step 1**: Get high-level stats.
```
mcp__plugin_agent-flow_graphify__graph_stats()
```
Expected result shape:
```
nodes: 412
edges: 1847
communities: 23
confidence: { EXTRACTED: 1203, INFERRED: 544, AMBIGUOUS: 100 }
```
How to use: Scope the codebase (412 nodes = medium-sized), note that 29% of edges are INFERRED — verify load-bearing relationships.

**Step 2**: Identify structural hubs.
```
mcp__plugin_agent-flow_graphify__god_nodes(top_n=10)
```
Expected result shape:
```
1. AgentOrchestrator   degree=89  community=0  source_location: commands/orchestrate.md:1
2. Riko                degree=67  community=1  source_location: agents/Riko.md:1
3. Senku               degree=61  community=1  source_location: agents/Senku.md:1
...
```
How to use: Top nodes reveal central abstractions. Note community IDs for next step.

**Step 3**: Drill into the largest community.
```
mcp__plugin_agent-flow_graphify__get_community(community_id=0)
```
Expected result shape: List of all nodes in community 0 with labels and source_locations.
How to use: This community likely contains the core orchestration concepts. Map labels to file paths via source_location. Summarize as: "Community 0 = orchestration layer: commands/orchestrate.md, commands/team-orchestrate.md, scripts/init-orchestration.sh".

**Handoff summary** to Senku: "Core abstractions: AgentOrchestrator (commands/orchestrate.md), agent definitions (agents/*.md). Three main communities: orchestration (0), agents (1), skills (2). Graph has 412 nodes, moderate INFERRED edge ratio — verify any edge marked INFERRED before using for planning."

---

## Scenario 2 — Senku checking blast radius before a refactor

**Question**: "If I change how `Riko` communicates results, what else might break?"

**Tool sequence**:

**Step 1**: Find direct neighbors of the Riko node.
```
mcp__plugin_agent-flow_graphify__get_neighbors(label="Riko")
```
Expected result shape:
```
Inbound (callers of Riko):
  - AgentOrchestrator --[spawns]--> Riko  (EXTRACTED)
  - TeamOrchestrator  --[spawns]--> Riko  (EXTRACTED)

Outbound (Riko depends on):
  - exploration-strategy  --[uses]-->  Riko  (EXTRACTED)
  - agent-behavior-constraints  --[constrained_by]--> Riko  (EXTRACTED)
```
How to use: AgentOrchestrator and TeamOrchestrator are the callers. Changing Riko's output format will require updating both.

**Step 2**: Trace path to a suspected downstream.
```
mcp__plugin_agent-flow_graphify__shortest_path(source="Riko", target="Senku", max_hops=4)
```
Expected result shape:
```
Riko → [spawned_by] → AgentOrchestrator → [delegates_to] → Senku
hops: 2
```
How to use: Riko and Senku are 2 hops apart through AgentOrchestrator. Any change to Riko's output contract must be reflected in how AgentOrchestrator passes results to Senku.

**Planning note for Senku**: "Blast radius: AgentOrchestrator (commands/orchestrate.md), TeamOrchestrator (commands/team-orchestrate.md). Senku is affected indirectly via orchestrator. Loid needs to update 3 files."

---

## Scenario 3 — Lawliet verifying module boundary adherence

**Question**: "The PR adds a new function in `commands/orchestrate.md`. Do its callers stay within the orchestration community?"

**Tool sequence**:

**Step 1**: Get node details for the changed concept.
```
mcp__plugin_agent-flow_graphify__get_node(label="AgentOrchestrator")
```
Expected result shape:
```
label: AgentOrchestrator
source_location: commands/orchestrate.md:1
community_id: 0
edges: [...]
```
How to use: Note community_id = 0 (orchestration community).

**Step 2**: Get all nodes in that community.
```
mcp__plugin_agent-flow_graphify__get_community(community_id=0)
```
How to use: Build a set of labels that legitimately belong to community 0.

**Step 3**: Check neighbors of the changed node.
```
mcp__plugin_agent-flow_graphify__get_neighbors(label="AgentOrchestrator")
```
Expected check: For each inbound caller, verify its community_id matches 0. If a caller from community 3 (skills layer) now directly calls into community 0 (orchestration), flag as boundary violation.

**Review comment template**: "Node `AgentOrchestrator` (community 0) is called by `X` (community 3). This crosses the orchestration/skills boundary. Confirm this coupling is intentional or route through the appropriate interface."

---

## Scenario 4 — Riko answering "what is the main orchestration entry point?"

**Question**: "Where does orchestration start? What is the top-level entry point?"

**Tool sequence**:

**Single call**:
```
mcp__plugin_agent-flow_graphify__query_graph(
  question="main orchestration entry point",
  mode="bfs",
  depth=2,
  token_budget=500
)
```
Expected result shape:
```
Top matches:
  - AgentOrchestrator  source_location: commands/orchestrate.md:1
    Edges: spawns→Riko, spawns→Senku, spawns→Loid, spawns→Lawliet, spawns→Alphonse
  - TeamOrchestrator   source_location: commands/team-orchestrate.md:1
    Edges: spawns→Riko, spawns→Senku (parallel)
```
How to use: The graph directly surfaces AgentOrchestrator at commands/orchestrate.md as the primary entry point. Report: "Main orchestration entry point: `commands/orchestrate.md` (AgentOrchestrator node, community 0). Team variant at `commands/team-orchestrate.md`."

**Follow-up** (if needed):
```
mcp__plugin_agent-flow_graphify__get_node(label="AgentOrchestrator")
```
Retrieve full source_location and edge list to confirm file path and summarize responsibilities.
