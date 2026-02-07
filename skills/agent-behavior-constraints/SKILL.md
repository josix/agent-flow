---
name: agent-behavior-constraints
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
| Riko (Explorer) | Opus | Complex exploration needs thorough analysis |
| Loid (Executor) | Sonnet | Balanced speed and capability for implementation |
| Lawliet (Reviewer) | Sonnet | Fast iteration for review feedback loops |
| Alphonse (Verifier) | Sonnet | Quick verification command execution |

**Decision Rule:**
- Opus for strategic/planning tasks requiring deep reasoning
- Sonnet for execution/verification tasks requiring speed

See [Model Selection Guide](references/model-selection-guide.md) for detailed criteria.

---

## Tool Access Matrix

```
Riko (Explorer):     [Read] [Grep] [Glob] [Bash]* [WebSearch] [WebFetch]
Senku (Planner):     [Read] [Grep] [Glob] [TodoWrite]
Loid (Executor):     [Read] [Write] [Edit] [Bash] [Grep] [Glob]
Lawliet (Reviewer):  [Read] [Grep] [Glob] [Bash]
Alphonse (Verifier): [Read] [Bash] [Grep]
```

**Key Restrictions:**
- Only Loid can modify files (Write, Edit)
- Only Riko can access web (WebSearch, WebFetch)
- Only Senku can manage tasks (TodoWrite)

**Footnote:**
- * Riko's Bash access is limited to AST analysis tools only (ast-grep, tree-sitter, language parsers)

See [Tool Access Details](references/tool-access-details.md) for per-agent breakdowns.

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
| Loid | Run tests after changes; follow the plan exactly |
| Lawliet | Cite specific code; distinguish blockers from suggestions |
| Alphonse | Run all verification commands; report exact output |

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

| Tool | Riko | Senku | Loid | Lawliet | Alphonse |
|------|:----:|:-----:|:----:|:-------:|:--------:|
| Read | Yes | Yes | Yes | Yes | Yes |
| Grep | Yes | Yes | Yes | Yes | Yes |
| Glob | Yes | Yes | Yes | Yes | - |
| Write | - | - | Yes | - | - |
| Edit | - | - | Yes | - | - |
| Bash | Yes* | - | Yes | Yes | Yes |
| WebSearch | Yes | - | - | - | - |
| TodoWrite | - | Yes | - | - | - |

*Riko: Bash restricted to AST analysis tools only (ast-grep, tree-sitter, language parsers)

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
