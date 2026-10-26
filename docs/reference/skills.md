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
| exploration-strategy | Riko | Senku, Loid, Speedwagon | Codebase exploration patterns |
| task-classification | Senku | Riko, Orchestrator | Task routing decisions |
| prompt-refinement | Senku | Orchestrator | Ambiguous request handling |
| verification-gates | Alphonse | Loid, Lawliet | Quality validation patterns |
| agent-behavior-constraints | System | All | Universal behavioral rules |
| graphify-usage | Riko | Senku, Lawliet | Knowledge graph query patterns and tool decision table |
| personal-kb-usage | Riko | Senku, Lawliet | Cross-project personal knowledge base queries |
| agentsview-usage | Riko | Senku, Lawliet | Prior session-history search patterns |
| evidence-driven-work | System | Lawliet, Alphonse; Orchestrator (Phase 6) | Perception, evidence, argument and reporting practices |
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
│ •graphify-usage  │  │                  │  │              │  │ •exploration-    │  └──────────────────────────────┘
│ •personal-kb-    │  ├──────────────────┤  └──────────────┘  │  strategy        │
│  usage           │  │ CONSUMED BY:     │                     │ •explainer-      │
├──────────────────┤  │ •Riko, Orchestr. │                     │  design-system   │
│ CONSUMED BY:     │  │  (task-classif., │                     └──────────────────┘
│ •Senku, Loid     │  │   prompt-refine.)│
│  (exploration-   │  │                  │
│  strategy)       │  └──────────────────┘
│ •Senku, Lawliet  │
│  (graphify-usage,│
│  personal-kb-    │
│  usage,          │
│  agentsview-     │
│  usage)          │
└──────────────────┘
```

Not drawn above: the System skill `evidence-driven-work`. Lawliet and Alphonse preload it, the orchestrator reads its `references/expression.md` in Phase 6, Riko reaches `references/perception.md` through exploration-strategy, and it also auto-triggers in plain sessions.

### Ownership Principles

1. **Single Ownership**: Each skill has exactly one owner (or System for cross-cutting)
2. **Clear Boundaries**: Owners maintain the skill; consumers reference it
3. **Explicit Dependencies**: Relationships declared in frontmatter
4. **System Skills**: Apply universally, not agent-specific

## Skill Specifications

### exploration-strategy

**Owner**: Riko (Explorer Agent)
**Consumers**: Senku, Loid, Speedwagon
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

**Reference Files**: see `skills/exploration-strategy/references/` and `examples/`.

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
| Implementation | 2-5 | Medium | Loid | Lawliet + Alphonse |
| Complex | 5+ | High | Full orchestration | Lawliet + Alphonse (+ Codex) |
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

**Reference Files**: see `skills/task-classification/references/` and `examples/`.

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

**Reference Files**: see `skills/prompt-refinement/references/` and `examples/`.

---

### verification-gates

**Owner**: Alphonse (Verifier Agent)
**Consumers**: Loid, Lawliet
**Location**: `skills/verification-gates/SKILL.md`

**Purpose**: Defines mandatory quality checkpoints.

**Gate Types**:

| Gate | Checks | Timeout |
|------|--------|---------|
| Pre-Commit | Lint, format, quick tests | per check |
| Pre-Complete | Full tests, types, lint, build | per check |
| Security | Credential scan, audit | per check |

Per-check timeouts are in `skills/verification-gates/SKILL.md`.

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

**Reference Files**: see `skills/verification-gates/references/` and `examples/`.

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
| Riko | Sonnet | Exploration is breadth-first; speed over deep reasoning |
| Loid | Sonnet | Implementation benefits from speed |
| Lawliet | Sonnet | Review cycles need fast iteration |
| Alphonse | Sonnet | Verification is command-focused |
| Speedwagon | Sonnet | Fast content authoring for explainer modules |

**Tool Access Matrix**:

| Tool | Riko | Senku | Loid | Lawliet | Alphonse | Speedwagon |
|------|:----:|:-----:|:----:|:-------:|:--------:|:----------:|
| Read | Yes | Yes | Yes | Yes | Yes | Yes |
| Grep | Yes | Yes | Yes | Yes | Yes | Yes |
| Glob | Yes | Yes | Yes | Yes | - | Yes |
| Write | - | § | Yes | - | - | † |
| Edit | - | - | Yes | - | - | † |
| Bash | * | - | Yes | ** | Yes | ‡ |
| WebSearch | Yes | - | - | - | - | - |

\* AST analysis only
\*\* Static analysis only
§ Plan/report files only (`.claude/agent-reports/`, `.senku/`)
† `explain-out/` and `.claude/explain-briefs/` only
‡ `compile-explain.sh` only

**Universal Non-Negotiables**:

1. Never speculate about unread code
2. Never suppress type errors
3. Prefer existing patterns
4. Avoid irreversible actions
5. Read before deciding
6. Ask one targeted question (if truly blocked)

**Reference Files**: see `skills/agent-behavior-constraints/references/` and `examples/`.

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

**Reference Files**: see `skills/graphify-usage/references/` and `examples/`.

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

**Reference Files**: see `skills/personal-kb-usage/references/` and `examples/`.

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

**Reference Files**: see `skills/agentsview-usage/references/` and `examples/`.

---

### evidence-driven-work

**Owner**: System (cross-cutting)
**Consumers**: Lawliet, Alphonse (preloaded); Orchestrator (reads `references/expression.md` in Phase 6); Riko via exploration-strategy (`references/perception.md` on demand); also auto-triggers in plain sessions
**Location**: `skills/evidence-driven-work/SKILL.md`

**Purpose**: Ground claims in what the system actually did, and communicate them so a reader understands at a glance.

**Covers**:
- Perception: observation surfaces across domains (effective state, plans, metrics, history, API behind a UI) and recommending equivalent tools to the user
- Recovery from wrong hypotheses, change discipline, target-environment verification habits
- Evidence standards and argument structure
- Expression: outcome first, full narrative (background, change, purpose, impact), terms explained, clarity over decoration
- Defers to `exploration-strategy`, `verification-gates`, `agent-behavior-constraints` and `agentsview-usage`; inside `/orchestrate` the Phase 6 report follows its reporting shape while the Intent Ledger and completion promise remain required
- Running as a subagent: the role's verdict and gate lines stay unchanged and in place, blockers go in the report (escalation or verdict) rather than to the user, and delegation stays with the orchestrator

**Reference Files**: see `skills/evidence-driven-work/references/` and `examples/`.

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
| 11 lint rules | 8 enforced + 3 warning-only, run by `scripts/lib/explain-lint.py` on every compile: forbidden classes/JS/onclick, undefined classes/CSS vars, aria integrity, language allow-list, diagram-first, duplicate onclick; warnings for missing visual elements, overlong paragraphs and unfilled placeholders |
| English-panel scaffold | Every translator ships with `translator__tldr` (above), dual-pane block, and `translator__takeaway` (below) — none are optional |
| Design-skill protocol | Speedwagon reads this skill before rendering any HTML (see DESIGN SKILL block in `agents/Speedwagon.md`) |

**Reference Files**: see `skills/explainer-design-system/references/` (content philosophy, design system, interactive elements, gotchas).

## Skill File Structure

Each skill is a directory `skills/<name>/` with a `SKILL.md`, plus optional `references/` (branch-only detail read on demand) and `examples/`. `skills/skill-agent-mapping/SKILL.md` is the central registry.

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
