---
name: task-classification
description: This skill should be used when classifying tasks, routing to agents, determining complexity, or handling task routing, agent selection, verification requirements, and multi-component changes.
---

# Task Classification

## Overview

Task classification is the foundational skill that enables intelligent routing of user requests to the appropriate agent(s) within the multi-agent orchestration system. This skill analyzes incoming tasks to determine:

- **Complexity Level**: How many files, components, or systems are affected
- **Risk Assessment**: Potential for introducing bugs, regressions, or breaking changes
- **Agent Assignment**: Which specialized agent(s) should handle the task
- **Verification Requirements**: Whether automated testing and review are needed

### When to Use This Skill

Apply task classification when:
- A new user request arrives that requires action
- The scope of work is unclear or potentially complex
- Multiple approaches could solve the same problem
- Determining if verification gates are required
- Delegating work to specialized agents

### Key Principles

1. **Err on the side of caution**: When uncertain, classify higher rather than lower
2. **Consider hidden complexity**: Database migrations, API changes, and authentication have amplified risk
3. **Account for dependencies**: Changes that affect shared code require broader verification
4. **Respect the verification mandate**: Implementation and Complex tasks always require verification

---

## Task Categories

Tasks are classified into five primary categories:

| Category | Files | Risk | Primary Agent | Verification |
|----------|-------|------|---------------|--------------|
| Trivial | 0-1 | Low | Direct | None |
| Exploratory | N/A | Low | Riko | None |
| Implementation | 2-5 | Medium | Loid | Alphonse |
| Complex | 5+ | High | Full orchestration | Alphonse + Lawliet |
| Research | N/A | Low | Riko + WebSearch | None |

### Trivial Tasks

Simple, low-risk tasks handled directly without agent delegation.

**Examples**: Answering code questions, single-line fixes, documentation comments

**Indicators**: "what", "why", "how" questions; localized changes; no logic changes

### Exploratory Tasks

Read-only investigation focused on understanding code or gathering information.

**Examples**: Finding usages, tracing data flow, understanding architecture

**Agent**: Riko (Explorer) with Grep, Glob, Read tools

### Implementation Tasks

Standard development tasks involving code changes across a moderate number of files.

**Examples**: New API endpoints, feature flags, bug fixes, refactoring functions

**Agents**: Loid (Executor) -> Alphonse (Verifier)

### Complex Tasks

High-impact changes affecting multiple components, requiring full orchestration.

**Examples**: Major refactoring, security changes, database migrations, cross-service features

**Agents**: Riko -> Senku -> Loid -> Alphonse + Lawliet

### Research Tasks

Information-gathering requiring external research or documentation lookup.

**Examples**: Best practices research, library evaluation, documentation lookup

**Agent**: Riko (Explorer) with WebSearch

---

## Agent Quick Reference

| Agent | Role | Model | Key Tools |
|-------|------|-------|-----------|
| Riko | Explorer | Opus | Read, Grep, Glob, Bash*, WebSearch, WebFetch |
| Senku | Planner | Opus | Read, Grep, Glob, TodoWrite |
| Loid | Executor | Sonnet | Read, Write, Edit, Grep, Glob, Bash |
| Lawliet | Reviewer | Sonnet | Read, Grep, Glob, Bash |
| Alphonse | Verifier | Sonnet | Bash, Read, Grep |

* Riko's Bash access is limited to AST analysis tools only (ast-grep, tree-sitter, language parsers)

For detailed agent routing, see [references/agent-selection-matrix.md](references/agent-selection-matrix.md).

---

## Quick Classification Process

### Three-Question Decision

1. **Is this read-only?** -> Yes: Exploratory (Riko)
2. **How many files?** -> 0-1: Trivial, 2-5: Implementation, 5+: Complex
3. **High-risk domain?** -> Yes: Complex (regardless of file count)

### Override Conditions

These conditions force Complex classification:

- Security-sensitive changes (authentication, authorization, encryption)
- Database migrations or schema changes
- Changes to payment or billing systems
- Multi-service coordination required
- Breaking API changes

For detailed classification steps, see [references/classification-process.md](references/classification-process.md).

---

## Risk Amplifiers

| Domain | Risk Increase | Reason |
|--------|---------------|--------|
| Authentication | Critical | Security breach potential |
| Database schema | Critical | Data loss, migration complexity |
| API contracts | High | Breaking changes for consumers |
| Shared utilities | Medium | Wide blast radius |
| Payment/billing | Critical | Financial impact |
| Configuration | Medium | Runtime behavior changes |

---

## Verification Requirements

| Task Type | Type Check | Lint | Unit Tests | Integration | Review |
|-----------|------------|------|------------|-------------|--------|
| Trivial | - | - | - | - | - |
| Exploratory | - | - | - | - | - |
| Implementation | Required | Required | Required | Optional | Optional |
| Complex | Required | Required | Required | Required | Required |
| Research | - | - | - | - | - |

---

## Keyword Indicators

| Keywords | Likely Classification |
|----------|----------------------|
| "what", "why", "how", "explain" | Trivial or Exploratory |
| "find", "search", "where", "trace" | Exploratory |
| "fix", "update", "add", "change" | Implementation |
| "refactor", "redesign", "migrate" | Complex |
| "research", "best practices", "compare" | Research |
| "all", "every", "entire", "across" | Complex (scope indicator) |

---

## Additional Resources

### Reference Files

- [references/agent-selection-matrix.md](references/agent-selection-matrix.md) - Detailed agent routing tables
- [references/classification-process.md](references/classification-process.md) - Step-by-step classification
- [references/decision-flowchart.md](references/decision-flowchart.md) - Visual decision guides
- [references/classification-best-practices.md](references/classification-best-practices.md) - Best practices and pitfalls
- [references/classification-heuristics.md](references/classification-heuristics.md) - Edge case handling
- [references/deep-dive-synthesis.md](references/deep-dive-synthesis.md) - Synthesis for /deep-dive command

### Examples

- [examples/classification-examples.md](examples/classification-examples.md) - Worked classification examples

### Related Skills

- **agent-behavior-constraints**: Model routing, tool access, and behavioral guardrails
- **verification-gates**: Verification requirements and pass criteria
