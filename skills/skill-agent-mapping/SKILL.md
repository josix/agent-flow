---
name: skill-agent-mapping
description: This skill should be used when looking up which agents own or consume specific skills, understanding skill-agent relationships, or routing tasks based on skill ownership.
---

# Skill-Agent Mapping

Central registry documenting the ownership and consumption relationships between skills and agents in the multi-agent orchestration system.

## Overview

Skills are domain expertise modules that define behavioral patterns and best practices. Each skill has:

- **Owner Agent**: The agent responsible for maintaining and embodying the skill
- **Consumer Agents**: Agents that reference the skill for guidance or constraints

## Quick Reference Table

| Skill | Owner | Consumers | Purpose |
|-------|-------|-----------|---------|
| exploration-strategy | Riko | Senku, Loid | Codebase exploration patterns |
| task-classification | Senku | Riko, Orchestrator | Task routing and complexity assessment |
| prompt-refinement | Senku | Orchestrator | Ambiguous request clarification |
| verification-gates | Alphonse | Loid, Lawliet | Quality validation checkpoints |
| team-decision | Senku | Orchestrator | Parallel vs sequential execution choice |
| agent-behavior-constraints | System | All | Universal behavioral guardrails |
| graphify-usage | Riko | Senku, Lawliet | Knowledge graph query patterns and interpretation |

## Visual Mapping

```
                    +----------------------------------------------------------+
                    |              agent-behavior-constraints                   |
                    |                   (Owner: System)                         |
                    |              Consumed by: ALL AGENTS                      |
                    +----------------------------------------------------------+
                                              |
            +---------------------------------+---------------------------------+
            |                                 |                                 |
            v                                 v                                 v
+-----------------------+       +-----------------------+       +-----------------------+
|        Riko           |       |        Senku          |       |       Alphonse        |
|   (Explorer Agent)    |       |   (Planner Agent)     |       |   (Verifier Agent)    |
+-----------------------+       +-----------------------+       +-----------------------+
| OWNS:                 |       | OWNS:                 |       | OWNS:                 |
| - exploration-strategy|       | - task-classification |       | - verification-gates  |
| - graphify-usage      |       | - prompt-refinement   |       |                       |
|                       |       | - team-decision       |       |                       |
+-----------------------+       +-----------------------+       +-----------------------+
| CONSUMES:             |       | CONSUMES:             |       | CONSUMES:             |
| - agent-behavior-     |       | - agent-behavior-     |       | - agent-behavior-     |
|   constraints         |       |   constraints         |       |   constraints         |
| - task-classification |       | - exploration-strategy|       |                       |
|                       |       | - graphify-usage      |       |                       |
+-----------------------+       +-----------------------+       +-----------------------+
            |                                 |                                 |
            |                                 |                                 |
            v                                 v                                 v
+-----------------------+       +-----------------------+       +-----------------------+
|        Loid           |       |       Lawliet         |       |     Orchestrator      |
|  (Executor Agent)     |       |  (Reviewer Agent)     |       |   (Coordination)      |
+-----------------------+       +-----------------------+       +-----------------------+
| OWNS: (none)          |       | OWNS: (none)          |       | OWNS: (none)          |
+-----------------------+       +-----------------------+       +-----------------------+
| CONSUMES:             |       | CONSUMES:             |       | CONSUMES:             |
| - agent-behavior-     |       | - agent-behavior-     |       | - task-classification |
|   constraints         |       |   constraints         |       | - prompt-refinement   |
| - verification-gates  |       | - verification-gates  |       | - team-decision       |
| - exploration-strategy|       | - graphify-usage      |       |                       |
+-----------------------+       +-----------------------+       +-----------------------+
```

## Skill Descriptions

### exploration-strategy

**Owner**: Riko (Explorer Agent)
**Consumers**: Senku, Loid
**Location**: `skills/exploration-strategy/SKILL.md`

Defines patterns for efficient codebase exploration including:
- Search tool selection (Glob, Grep, Read)
- Parallel search strategies
- Convergence criteria for stopping exploration
- Context gathering techniques

### task-classification

**Owner**: Senku (Planner Agent)
**Consumers**: Riko, Orchestrator
**Location**: `skills/task-classification/SKILL.md`

Provides guidance on:
- Task complexity assessment (Trivial, Exploratory, Implementation, Complex, Research)
- Agent routing decisions
- Verification requirement determination
- Risk amplifier identification

### prompt-refinement

**Owner**: Senku (Planner Agent)
**Consumers**: Orchestrator
**Location**: `skills/prompt-refinement/SKILL.md`

Handles:
- Ambiguity detection in user requests
- Clarification question strategies
- Structured task specification templates
- Orchestration eligibility detection

### verification-gates

**Owner**: Alphonse (Verifier Agent)
**Consumers**: Loid, Lawliet
**Location**: `skills/verification-gates/SKILL.md`

Defines:
- Pre-commit and pre-complete gate types
- Verification commands by language/framework
- Failure handling protocols
- Override rules and documentation requirements

### team-decision

**Owner**: Senku (Planner Agent)
**Consumers**: Orchestrator
**Location**: `skills/team-decision/SKILL.md`

Provides guidance on:
- Parallel vs sequential execution decisions
- Task independence and parallelism safety analysis
- File ownership rules for conflict avoidance
- Cost-benefit analysis for team spawning
- Team size and coordination guidelines

### agent-behavior-constraints

**Owner**: System
**Consumers**: All agents
**Location**: `skills/agent-behavior-constraints/SKILL.md`

Establishes:
- Model routing rules (Opus vs Sonnet)
- Tool access permissions per agent
- Universal behavioral guardrails
- MCP tool preferences

### graphify-usage

**Owner**: Riko (Explorer Agent)
**Consumers**: Senku, Lawliet
**Location**: `skills/graphify-usage/SKILL.md`

Covers:
- When to query the knowledge graph vs. use Grep/Read
- Tool selection decision table (query_graph, get_node, get_neighbors, get_community, god_nodes, graph_stats, shortest_path)
- Token hygiene rules (top_k/top_n limits, no raw JSON downstream, source_location citations)
- Result interpretation including confidence tags (EXTRACTED/INFERRED/AMBIGUOUS) and staleness discipline
- Standard query patterns (orientation, blast-radius, boundary verification)

## Ownership Principles

1. **Single Ownership**: Each skill has exactly one owner agent (or System for cross-cutting concerns)
2. **Clear Boundaries**: Owners maintain and evolve the skill; consumers reference but don't modify
3. **Explicit Dependencies**: Consumer relationships are declared in both skill and agent frontmatter
4. **System Skills**: Skills owned by "System" apply universally and are not agent-specific

## Consumption Guidelines

When an agent consumes a skill:

1. **Reference the skill** when making decisions in the skill's domain
2. **Follow the patterns** defined in the skill documentation
3. **Defer to the owner** for ambiguous interpretations
4. **Report conflicts** if skill guidance contradicts task requirements

## Related Files

- [Agent Definitions](../agents/) - Agent .md files with skill references
- [Skill Directories](.) - Individual skill documentation
- [README](../README.md) - Plugin overview and architecture
