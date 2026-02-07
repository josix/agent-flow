# Skills Reference

Complete reference for the Agent Flow skill system, including skill specifications, ownership model, and extension patterns.

## Overview

Skills are domain expertise modules that provide behavioral patterns and best practices. Each skill has:

- **Owner Agent**: The agent responsible for maintaining and embodying the skill
- **Consumer Agents**: Agents that reference the skill for guidance
- **Reference Files**: Detailed documentation and examples

## Skill Registry

| Skill | Owner | Consumers | Purpose |
|-------|-------|-----------|---------|
| exploration-strategy | Riko | Senku, Loid | Codebase exploration patterns |
| task-classification | Senku | Riko, Orchestrator | Task routing decisions |
| prompt-refinement | Senku | Orchestrator | Ambiguous request handling |
| verification-gates | Alphonse | Loid, Lawliet | Quality validation patterns |
| agent-behavior-constraints | System | All | Universal behavioral rules |

## Ownership Model

```
                    ┌─────────────────────────────────────────────────────────┐
                    │              agent-behavior-constraints                 │
                    │                   (Owner: System)                       │
                    │              Consumed by: ALL AGENTS                    │
                    └─────────────────────────────────────────────────────────┘
                                              │
            ┌─────────────────────────────────┼─────────────────────────────────┐
            │                                 │                                 │
            ▼                                 ▼                                 ▼
┌───────────────────────┐       ┌───────────────────────┐       ┌───────────────────────┐
│        Riko           │       │        Senku          │       │       Alphonse        │
│   (Explorer Agent)    │       │   (Planner Agent)     │       │   (Verifier Agent)    │
├───────────────────────┤       ├───────────────────────┤       ├───────────────────────┤
│ OWNS:                 │       │ OWNS:                 │       │ OWNS:                 │
│ • exploration-strategy│       │ • task-classification │       │ • verification-gates  │
│                       │       │ • prompt-refinement   │       │                       │
└───────────────────────┘       └───────────────────────┘       └───────────────────────┘
```

### Ownership Principles

1. **Single Ownership**: Each skill has exactly one owner (or System for cross-cutting)
2. **Clear Boundaries**: Owners maintain the skill; consumers reference it
3. **Explicit Dependencies**: Relationships declared in frontmatter
4. **System Skills**: Apply universally, not agent-specific

## Skill Specifications

### exploration-strategy

**Owner**: Riko (Explorer Agent)
**Consumers**: Senku, Loid
**Location**: `skills/exploration-strategy/SKILL.md`

**Purpose**: Defines patterns for efficient codebase exploration.

**Key Concepts**:

| Pattern | When to Use | Approach |
|---------|-------------|----------|
| Breadth-First | Unfamiliar codebase | High-level structure first |
| Depth-First | Known target | Follow imports/references |
| Targeted | Specific patterns | Search then filter |

**Tool Selection Matrix**:

| Goal | Primary Tool |
|------|--------------|
| Find files by name | Glob |
| Find content in files | Grep |
| Read file contents | Read |
| External documentation | WebSearch |
| Fetch specific page | WebFetch |

**Convergence Criteria**:
- Results stabilize (same files found)
- Context sufficient for task
- Patterns identified
- Scope defined

**Reference Files**:
- `references/search-patterns.md` - Search pattern guidance
- `references/exploration-depth.md` - Depth by task type
- `references/deep-dive-patterns.md` - Parallel exploration
- `examples/exploration-scenarios.md` - Worked examples

---

### task-classification

**Owner**: Senku (Planner Agent)
**Consumers**: Riko, Orchestrator
**Location**: `skills/task-classification/SKILL.md`

**Purpose**: Routes tasks to appropriate agents based on complexity.

**Task Categories**:

| Category | Files | Risk | Primary Agent | Verification |
|----------|-------|------|---------------|--------------|
| Trivial | 0-1 | Low | Direct | None |
| Exploratory | N/A | Low | Riko | None |
| Implementation | 2-5 | Medium | Loid | Alphonse |
| Complex | 5+ | High | Full orchestration | Alphonse + Lawliet |
| Research | N/A | Low | Riko + WebSearch | None |

**Quick Classification**:

1. Is this read-only? -> Exploratory (Riko)
2. How many files? -> 0-1: Trivial, 2-5: Implementation, 5+: Complex
3. High-risk domain? -> Complex (override)

**Risk Amplifiers**:

| Domain | Risk Level | Reason |
|--------|------------|--------|
| Authentication | Critical | Security breach potential |
| Database schema | Critical | Data loss, migration complexity |
| API contracts | High | Breaking changes |
| Shared utilities | Medium | Wide blast radius |
| Payment/billing | Critical | Financial impact |

**Reference Files**:
- `references/agent-selection-matrix.md` - Detailed routing
- `references/classification-process.md` - Step-by-step
- `references/decision-flowchart.md` - Visual guides
- `examples/classification-examples.md` - Worked examples

---

### prompt-refinement

**Owner**: Senku (Planner Agent)
**Consumers**: Orchestrator
**Location**: `skills/prompt-refinement/SKILL.md`

**Purpose**: Handles ambiguous requests and ensures task clarity.

**Refinement Process**:

1. **Detect orchestration eligibility**: Is this a planning/implementation task?
2. **Check specificity**: Does request specify what, where, and why?
3. **If vague**: Ask ONE clarifying question with 2-4 options
4. **If clear**: Transform to structured format

**Structured Task Format**:
```markdown
**Goal**: One-sentence outcome

**Description**: What and why (2-3 sentences)

**Actions**: Concrete steps
```

**Ambiguity Indicators**:
- Missing component/file references
- Unclear scope ("make it better")
- Multiple interpretations possible
- No success criteria

