# Worked Query Examples — Personal KB

End-to-end scenarios showing question → tool call → result shape → how to use.

All `source_location` values below are ABSOLUTE paths because the personal KB lives outside the current project root.

---

## Scenario 1 — Riko finding prior auth decisions before exploring a new task

**Context**: Riko is asked to explore a new authentication-related task. Before grepping the current project, Riko checks the personal KB for prior experience.

**Question**: "Has the user documented any decisions or patterns around authentication before?"

**Tool sequence**:

**Step 1**: Broad recall on "authentication".
```
mcp__personal-kb__query_graph(
  question="authentication patterns decisions",
  mode="bfs",
  depth=2,
  token_budget=500
)
```
Expected result shape:
```
Top matches:
  - JWTDecision2024   source_location: /Users/you/kb/decisions/auth-jwt.md:1
    Edges: relates_to→SessionVsToken (EXTRACTED), supersedes→OldCookieAuth (EXTRACTED)
  - OAuthPattern      source_location: /Users/you/kb/patterns/oauth-flow.md:1
    Edges: references→JWTDecision2024 (EXTRACTED)
```
How to use: The user has prior JWT and OAuth decisions. Note absolute paths for downstream reference.

**Step 2**: Get full details on the most relevant node.
```
mcp__personal-kb__get_node(label="JWTDecision2024")
```
Expected result shape:
```
label: JWTDecision2024
source_location: /Users/you/kb/decisions/auth-jwt.md:1
community_id: 2
edges: [relates_to→SessionVsToken, supersedes→OldCookieAuth, ...]
```

**Handoff summary** to Senku: "Personal KB contains prior JWT auth decision at `/Users/you/kb/decisions/auth-jwt.md`. User previously chose JWT over cookies (OldCookieAuth superseded). OAuth pattern also documented at `/Users/you/kb/patterns/oauth-flow.md`. Recommend Senku incorporate these priors into planning."

---

## Scenario 2 — Senku pulling cross-project design decisions into planning

**Context**: Senku is planning an implementation for a caching layer. Senku queries the personal KB to see if the user has documented caching approaches from past projects.

**Question**: "What caching patterns or decisions has the user documented?"

**Tool sequence**:

**Step 1**: Query for caching-related personal knowledge.
```
mcp__personal-kb__query_graph(
  question="caching patterns performance",
  mode="bfs",
  depth=2,
  token_budget=800
)
```
Expected result shape:
```
Top matches:
  - RedisVsMemcached   source_location: /Users/you/kb/decisions/caching-2023.md:5
    Edges: relates_to→PerformanceNotes (EXTRACTED), decided_by→ProjectAlpha (INFERRED)
  - CachingGotchas     source_location: /Users/you/kb/anti-patterns/caching.md:1
```

**Step 2**: Check neighbors of the gotchas node.
```
mcp__personal-kb__get_neighbors(label="CachingGotchas")
```
Expected result shape:
```
Outbound:
  - CachingGotchas --[warns_about]--> StaleReadProblem  (EXTRACTED)
  - CachingGotchas --[warns_about]--> CacheStampede     (EXTRACTED)
```
How to use: User has documented stale read and cache stampede as personal anti-patterns. Senku should flag these risks in the implementation plan.

**Planning note**: "Per personal KB: user chose Redis over Memcached in 2023 (see `/Users/you/kb/decisions/caching-2023.md`). Two documented caching anti-patterns: stale reads and cache stampede (see `/Users/you/kb/anti-patterns/caching.md`). Plan must address both."

---

## Scenario 3 — Lawliet comparing current code to personal anti-patterns

**Context**: Lawliet is reviewing a PR that adds error handling. Lawliet queries the personal KB to check for personally documented error handling anti-patterns.

**Question**: "Has the user documented any error handling anti-patterns or style preferences?"

**Tool sequence**:

**Step 1**: Query for error handling in personal KB.
```
mcp__personal-kb__query_graph(
  question="error handling anti-patterns exceptions",
  mode="bfs",
  depth=2,
  token_budget=500
)
```
Expected result shape:
```
Top matches:
  - SilentCatchAntiPattern   source_location: /Users/you/kb/anti-patterns/errors.md:12
    Edges: warns_about→DataLoss (EXTRACTED)
  - ErrorLogStyle            source_location: /Users/you/kb/preferences/logging.md:1
```

**Step 2**: Get full details on the style preference node.
```
mcp__personal-kb__get_node(label="ErrorLogStyle")
```
Expected result shape:
```
label: ErrorLogStyle
source_location: /Users/you/kb/preferences/logging.md:1
community_id: 1
summary: "Always include stack trace and context object. Never log raw error.message alone."
```

**Review comment**: "Personal KB flags silent catch as anti-pattern (see `/Users/you/kb/anti-patterns/errors.md:12`). Also documents personal preference: always log stack trace + context, not just error.message (see `/Users/you/kb/preferences/logging.md:1`). Current PR catches `err` but only logs `err.message`. Recommend adding stack trace and context to match personal style preference."

---

## Scenario 4 — Riko answering "what is my most central personal topic?"

**Context**: At the start of a new project exploration, Riko wants to orient the team on what cross-project context the user brings.

**Question**: "What are the dominant concepts in the user's personal knowledge base?"

**Tool sequence**:

**Single call**:
```
mcp__personal-kb__god_nodes(top_n=10)
```
Expected result shape:
```
1. SoftwareArchDecisions   degree=47  community=0  source_location: /Users/you/kb/arch/index.md:1
2. SecurityPatterns        degree=38  community=1  source_location: /Users/you/kb/security/index.md:1
3. TestingPhilosophy       degree=31  community=2  source_location: /Users/you/kb/testing/philosophy.md:1
...
```
How to use: Top concepts reveal what the user has thought most deeply about across projects. Riko can summarize: "User's personal KB is centered on architecture decisions, security patterns, and testing philosophy — all relevant to this project."

**Follow-up** (if needed):
```
mcp__personal-kb__get_community(community_id=0)
```
Retrieves all nodes in the architecture decisions community for a richer picture of the user's prior architectural thinking.
