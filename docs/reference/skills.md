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
| team-decision | Senku | Orchestrator | Parallel vs sequential execution choice |
| graphify-usage | Riko | Senku, Lawliet | Knowledge graph query patterns and tool decision table |
| personal-kb-usage | Riko | Senku, Lawliet | Cross-project personal knowledge base queries |
| agentsview-usage | Riko | Senku, Lawliet | Prior session-history search patterns |
| explainer-design-system | Vendored (upstream: zarazhangrui) | Speedwagon | Interactive HTML explainer design system (primitives, lint rules, design tokens, content philosophy) |
| skill-agent-mapping | System | All | Central registry of skill ownership and consumption relationships between skills and agents |

## Ownership Model

```
                    ┌─────────────────────────────────────────────────────────┐
                    │              agent-behavior-constraints                 │
                    │                   (Owner: System)                       │
                    │              Consumed by: ALL AGENTS                    │
                    └─────────────────────────────────────────────────────────┘
                                              │
   ┌──────────────────────┬───────────────────┼─────────────────┬─────────────────────┐
   │                      │                   │                 │                     │
   ▼                      ▼                   ▼                 ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────────────────┐
│      Riko        │  │      Senku       │  │   Alphonse   │  │   Speedwagon     │  │  Upstream (zarazhangrui)     │
│  (Explorer)      │  │  (Planner)       │  │  (Verifier)  │  │  (Authoring)     │  │  (Vendored)                  │
├──────────────────┤  ├──────────────────┤  ├──────────────┤  ├──────────────────┤  ├──────────────────────────────┤
│ OWNS:            │  │ OWNS:            │  │ OWNS:        │  │ CONSUMES:        │  │ OWNS:                        │
│ •exploration-    │  │ •task-classif.   │  │ •verification│  │ •agent-behavior- │  │ •explainer-design-system     │
│  strategy        │  │ •prompt-refine.  │  │  gates       │  │  constraints     │  │  (consumed by Speedwagon)    │
│ •agentsview-usage│  │                  │  │              │  │                  │  │                              │
│ •graphify-usage  │  │ •team-decision   │  │              │  │ •exploration-    │  └──────────────────────────────┘
│ •personal-kb-    │  ├──────────────────┤  └──────────────┘  │  strategy        │
│  usage           │  │ CONSUMED BY:     │                     │ •explainer-      │
├──────────────────┤  │ •Riko, Orchestr. │                     │  design-system   │
│ CONSUMED BY:     │  │  (task-classif., │                     └──────────────────┘
│ •Senku, Loid     │  │   prompt-refine.,│
│  (exploration-   │  │   team-decision) │
│  strategy)       │  └──────────────────┘
│ •Senku, Lawliet  │
│  (graphify-usage,│
│  personal-kb-    │
│  usage,          │
│  agentsview-     │
│  usage)          │
└──────────────────┘
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

---

### team-decision

**Owner**: Senku (Planner Agent)
**Consumers**: Orchestrator
**Location**: `skills/team-decision/SKILL.md`

**Purpose**: Determines whether to use parallel or sequential execution for review and verification phases.

**Decision Factors**:

| Factor | Parallel | Sequential |
|--------|----------|------------|
| Agent Teams availability | Required | N/A |
| Task complexity | Medium-High | Low |
| Time sensitivity | High | Low |
| Resource availability | Sufficient | Limited |

**Execution Modes**:

1. **Parallel (Team Mode)**:
   - Review (Lawliet) and Verification (Alphonse) run concurrently
   - Reduces wall-clock time by 30-40%
   - Requires Agent Teams feature
   - Results merged after both complete

2. **Sequential (Fallback)**:
   - Review runs first, then verification
   - Lower resource usage
   - Works without Agent Teams
   - Traditional waterfall approach

**Reference Files**:
- `references/parallel-safety.md` - Safety considerations for parallel execution
- `references/decision-criteria.md` - Detailed decision criteria
- `examples/team-decision-scenarios.md` - Worked examples

---

### graphify-usage

**Owner**: Riko (Explorer Agent)
**Consumers**: Senku, Lawliet
**Location**: `skills/graphify-usage/SKILL.md`

**Purpose**: Governs when and how to query the graphify knowledge graph for structural codebase information.

**Tool Decision Table**:

| Question type | Primary tool | Follow-up |
|---------------|--------------|-----------|
| How large is this codebase? | `graph_stats` | `god_nodes` for core abstractions |
| What are the central concepts? | `god_nodes` | `get_community` to explore clusters |
| Which modules are in the same cluster? | `get_community` | `get_node` on members |
| What does this node connect to? | `get_neighbors` | `get_node` on callers/callees |
| Blast radius of changing X | `get_neighbors` then `shortest_path` | Manual review of connected files |
| Path between two concepts | `shortest_path` | `get_node` on intermediate nodes |
| Specific node details | `get_node` | — |

**Graph vs. Grep Boundary**:

| Condition | Use |
|-----------|-----|
| Dependency mapping, call graph, blast radius | Graph tools |
| Literal text match, freshly edited file | Grep / Read |
| Graph absent (`graphify-out/graph.json` missing) | Grep / Read only |

**Token Hygiene**:
- Always set `top_k` / `top_n` when available
- Set `token_budget` on `query_graph` (default 2000; use 500 for orientation)
- Do not paste raw graph JSON into prompts or summaries
- Summarize results as `label → source_location` bullets before handing off

**Reference Files**:
- `references/tool-reference.md` - Full MCP tool signatures
- `references/query-patterns.md` - Decision sequences
- `examples/worked-queries.md` - End-to-end query scenarios

---

### personal-kb-usage

**Owner**: Riko (Explorer Agent)
**Consumers**: Senku, Lawliet
**Location**: `skills/personal-kb-usage/SKILL.md`

**Purpose**: Governs when and how to query the user's personal knowledge base graph for cross-project prior decisions, patterns, and learnings.

**When to Query**:

| Trigger condition | Approach |
|-------------------|----------|
| "Have I solved this problem before?" | Personal KB: `query_graph` |
| "What did I decide about X in past projects?" | Personal KB: `query_graph` |
| "What are my recurring patterns across codebases?" | Personal KB: `god_nodes` |
| Dependency structure of THIS project | Project graph (`graphify-usage`) |
| Personal KB not configured (`available: false`) | Skip — use project graph or Grep |

**Key Distinctions**:
- `graphify-usage` queries the **current project's** graph (relative path `graphify-out/graph.json`)
- `personal-kb-usage` queries the **user's personal** graph at `$AGENT_FLOW_PERSONAL_KB_PATH` (absolute path, outside project)
- Personal KB is prior experience; project docs take precedence for current requirements

**Token Hygiene**: Same rules as `graphify-usage` — set `top_k`, set `token_budget`, no raw JSON downstream, summarize with absolute `source_location` paths.

**Reference Files**:
- `references/tool-reference.md` - Full MCP tool signatures
- `references/query-patterns.md` - Decision sequences
- `examples/worked-queries.md` - End-to-end query scenarios

---

### agentsview-usage

**Owner**: Riko (Explorer Agent)
**Consumers**: Senku, Lawliet
**Location**: `skills/agentsview-usage/SKILL.md`

**Purpose**: Governs when and how to search prior AI coding agent session history (via the `agentsview` MCP server) to leverage proven past approaches and cross-verify current handling against precedent.

**Covers**:
- Riko searches prior related sessions during exploration to surface how similar work was handled before
- Senku leverages proven past approaches when designing an implementation plan
- Lawliet cross-verifies current handling against precedent found in earlier sessions
- Loid and Alphonse are intentionally excluded — session-history recall is out of scope for write/verify agents
- All five granted tools are accessed via the `mcp__plugin_agent-flow_agentsview__*` prefix (`search_sessions`, `list_sessions`, `get_session_overview`, `get_messages`, `search_content`); `get_usage_summary` is intentionally not granted
- Degrades gracefully when `agentsview: available: false` in state (binary not installed, or opted out via `AGENT_FLOW_NO_AGENTSVIEW=1`)

**Reference Files**:
- `references/tool-reference.md` - Full MCP tool signatures
- `references/query-patterns.md` - Decision sequences
- `examples/worked-queries.md` - End-to-end query scenarios

---

### explainer-design-system

**Owner**: Vendored from upstream (`zarazhangrui/codebase-to-course`)
**Consumers**: Speedwagon (Authoring Agent)
**Location**: `skills/explainer-design-system/SKILL.md`

**Purpose**: Provides the interactive HTML explainer design system that Speedwagon uses when authoring explainer modules. Defines teaching primitives, content philosophy, design tokens, interactive-element HTML patterns, and a lint-rule reference. Adapted from `zarazhangrui/codebase-to-course` (full credit to the original author) and vendored as `explainer-design-system` to reflect its role as a design-system reference inside the `/explain` single-module pipeline.

**Key Concepts**:

| Concept | Description |
|---------|-------------|
| 12 teaching primitives | Class vocabulary (`translator`, `quiz-container`, `callout`, `step-cards`, `badge`, `mermaid`, etc.) fully defined in `templates/explain/styles.css` |
| 8 lint rules | Enforced by `scripts/lib/explain-lint.py` on every compile: forbidden classes, inline handlers, undefined classes/vars, aria integrity, language allow-list, diagram-first, no onclick |
| English-panel scaffold | Every translator ships with `translator__tldr` (above), dual-pane block, and `translator__takeaway` (below) — none are optional |
| Design-skill protocol | Speedwagon reads this skill before rendering any HTML (see DESIGN SKILL block in `agents/Speedwagon.md`) |

**Reference Files**:

- `skills/explainer-design-system/SKILL.md` — adapter note and full upstream content
- `skills/explainer-design-system/references/content-philosophy.md` — metaphor rules, tone, quiz and tooltip design
- `skills/explainer-design-system/references/design-system.md` — warm palette, typography, spacing tokens
- `skills/explainer-design-system/references/interactive-elements.md` — HTML patterns for translator blocks, chat animations, flow animations, quizzes, callouts, glossary tooltips
- `skills/explainer-design-system/references/gotchas.md` — checklist Speedwagon runs before declaring a fragment done

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
├── team-decision/
│   ├── SKILL.md
│   ├── references/
│   │   ├── parallel-safety.md
│   │   └── decision-criteria.md
│   └── examples/
│       └── team-decision-scenarios.md
└── ...
```

## Creating New Skills

### Skill Template

```markdown
---
name: skill-name
description: When to use this skill
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