**Reference Files**:
- `references/ambiguity-detection.md` - Detection patterns
- `references/clarification-strategies.md` - Questioning approaches
- `references/orchestration-detection.md` - Task type detection
- `examples/refinement-scenarios.md` - Worked examples

---

### verification-gates

**Owner**: Alphonse (Verifier Agent)
**Consumers**: Loid, Lawliet
**Location**: `skills/verification-gates/SKILL.md`

**Purpose**: Defines mandatory quality checkpoints.

**Gate Types**:

| Gate | Checks | Timeout |
|------|--------|---------|
| Pre-Commit | Lint, format, quick tests | 60s |
| Pre-Complete | Full tests, types, lint, build | 300s |
| Security | Credential scan, audit | 30s |

**Verification Commands by Language**:

| Language | Tests | Types | Lint | Build |
|----------|-------|-------|------|-------|
| Node.js | `npm test` | `npx tsc --noEmit` | `npm run lint` | `npm run build` |
| Python | `pytest` | `mypy .` | `ruff check .` | `python -m build` |
| Go | `go test ./...` | `go build` | `golangci-lint run` | `go build` |
| Rust | `cargo test` | `cargo check` | `cargo clippy` | `cargo build` |

**Failure Severity**:

| Type | Severity | Action |
|------|----------|--------|
| Test Failure | BLOCKING | Fix and re-run |
| Type Error | BLOCKING | Resolve types |
| Lint Error | BLOCKING | Auto-fix or manual |
| Build Failure | BLOCKING | Fix compilation |
| Security Alert | CRITICAL | Immediate remediation |

**Override Rules**:
- User explicitly requests skip (documented)
- No code changes made (docs only)
- Task is purely exploratory

**Reference Files**:
- `references/verification-commands.md` - Complete command reference
- `references/project-detection.md` - Project type detection
- `references/failure-handling.md` - Failure protocols
- `examples/verification-scenarios.md` - Worked examples

---

### agent-behavior-constraints

**Owner**: System
**Consumers**: All agents
**Location**: `skills/agent-behavior-constraints/SKILL.md`

**Purpose**: Universal behavioral rules for all agents.

**Model Routing**:

| Agent | Model | Rationale |
|-------|-------|-----------|
| Senku | Opus | Strategic planning needs deep reasoning |
| Riko | Opus | Complex exploration needs thorough analysis |
| Loid | Sonnet | Implementation benefits from speed |
| Lawliet | Sonnet | Review cycles need fast iteration |
| Alphonse | Sonnet | Verification is command-focused |

**Tool Access Matrix**:

| Tool | Riko | Senku | Loid | Lawliet | Alphonse |
|------|:----:|:-----:|:----:|:-------:|:--------:|
| Read | Yes | Yes | Yes | Yes | Yes |
| Grep | Yes | Yes | Yes | Yes | Yes |
| Glob | Yes | Yes | Yes | Yes | - |
| Write | - | - | Yes | - | - |
| Edit | - | - | Yes | - | - |
| Bash | * | - | Yes | ** | Yes |
| WebSearch | Yes | - | - | - | - |
| TodoWrite | - | Yes | - | - | - |

\* AST analysis only
\*\* Static analysis only

**Universal Non-Negotiables**:

1. Never speculate about unread code
2. Never suppress type errors
3. Prefer existing patterns
4. Avoid irreversible actions
5. Read before deciding
6. Ask one targeted question (if truly blocked)

**Reference Files**:
- `references/tool-access-details.md` - Complete permissions
- `references/model-selection-guide.md` - Selection criteria
- `references/mcp-tool-guide.md` - MCP preferences
- `examples/constraint-scenarios.md` - Worked examples

## Skill File Structure

```
skills/
├── skill-agent-mapping/
│   └── SKILL.md                     # Central registry
├── exploration-strategy/
│   ├── SKILL.md                     # Main documentation
│   ├── references/
│   │   ├── search-patterns.md
│   │   ├── exploration-depth.md
│   │   └── deep-dive-patterns.md
│   └── examples/
│       └── exploration-scenarios.md
├── task-classification/
│   ├── SKILL.md
│   ├── references/
│   │   ├── agent-selection-matrix.md
│   │   ├── classification-process.md
│   │   └── decision-flowchart.md
│   └── examples/
│       └── classification-examples.md
└── ...
```

## Creating New Skills

### Skill Template

```markdown
---
name: skill-name
description: When to use this skill
version: 1.0.0
owner_agent: AgentName
consumer_agents: [Agent1, Agent2]
---

# Skill Name

## Overview
[What this skill provides]

## Key Concepts
[Core patterns and practices]

## Quick Reference
[Lookup tables and decision trees]

## Resources
- [references/...](references/...) - Detailed docs
- [examples/...](examples/...) - Worked examples

## Related Skills
- [other-skill](../other-skill/SKILL.md) - How they relate
```

### Adding a Skill

1. Create skill directory: `skills/skill-name/`
2. Create main documentation: `skills/skill-name/SKILL.md`
3. Add references: `skills/skill-name/references/`
4. Add examples: `skills/skill-name/examples/`
5. Update registry: `skills/skill-agent-mapping/SKILL.md`
6. Update consuming agents to reference the skill

See [Adding Skills Guide](../guides/adding-skills.md) for detailed instructions.

## Consumption Guidelines

When an agent consumes a skill:

1. **Reference the skill** when making decisions in that domain
2. **Follow the patterns** defined in skill documentation
3. **Defer to the owner** for ambiguous interpretations
4. **Report conflicts** if skill guidance contradicts task requirements

## Related Documentation

- [Agents Reference](agents.md) - Agent specifications
- [Adding Skills Guide](../guides/adding-skills.md) - Extension instructions
- [Architecture Overview](../architecture/overview.md) - System design
