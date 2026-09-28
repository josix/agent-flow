---
name: agent-behavior-constraints
user-invocable: false
description: This skill should be used when handling agent model selection, tool access permissions, behavioral guardrails, MCP tool preferences, or any question about what agents can/cannot do.
---

# Agent Behavior Constraints

Define behavioral rules governing model selection, tool access, and operational guardrails.

## Overview

This skill consolidates four core constraint domains:

1. **Model Routing** - Which AI model powers each agent
2. **Tool Access** - What tools each agent can use
3. **Behavioral Guardrails** - Non-negotiable rules for all agents
4. **MCP Tool Preferences** - Domain-specific tool selection

Apply these constraints when spawning agents, checking permissions, or reviewing behavior.

---

## Model Routing

| Agent | Model | Rationale |
|-------|-------|-----------|
| Senku (Planner) | Opus | Strategic planning needs deep reasoning |
| Riko (Explorer) | Sonnet (effort: medium) | Exploration is breadth-first search; speed matters more than deep reasoning |
| Loid (Executor) | Sonnet | Balanced speed and capability for implementation |
| Lawliet (Reviewer) | Sonnet | Fast iteration for review feedback loops |
| Alphonse (Verifier) | Sonnet | Quick verification command execution |
| Speedwagon (Authoring) | Sonnet | Fast content authoring for explainer modules |

**Decision Rule:**
- Opus for strategic/planning tasks requiring deep reasoning (Senku, `effort: high`)
- Sonnet for exploration, execution, and verification tasks requiring speed

See [Model Selection Guide](references/model-selection-guide.md) for detailed criteria.

---

## Tool Access Matrix

```
Riko (Explorer):       [Read] [Grep] [Glob] [Bash]* [WebSearch] [WebFetch]
Senku (Planner):       [Read] [Grep] [Glob] [Write]§
Loid (Executor):       [Read] [Write] [Edit] [Bash] [Grep] [Glob]
Lawliet (Reviewer):    [Read] [Grep] [Glob] [Bash]
Alphonse (Verifier):   [Read] [Bash] [Grep]
Speedwagon (Authoring):[Read] [Grep] [Glob] [Write]† [Edit]† [Bash]‡
```

**Key Restrictions:**
- Only Loid can modify files (Write, Edit) — except Speedwagon's scoped authoring exception, Senku's plan/report files§, and Riko/Lawliet/Alphonse writing their own long reports to `.claude/agent-reports/` via Bash heredoc
- Only Riko can access web (WebSearch, WebFetch)
- Senku produces plans as numbered markdown checklists (TodoWrite no longer exists on current models)

**Footnotes:**
- § Senku's Write is scoped to plan/report files under `.claude/agent-reports/` or `.senku/` only — never source code
- * Riko's Bash access is limited to AST analysis tools only (ast-grep, tree-sitter, language parsers)
- † Speedwagon Write/Edit scoped to `explain-out/` and `.claude/explain-briefs/` only
- ‡ Speedwagon Bash limited to `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-explain.sh` only

See [Tool Access Details](references/tool-access-details.md) for per-agent breakdowns.

---

## External CLI dispatch — Codex co-review (Phase 4)

The orchestrator may invoke the OpenAI Codex CLI as an external Bash dispatch
during Phase 4 (Review) when `codex.available: true` in orchestration state.
This is the only sanctioned non-persona tool call from the orchestrator.

- Codex receives: task description and the `git diff` under review (or only
  the fix diff via `--diff-base <rev>` in review-fix rounds). It runs in
  parallel with Lawliet and Alphonse and does NOT receive Lawliet's findings —
  those are included only on a sequential re-check (e.g. a disputed finding).
  See `skills/verification-gates/references/codex-co-review.md` and
  `docs/guides/using-codex-review.md` for the data boundary.
- Codex runs in `-s read-only --ignore-user-config` sandbox.
- Verdict-merge rules (truth table + Divergence Cap):
  `skills/verification-gates/references/codex-co-review.md` (canonical).
- Per-run opt-out: `AGENT_FLOW_NO_CODEX=1` env var.

Personas (Riko/Senku/Loid/Lawliet/Alphonse) must NOT invoke `codex` directly.

---

## Behavioral Guardrails

### Universal Non-Negotiables

1. **Never speculate about unread code** - Read files before making assertions
2. **Never suppress type errors** - Fix root causes, not symptoms
3. **Prefer existing patterns** - Follow the codebase's established style
4. **Avoid irreversible actions** - Do not delete or force-push without confirmation
5. **Read before deciding** - Gather context when uncertain
6. **Ask one targeted question** - Only if truly blocked and cannot find answer in code

### Agent-Specific Rules

| Agent | Key Constraints |
|-------|-----------------|
| Riko | Read-only; summarize findings concisely |
| Senku | Create actionable plans; estimate complexity |
| Loid | Run targeted checks on changed code (Alphonse runs the full suite); follow the plan exactly |
| Lawliet | Cite specific code; distinguish blockers from suggestions; no file writes except its own report in `.claude/agent-reports/` |
| Alphonse | Run all verification commands (except type/lint in parallel mode — reported `COVERED (Lawliet)`); report exact output; no file writes except its own report in `.claude/agent-reports/` |
| Speedwagon | Write only to explain-out/ and .claude/explain-briefs/; Bash only for compile-explain.sh |

---

## MCP Tool Preferences

Prefer MCP tools over shell commands for domain operations.

| Domain | Preferred | Fallback |
|--------|-----------|----------|
| GitHub | `gh` CLI or MCP | API calls |
| Obsidian | MCP tools | File operations |
| Playwright | MCP tools | - |
| Database | MCP tools | Direct SQL |

See [MCP Tool Guide](references/mcp-tool-guide.md) for domain-specific guidance.

---

## Quick Reference

### Tool Access Check

| Tool | Riko | Senku | Loid | Lawliet | Alphonse | Speedwagon |
|------|:----:|:-----:|:----:|:-------:|:--------:|:----------:|
| Read | Yes | Yes | Yes | Yes | Yes | Yes |
| Grep | Yes | Yes | Yes | Yes | Yes | Yes |
| Glob | Yes | Yes | Yes | Yes | - | Yes |
| Write | - | Scoped§ | Yes | - | - | Scoped† |
| Edit | - | - | Yes | - | - | Scoped† |
| Bash | Yes* | - | Yes | Yes | Yes | Scoped‡ |
| WebSearch | Yes | - | - | - | - | - |

*Riko: Bash restricted to AST analysis tools only (ast-grep, tree-sitter, language parsers), plus writing its own report to `.claude/agent-reports/`
§Senku: Write restricted to plan/report files under `.claude/agent-reports/` or `.senku/`

### Violation Protocol

1. **Stop** - Halt forbidden operation
2. **Document** - Record what was blocked
3. **Delegate** - Hand off to appropriate agent
4. **Continue** - Proceed with permitted operations

---

## Resources

- [Tool Access Details](references/tool-access-details.md) - Complete permission matrices
- [Model Selection Guide](references/model-selection-guide.md) - Detailed selection criteria
- [MCP Tool Guide](references/mcp-tool-guide.md) - Domain tool preferences
- [Constraint Scenarios](examples/constraint-scenarios.md) - Worked examples

## Related Skills

- [task-classification](../task-classification/SKILL.md) - Uses constraints for agent assignment
- [verification-gates](../verification-gates/SKILL.md) - Defines Alphonse verification commands
- [exploration-strategy](../exploration-strategy/SKILL.md) - Guides Riko's exploration approach
