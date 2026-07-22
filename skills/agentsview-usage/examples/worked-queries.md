# Worked Query Examples — AgentsView

End-to-end scenarios showing question → tool call → result shape → how to use.

---

## Scenario 1 — Riko finds a prior approach before exploring a new task

**Context**: Riko is asked to explore adding a new MCP integration to agent-flow. Before diving into the codebase cold, Riko checks whether a similar integration was built before.

**Question**: "Has a similar MCP integration been added to this project before?"

**Tool sequence**:

**Step 1**: Search for prior sessions on this project mentioning MCP integration work.
```
mcp__plugin_agent-flow_agentsview__search_sessions(
  project="agent-flow",
  limit=10
)
```
Expected result shape:
```
Sessions:
  - id: 7f3a...  started: 2026-06-02  first_message: "add graphify as a built-in MCP integration"
  - id: c91d...  started: 2026-05-18  first_message: "wire personal-kb MCP server into orchestration"
```
How to use: Both sessions look like precedent for "add a new MCP integration" work.

**Step 2**: Pull an overview of the closest match.
```
mcp__plugin_agent-flow_agentsview__get_session_overview(id="7f3a...")
```
Expected result shape:
```
id: 7f3a...
outcome: success
message_count: 42
health_grade: A
summary signals: detector script + guard wrapper + .mcp.json registration + skill + docs
```

**Handoff summary** to Senku: "Session 7f3a... (2026-06-02) added the graphify MCP integration using a detector script + guard wrapper + .mcp.json entry + skill + docs pattern. Outcome: success, health grade A. Recommend following the same structure for this task."

---

## Scenario 2 — Senku reuses a past plan structure

**Context**: Senku is planning the same MCP-integration task and wants to confirm the file layout used last time before drafting today's plan.

**Question**: "What files did the prior graphify MCP integration touch, in what order?"

**Tool sequence**:

**Step 1**: Get the session overview (already known from Riko's handoff) to confirm scope.
```
mcp__plugin_agent-flow_agentsview__get_session_overview(id="7f3a...")
```

**Step 2**: Read a narrow window of messages around the implementation-planning portion of that session.
```
mcp__plugin_agent-flow_agentsview__get_messages(
  id="7f3a...",
  around=12,
  before=3,
  after=5,
  limit=10
)
```
Expected result shape:
```
[12] assistant: "Plan: detect-graphify-context.sh (new) -> start-graphify-mcp.sh (new) -> .mcp.json entry -> init-orchestration.sh wiring -> commands/orchestrate.md preamble -> agents frontmatter -> skill -> docs -> mkdocs nav"
```

**Planning note**: "Precedent (session 7f3a...) used the sequence: detector script -> guard wrapper -> .mcp.json -> init wiring -> command preambles -> agent frontmatter -> skill -> docs -> mkdocs nav. Adopting the same group ordering (A-F) for this plan, since the current task is structurally analogous. Current requirements differ in tool list (5 tools, not 7) and exclusion of get_usage_summary — noting deviation explicitly rather than copying verbatim."

---

## Scenario 3 — Lawliet cross-verifies a change against precedent

**Context**: Lawliet is reviewing Loid's implementation of the new detector script and wants to check whether it follows the same graceful-degradation pattern used for the Codex detector previously.

**Question**: "Was a similar 'exit 0 on missing binary' pattern used and reviewed favorably before?"

**Tool sequence**:

**Step 1**: Full-text search for the graceful-degradation pattern across prior sessions.
```
mcp__plugin_agent-flow_agentsview__search_content(
  pattern="graceful degrade exit 0",
  limit=10,
  context=3
)
```
Expected result shape:
```
Matches:
  - session: a12b...  snippet: "...Graceful degrade — MCP server simply unavailable, not 'failed'; stderr messages remain for diagnostics..."
  - session: 7f3a...  snippet: "...detect-codex-context.sh: each branch exits 0, no set -e trap failures allowed..."
```

**Step 2**: Confirm the outcome of the session that established the pattern.
```
mcp__plugin_agent-flow_agentsview__get_session_overview(id="7f3a...")
```
Expected result shape:
```
id: 7f3a...
outcome: success
health_grade: A
```

**Review comment**: "Precedent (session 7f3a..., outcome: success) established the graceful-degradation contract: every detector/guard-wrapper branch exits 0, with diagnostics on stderr only. Current diff's `detect-agentsview-context.sh` and `start-agentsview-mcp.sh` follow the same contract (verified independently by reading the current files, not just the precedent). No conflict found between precedent and current requirements — approving on this point."
