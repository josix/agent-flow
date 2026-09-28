# Context Preambles for Agent Dispatches

Loaded on demand by `/orchestrate`: for each integration marked `available: true` in `.claude/orchestration.local.md`, inject the matching preamble into Riko, Senku, and Lawliet dispatches.

## Graph-aware mode

If `.claude/orchestration.local.md` contains `graph: available: true`, inject a one-line graph preamble into every `Agent(...)` call for Riko, Senku, and Lawliet:

```
# Read current graph status
GRAPH_AVAILABLE=$(grep -A1 '^graph:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

When `GRAPH_AVAILABLE` is `true`, prepend to each agent prompt:

```
Knowledge graph available at graphify-out/graph.json. See the
graphify-usage skill for query patterns and tool selection.
```

Loid and Alphonse do NOT receive this preamble (they are write/verify-only).

## Personal KB-aware mode

If `.claude/orchestration.local.md` contains `personal_kb: available: true`, inject a one-line personal KB preamble into every `Agent(...)` call for Riko, Senku, and Lawliet:

```
# Read current personal KB status
PERSONAL_KB_AVAILABLE=$(grep -A1 '^personal_kb:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

When `PERSONAL_KB_AVAILABLE` is `true`, prepend to each agent prompt:

```
Personal knowledge base available via mcp__personal-kb__* tools. See the
personal-kb-usage skill for cross-project recall query patterns.
```

Loid and Alphonse do NOT receive this preamble (they are write/verify-only).

## AgentsView-aware mode

If `.claude/orchestration.local.md` contains `agentsview: available: true`, inject a one-line AgentsView preamble into every `Agent(...)` call for Riko, Senku, and Lawliet:

```
# Read current AgentsView status
AGENTSVIEW_AVAILABLE=$(grep -A1 '^agentsview:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

When `AGENTSVIEW_AVAILABLE` is `true`, prepend to each agent prompt:

```
Prior session history is searchable via mcp__plugin_agent-flow_agentsview__* tools.
Search past related sessions to leverage proven approaches and cross-verify current
handling against precedent. See the agentsview-usage skill for query patterns.
```

Loid and Alphonse do NOT receive this preamble (they are write/verify-only).
