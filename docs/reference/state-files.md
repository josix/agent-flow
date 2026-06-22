# State Files Reference

Complete reference for Agent Flow state files, including formats, fields, and management.

## Overview

Agent Flow uses state files to track workflow progress across sessions. These files are stored in the `.claude/` directory and use YAML frontmatter with Markdown content.

| File | Command | Purpose | Scope |
|------|---------|---------|-------|
| `orchestration.local.md` | /orchestrate | Phase and gate tracking | Session |
| `team-orchestration.local.md` | /team-orchestrate | Team phase and parallel group tracking | Session |
| `deep-dive.local.md` | /deep-dive | Codebase context | Session |
| `research-*.local.md` | /orchestrate (research short-circuit) | Investigation/plan report | Durable artifact |

## orchestration.local.md

Tracks progress through the orchestration workflow.

### Format

```yaml
---
active: true
current_phase: "exploration"
iteration: 1
max_iterations: 10
started_at: "2024-01-15T10:30:00Z"
task: "Add user authentication with JWT tokens"
# task_complexity = task-classification tier (NOT complexipy code/cognitive complexity)
task_complexity: "unclassified"
report_requested: false
intent:
  goal: ""
  description: ""
  actions: ""
  constraints: ""
  assumptions: ""
deep_dive:
  available: true
  using: false
  scope: "full"
  generated: "2024-01-14T15:00:00Z"
graph:
  available: true
  path: "graphify-out/graph.json"
  generated: "2024-01-14T12:00:00Z"
  nodes: 1626
  edges: 2346
  communities: 135
gates:
  exploration:
    status: "passed"
    timestamp: "2024-01-15T10:31:00Z"
    agent: "Riko"
    message: "Exploration complete"
  planning:
    status: "passed"
    timestamp: "2024-01-15T10:35:00Z"
    agent: "Senku"
    message: "Plan created with 5 steps"
  implementation:
    status: "in_progress"
    timestamp: "2024-01-15T10:40:00Z"
    agent: "Loid"
  review:
    status: "pending"
  verification:
    status: "pending"
---

## Orchestration Log

### Session Started
- Task: "Add user authentication with JWT tokens"
- Max Iterations: 10
- Started: 2024-01-15T10:30:00Z
- Deep-Dive Context: Available but not requested (use --use-deep-dive)

---

### Phase: Exploration
- Agent: Riko
- Status: PASSED
- Timestamp: 2024-01-15T10:31:00Z
- Message: Exploration complete

### Phase: Planning
- Agent: Senku
- Status: PASSED
- Timestamp: 2024-01-15T10:35:00Z
- Message: Plan created with 5 steps

### Phase: Implementation
- Agent: Loid
- Status: IN PROGRESS
- Started: 2024-01-15T10:40:00Z
```

### Field Reference

#### Root Fields

| Field | Type | Description |
|-------|------|-------------|
| `active` | boolean | Whether orchestration is in progress |
| `current_phase` | string | Current workflow phase |
| `iteration` | integer | Current iteration number |
| `max_iterations` | integer | Maximum allowed iterations |
| `started_at` | ISO 8601 | Session start timestamp |
| `task` | string | Task description |
| `task_complexity` | string | Task-classification tier (`trivial`/`exploratory`/`implementation`/`complex`/`research`); starts as `"unclassified"`. This is the **task-routing tier**, distinct from complexipy's code cognitive-complexity check used by Lawliet. |
| `report_requested` | boolean | Set to `true` during Phase 0 Prompt Refinement when the user explicitly asked for a written report, investigation guide, or planning document (e.g., "write me a report"). Defaults to `false`. Read by the Research Short-Circuit: the short-circuit activates when `task_complexity` is `research` or `exploratory` **OR** when this flag is `true`. Legacy files missing this key are migrated-on-write (idempotent). |
| `intent` | object | Structured intent captured during Phase 0. Fields: `goal`, `description`, `actions`, `constraints`, `assumptions` (all strings). Legacy files missing these keys are migrated-on-write per-field (idempotent). |

#### Phase Values

| Phase | Description |
|-------|-------------|
| `exploration` | Riko gathering context |
| `planning` | Senku creating strategy |
| `implementation` | Loid writing code |
| `review` | Lawliet checking quality |
| `verification` | Alphonse running tests |
| `complete` | All gates passed |

#### deep_dive Object

| Field | Type | Description |
|-------|------|-------------|
| `available` | boolean | Whether deep-dive context exists |
| `using` | boolean | Whether context is being used |
| `scope` | string | Deep-dive scope (full/focused) |
| `generated` | ISO 8601 | When context was generated |

#### graph Object

Written by `scripts/detect-graph-context.sh` during init. Present in both `orchestration.local.md` and `team-orchestration.local.md`. Signals graphify-backed knowledge graph availability so the orchestrator knows whether to inject MCP query hints into subagent prompts.

| Field | Type | Description |
|-------|------|-------------|
| `available` | boolean | Whether `graphify-out/graph.json` exists |
| `path` | string | Relative path to the graph file (empty if unavailable) |
| `generated` | ISO 8601 | When the graph was last built (empty if unavailable) |
| `nodes` | integer | Node count from `manifest.json` (0 if unavailable) |
| `edges` | integer | Edge count (0 if unavailable) |
| `communities` | integer | Detected community count (0 if unavailable) |

When `available: false`, the orchestrator skips graph-aware mode and falls back to `Grep`/`Read` for all subagent queries. See [Using Graphify](../guides/using-graphify.md) for usage.

#### personal_kb Object

Written by `scripts/detect-personal-kb.sh` during init. Present in both `orchestration.local.md` and `team-orchestration.local.md`. Signals the user's personal knowledge base availability so the orchestrator knows whether to inject cross-project recall hints into subagent prompts.

Example when available:
```yaml
personal_kb:
  available: true
  path: "/Users/you/personal/knowledge-base"
  graph_path: "/Users/you/personal/knowledge-base/graphify-out/graph.json"
  generated: "2026-04-13T22:15:00Z"
  nodes: 342
  edges: 891
  communities: 27
```

Example when unavailable:
```yaml
personal_kb:
  available: false
  path: ""
  graph_path: ""
  generated: ""
  nodes: 0
  edges: 0
  communities: 0
```

| Field | Type | Description |
|-------|------|-------------|
| `available` | boolean | Whether personal KB is configured and `graph.json` exists |
| `path` | string | Absolute path to personal KB root (value of `AGENT_FLOW_PERSONAL_KB_PATH`, expanded; empty if unavailable) |
| `graph_path` | string | Absolute path to `graphify-out/graph.json` within personal KB (empty if unavailable) |
| `generated` | ISO 8601 | When the personal KB graph was last built (empty if unavailable) |
| `nodes` | integer | Node count from personal KB graph (0 if unavailable) |
| `edges` | integer | Edge count (0 if unavailable) |
| `communities` | integer | Detected community count (0 if unavailable) |

Note: unlike the `graph:` block which uses a relative `path`, `personal_kb:` uses **absolute paths** because the personal KB lives outside `CLAUDE_PROJECT_DIR`.

When `available: false`, the orchestrator skips personal-KB-aware mode. Set `AGENT_FLOW_PERSONAL_KB_PATH` in your shell profile and ensure `graphify-out/graph.json` exists at that path. See [Using Personal KB](../guides/using-personal-kb.md) for setup.

#### codex Object

Written by `scripts/detect-codex-context.sh` during init. Present in both `orchestration.local.md` and `team-orchestration.local.md`. Tells the orchestrator whether Codex co-review is available for this session.

```yaml
codex:
  available: true              # true only when binary found AND auth_present AND AGENT_FLOW_NO_CODEX != 1
  binary: "/usr/local/bin/codex"  # absolute path when codex is on PATH; empty string only when not found
  auth_present: true           # true when auth.json or session.json exists under ${CODEX_HOME:-$HOME/.codex}
```

`available` can be `false` for three independent reasons:

- Binary not on PATH — `binary` will be empty string.
- No auth credential file (`auth.json` or `session.json`) under `${CODEX_HOME:-$HOME/.codex}` — `auth_present: false`, but `binary` is still populated.
- `AGENT_FLOW_NO_CODEX=1` is set at Claude Code startup. On this path,
  `binary` reflects whatever `command -v codex` finds (may be populated),
  but `auth_present` is always emitted as `false` regardless of actual
  credential file presence.

When `available: false`, Phase 4 falls back to Lawliet-only review.

#### Gate Object

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Gate status |
| `timestamp` | ISO 8601 | Last update time |
| `agent` | string | Agent that processed gate |
| `message` | string | Status message |

#### Gate Status Values

| Status | Description |
|--------|-------------|
| `pending` | Not yet started |
| `in_progress` | Currently executing |
| `passed` | Gate passed successfully |
| `failed` | Gate failed, needs retry |

### Initialization

Created by `scripts/init-orchestration.sh`:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-orchestration.sh "Add user authentication"

# With deep-dive context
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-orchestration.sh --use-deep-dive "Add feature"

# With custom max iterations
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-orchestration.sh --max-iterations 20 "Complex task"
```

### Updates

Updated by `scripts/update-orchestration-state.sh`:

```bash
# Update phase and gate
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase planning \
  --gate-result passed \
  --agent Riko \
  --message "Exploration complete"

# Persist structured intent (Phase 0)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --set-task-complexity "complex" \
  --set-intent-goal "Add OAuth2 login with Google provider" \
  --set-intent-description "Integrate Google OAuth2 for user login" \
  --set-intent-actions "1. Add config 2. Create handler 3. Add routes" \
  --set-intent-constraints "Must not break existing session handling" \
  --set-intent-assumptions "Google OAuth credentials already provisioned"

# Mark complete
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --complete \
  --agent Orchestrator \
  --message "All phases completed successfully"
```

#### New flags (v1.5.0)

| Flag | Description |
|------|-------------|
| `--set-task-complexity <tier>` | Set the task-classification tier (stored lowercase) |
| `--set-intent-goal <text>` | Set `intent.goal` |
| `--set-intent-description <text>` | Set `intent.description` |
| `--set-intent-actions <text>` | Set `intent.actions` |
| `--set-intent-constraints <text>` | Set `intent.constraints` |
| `--set-intent-assumptions <text>` | Set `intent.assumptions` |

#### New flags (v1.7.0)

| Flag | Description |
|------|-------------|
| `--set-report-requested <true\|false>` | Set the `report_requested` flag. Pass `true` when the user explicitly requested a written report/investigation guide/planning document during Phase 0 Prompt Refinement. Only `true` or `false` are accepted; any other value exits non-zero. |

### Monitoring

```bash
# View current state
head -30 .claude/orchestration.local.md

# Check current phase
grep '^current_phase:' .claude/orchestration.local.md

# Check iteration
grep '^iteration:' .claude/orchestration.local.md

# Check deep-dive status
grep 'deep_dive:' -A4 .claude/orchestration.local.md
```

---

## team-orchestration.local.md

Tracks progress through the team orchestration workflow with parallel group support.

### Format

```yaml
---
active: true
current_phase: "review_verification"
iteration: 1
max_iterations: 10
started_at: "2024-01-15T10:30:00Z"
task: "Add user authentication with JWT tokens"
# task_complexity = task-classification tier (NOT complexipy code/cognitive complexity)
task_complexity: "unclassified"
intent:
  goal: ""
  description: ""
  actions: ""
  constraints: ""
  assumptions: ""
mode: "team"
team_available: true
deep_dive:
  available: true
  using: false
  scope: "full"
  generated: "2024-01-14T15:00:00Z"
graph:
  available: true
  path: "graphify-out/graph.json"
  generated: "2024-01-14T12:00:00Z"
  nodes: 1626
  edges: 2346
  communities: 135
personal_kb:
  available: false
  path: ""
  graph_path: ""
  generated: ""
  nodes: 0
  edges: 0
  communities: 0
parallel_groups:
  review_verification:
    status: "in_progress"
    started_at: "2024-01-15T10:45:00Z"
    completed_at: ""
    review:
      status: "passed"
      agent: "Lawliet"
      timestamp: "2024-01-15T10:46:30Z"
      result: "APPROVED"
    verification:
      status: "in_progress"
      agent: "Alphonse"
      timestamp: "2024-01-15T10:45:15Z"
      result: ""
gates:
  exploration:
    status: "passed"
    timestamp: "2024-01-15T10:31:00Z"
  planning:
    status: "passed"
    timestamp: "2024-01-15T10:35:00Z"
  implementation:
    status: "passed"
    timestamp: "2024-01-15T10:44:00Z"
  review_verification:
    status: "in_progress"
    timestamp: "2024-01-15T10:45:00Z"
  review:
    status: "passed"
    timestamp: "2024-01-15T10:46:30Z"
  verification:
    status: "in_progress"
    timestamp: "2024-01-15T10:45:15Z"
---

## Team Orchestration Log

### Session Started
- Task: "Add user authentication with JWT tokens"
- Max Iterations: 10
- Mode: team
- Team Available: true
- Started: 2024-01-15T10:30:00Z
- Deep-Dive Context: Available but not requested

---

### Phase: Exploration
- Agent: Riko
- Status: PASSED
- Timestamp: 2024-01-15T10:31:00Z

### Phase: Planning
- Agent: Senku
- Status: PASSED
- Timestamp: 2024-01-15T10:35:00Z

### Phase: Implementation
- Agent: Loid
- Status: PASSED
- Timestamp: 2024-01-15T10:44:00Z

### Phase: Review & Verification (PARALLEL)
- Started: 2024-01-15T10:45:00Z
- Mode: team

#### Review (Lawliet)
- Status: PASSED
- Timestamp: 2024-01-15T10:46:30Z
- Result: APPROVED

#### Verification (Alphonse)
- Status: IN PROGRESS
- Started: 2024-01-15T10:45:15Z
```

### Field Reference

#### Root Fields

Extends `orchestration.local.md` with team-specific fields:

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | Execution mode (team or sequential) |
| `team_available` | boolean | Whether Agent Teams feature is available |
| `parallel_groups` | object | Parallel group tracking |

All other root fields are identical to `orchestration.local.md`.

#### Mode Values

| Mode | Description |
|------|-------------|
| `team` | Agent Teams enabled, parallel execution for review+verification |
| `sequential` | Fallback mode, all phases run sequentially |

#### parallel_groups Object

Tracks parallel execution groups. Currently, only `review_verification` group is used:

```yaml
parallel_groups:
  review_verification:
    status: "pending|in_progress|passed|failed"
    started_at: "ISO 8601 timestamp"
    completed_at: "ISO 8601 timestamp"
    review:
      status: "pending|in_progress|passed|failed"
      agent: "Lawliet"
      timestamp: "ISO 8601 timestamp"
      result: "APPROVED|NEEDS_CHANGES|error details"
    verification:
      status: "pending|in_progress|passed|failed"
      agent: "Alphonse"
      timestamp: "ISO 8601 timestamp"
      result: "VERIFIED|FAILED|error details"
```

#### Parallel Group Status Values

| Status | Description |
|--------|-------------|
| `pending` | Not started, waiting for implementation |
| `in_progress` | Teammates active, tasks running |
| `passed` | All sub-phases passed successfully |
| `failed` | One or more sub-phases failed |

#### Sub-Phase Fields

Each sub-phase (review, verification) has:

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Sub-phase status |
| `agent` | string | Agent responsible for this sub-phase |
| `timestamp` | ISO 8601 | Last update time |
| `result` | string | Sub-phase outcome (varies by type) |

#### Phase Values

Extends standard phases with parallel phase:

| Phase | Description |
|-------|-------------|
| `exploration` | Riko gathering context |
| `planning` | Senku creating strategy |
| `implementation` | Loid writing code |
| `review_verification` | Parallel review + verification (team mode) |
| `review` | Sequential review (sequential mode) |
| `verification` | Sequential verification (sequential mode) |
| `complete` | All gates passed |

### Initialization

Created by `scripts/init-team-orchestration.sh`:

```bash
# Standard initialization
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-team-orchestration.sh "Add user authentication"

# With deep-dive context
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-team-orchestration.sh --use-deep-dive "Add feature"

# Force sequential mode
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-team-orchestration.sh --force-sequential "Complex task"

# Combine flags
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-team-orchestration.sh \
  --use-deep-dive --max-iterations 20 "Large refactoring"
```

### Updates

Updated by `scripts/update-team-state.sh`:

```bash
# Update phase and gate
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --phase planning \
  --gate-result passed \
  --agent Riko \
  --message "Exploration complete"

# Persist structured intent (Phase 0)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --set-task-complexity "complex" \
  --set-intent-goal "Add OAuth2 login with Google provider" \
  --set-intent-description "Integrate Google OAuth2 for user login" \
  --set-intent-actions "1. Add config 2. Create handler 3. Add routes" \
  --set-intent-constraints "Must not break existing session handling" \
  --set-intent-assumptions "Google OAuth credentials already provisioned"

# Update parallel group status
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --parallel-group review_verification \
  --gate-result in_progress \
  --message "Starting parallel review and verification"

# Update teammate sub-phase
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --parallel-group review_verification \
  --teammate review \
  --gate-result passed \
  --agent Lawliet \
  --message "Code review passed"

# Mark complete
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --complete \
  --agent Orchestrator \
  --message "All phases completed successfully"
```

#### New flags (v1.5.0)

| Flag | Description |
|------|-------------|
| `--set-task-complexity <tier>` | Set the task-classification tier (stored lowercase) |
| `--set-intent-goal <text>` | Set `intent.goal` |
| `--set-intent-description <text>` | Set `intent.description` |
| `--set-intent-actions <text>` | Set `intent.actions` |
| `--set-intent-constraints <text>` | Set `intent.constraints` |
| `--set-intent-assumptions <text>` | Set `intent.assumptions` |

### Monitoring

```bash
# View current state
head -50 .claude/team-orchestration.local.md

# Check mode
grep '^mode:' .claude/team-orchestration.local.md

# Check current phase
grep '^current_phase:' .claude/team-orchestration.local.md

# Check parallel group status
grep 'parallel_groups:' -A15 .claude/team-orchestration.local.md

# Check specific sub-phase
grep -A4 'review:' .claude/team-orchestration.local.md
grep -A4 'verification:' .claude/team-orchestration.local.md
```

### State Transitions

#### Team Mode

```
Phase 1-3: Sequential (exploration -> planning -> implementation)
    |
    v
Phase 4+5: Parallel Group "review_verification"
    |
    +-- review: pending -> in_progress -> passed/failed
    |
    +-- verification: pending -> in_progress -> passed/failed
    |
    v
All sub-phases complete -> review_verification: passed/failed
    |
    v
Phase 6: complete (if passed) OR back to implementation (if failed)
```

#### Sequential Mode

```
Phase 1-5: All sequential (exploration -> planning -> implementation -> review -> verification)
    |
    v
Phase 6: complete
```

---

## deep-dive.local.md

Stores comprehensive codebase context from deep-dive exploration.

### Format

```yaml
---
generated: "2024-01-15T10:00:00Z"
scope: "full"
focus_path: null
expires_hint: "refresh when codebase significantly changes"
phase: "complete"
agent_count: 5
phases:
  parallel_exploration:
    status: "complete"
    agents_spawned: 5
    agents_completed: 5
  synthesis:
    status: "complete"
  compilation:
    status: "complete"
---

# Deep-Dive Context

## Repository Overview
- **Tech stack**: TypeScript, React, Node.js, PostgreSQL
- **Entry points**: src/index.ts, src/server.ts, src/cli.ts
- **Key patterns**: Repository pattern, Dependency injection, Event sourcing

## Architecture Map

| Component | Location | Purpose |
|-----------|----------|---------|
| API Layer | src/api/ | REST endpoints and middleware |
| Services | src/services/ | Business logic and orchestration |
| Repositories | src/repositories/ | Data access abstraction |
| Models | src/models/ | Domain entities and types |
| Utils | src/utils/ | Shared utilities |
| Config | src/config/ | Configuration management |

## Conventions

### Naming
- Files: kebab-case (`user-service.ts`)
- Classes: PascalCase (`UserService`)
- Functions: camelCase (`getUserById`)
- Constants: SCREAMING_SNAKE_CASE (`MAX_RETRY_COUNT`)

### Testing
- Framework: Jest
- Location: `__tests__/` directories
- Naming: `*.test.ts` or `*.spec.ts`
- Mocks: `__mocks__/` directories

### Error Handling
- Custom `AppError` class for domain errors
- Error codes in `src/constants/error-codes.ts`
- Centralized error middleware

## Anti-Patterns (DO NOT)

- Do not use `any` type - use proper typing or `unknown`
- Do not import from `src/internal/` - internal modules are private
- Do not modify global state - use dependency injection
- Do not catch errors without logging - always log context
- Do not use synchronous file operations - use async/await

## Key Files Quick Reference

| Task | Look Here |
|------|-----------|
| Add API endpoint | src/api/routes/ |
| Add database model | src/models/ + src/repositories/ |
| Add service | src/services/ |
| Add middleware | src/api/middleware/ |
| Add CLI command | src/cli/commands/ |
| Add configuration | src/config/ |
| Add utility | src/utils/ |

## Agent Notes

### Authentication
- JWT-based authentication with refresh tokens
- Tokens stored in HTTP-only cookies
- Auth middleware in `src/api/middleware/auth.ts`

### Database
- PostgreSQL with Prisma ORM
- Migrations in `prisma/migrations/`
- Schema in `prisma/schema.prisma`

### Testing Requirements
- Tests require running database (use docker-compose)
- Environment: `NODE_ENV=test`
- Config: `jest.config.js`

### Build and Deploy
- Build: `npm run build` -> `dist/`
- Lint: `npm run lint`
- Type check: `npm run typecheck`
- CI: GitHub Actions (`.github/workflows/`)
```

### Field Reference

#### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `generated` | ISO 8601 | When context was generated |
| `scope` | string | Exploration scope |
| `focus_path` | string/null | Focus path if scoped |
| `expires_hint` | string | When to refresh |
| `phase` | string | Generation phase |
| `agent_count` | integer | Number of parallel agents |
| `phases` | object | Phase tracking |

#### phases Object

| Field | Type | Description |
|-------|------|-------------|
| `parallel_exploration` | object | Parallel exploration phase tracking |
| `parallel_exploration.status` | string | Phase status (pending/in_progress/complete) |
| `parallel_exploration.agents_spawned` | integer | Number of agents spawned |
| `parallel_exploration.agents_completed` | integer | Number of agents completed |
| `synthesis` | object | Synthesis phase tracking |
| `synthesis.status` | string | Phase status (pending/in_progress/complete) |
| `compilation` | object | Compilation phase tracking |
| `compilation.status` | string | Phase status (pending/in_progress/complete) |

#### Scope Values

| Scope | Description |
|-------|-------------|
| `full` | Entire codebase explored |
| `focused` | Specific path explored |

#### Phase Values

| Phase | Description |
|-------|-------------|
| `exploring` | Parallel exploration in progress |
| `synthesizing` | Senku merging findings |
| `complete` | Context ready for use |

### Content Sections

| Section | Purpose |
|---------|---------|
| Repository Overview | Tech stack, entry points, key patterns |
| Architecture Map | Component locations and purposes |
| Conventions | Naming, testing, error handling |
| Anti-Patterns | What NOT to do |
| Quick Reference | Task-to-location mapping |
| Agent Notes | Additional context for agents |

### Initialization

Created by `scripts/init-deep-dive.sh`:

```bash
# Full exploration
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-deep-dive.sh --scope full

# Focused exploration
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-deep-dive.sh --scope focused --focus-path src/auth

# Refresh existing
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-deep-dive.sh --refresh
```

### Compilation

Compiled by `scripts/compile-deep-dive.sh`:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-deep-dive.sh \
  --tech-stack "TypeScript, React" \
  --entry-points "src/index.ts" \
  --key-patterns "Repository pattern" \
  --overview "..." \
  --architecture "..." \
  --conventions "..." \
  --antipatterns "..." \
  --quick-reference "..." \
  --agent-notes "..." \
  --mark-complete
```

### Monitoring

```bash
# View context header
head -30 .claude/deep-dive.local.md

# Check generation phase
grep '^phase:' .claude/deep-dive.local.md

# Check scope
grep '^scope:' .claude/deep-dive.local.md
```

---

---

## research-*.local.md

Stores a durable investigation or planning report produced by the `/orchestrate` research short-circuit. Unlike session state files, this artifact is intended to persist beyond a single session so the user can keep and reference it.

### Naming

Files are named with a goal-derived slug and a UTC timestamp:

```
.claude/research-<slug>-<stamp>.local.md
```

- `<slug>` — lowercase, non-alphanumeric characters replaced with `-`, collapsed repeats trimmed, truncated to ~40 characters; falls back to `report` if the slug would be empty.
- `<stamp>` — `YYYYMMDDTHHMMSSz` (e.g. `20240115T103000Z`).

Multiple reports can accumulate under `.claude/` — no auto-cleanup occurs. The most recent report can be found with:

```bash
ls -t .claude/research-*.local.md | head -1
```

### Format

```yaml
---
generated: "20240115T103000Z"
goal: "investigate why auth tokens expire early"
scope: "research"
report_path: ".claude/research-investigate-why-auth-tokens-expire-ear-20240115T103000Z.local.md"
status: "complete"
phases:
  exploration: complete
  synthesis: complete
---

# Research Report

> Generated: 20240115T103000Z
> Updated: 2024-01-15T10:45:00Z
> Goal: investigate why auth tokens expire early
> Scope: research

## Summary
Root cause identified: server clock skew of ~3 minutes vs token issuer.

## Findings
...

## Plan / Recommendations
...

## Open Questions
...

## Sources & Evidence
...
```

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `generated` | string | Stamp when the report was initialized (`YYYYMMDDTHHMMSSz`) |
| `goal` | string | The investigation goal (YAML-escaped) |
| `scope` | string | `research` or `exploratory` |
| `report_path` | string | Self-referential path for tooling |
| `status` | string | `initializing` → `synthesis` → `complete` |
| `phases.exploration` | string | `pending` → `complete` |
| `phases.synthesis` | string | `pending` → `in_progress` → `complete` |

### Body Sections

| Section | Purpose |
|---------|---------|
| `## Summary` | One-paragraph overview of findings |
| `## Findings` | Detailed evidence and analysis |
| `## Plan / Recommendations` | Action items; rendered `_N/A — exploratory_` when scope=exploratory and no plan was produced |
| `## Open Questions` | Unresolved questions for follow-up |
| `## Sources & Evidence` | Files read, URLs, EXPLAIN output, etc. |

All sections are stubbed `_pending..._` on init and rewritten by `compile-research-report.sh`.

### Structural Completeness (--mark-complete)

When `--mark-complete` is passed to `compile-research-report.sh`:

- **Summary** must be non-empty and non-stub (required for all scopes).
- **Findings** must be non-empty and non-stub (required for all scopes).
- **Plan / Recommendations** must be non-empty for `scope=research`; for `scope=exploratory` an empty/stub plan is accepted and rendered as `_N/A — exploratory_`.

Exit 1 with a clear message if a required section is missing.

### Initialization

```bash
REPORT_PATH=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-research-report.sh \
  --goal "investigate why auth tokens expire early" \
  --scope research)
```

The last stdout line is `REPORT_PATH` so the orchestrator can capture it.

### Compilation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-research-report.sh \
  --report-path "$REPORT_PATH" \
  --summary "Root cause identified: clock skew" \
  --findings "..." \
  --plan "..." \
  --open-questions "..." \
  --sources "..." \
  --mark-complete
```

### Accumulation Behavior

Multiple research reports can exist simultaneously under `.claude/`. Each has a unique timestamp, so runs never overwrite each other. There is no auto-cleanup; delete old reports manually if needed.

### Git Ignore Coverage

Research reports are covered by the `.claude/*.local.*` pattern in the agent-flow managed `.gitignore` block. See the [Generated artifacts & .gitignore](#generated-artifacts--gitignore) section below for the full managed block and opt-out instructions.

---

## Generated artifacts & .gitignore

When agent-flow commands run in a user project, they automatically inject a managed block into that project's `.gitignore` so generated intermediate data is never accidentally committed. This is handled by `scripts/ensure-gitignore.sh`, which is called by `init-orchestration.sh`, `init-team-orchestration.sh`, `init-deep-dive.sh`, `compile-explain.sh`, `start-graphify-mcp.sh`, and `analyze.sh`.

### Managed block

The injected block is bounded by exact marker lines:

```
# >>> agent-flow managed (do not edit) >>>
# Generated by agent-flow commands (orchestrate / deep-dive / explain / graphify).
# Remove this whole block to opt out, or set AGENT_FLOW_NO_GITIGNORE=1.
.claude/*.local.*
.claude/codex/
.claude/explain-briefs/
.claude/observability/
graphify-out/
explain-out/
# <<< agent-flow managed <<<
```

The six patterns cover:
- `.claude/*.local.*` — session state files (orchestration, deep-dive, team-orchestration)
- `.claude/codex/` — Codex co-review working files
- `.claude/explain-briefs/` — per-module explain briefs and fragments
- `.claude/observability/` — SQLite event store and reports
- `graphify-out/` — knowledge graph build output
- `explain-out/` — compiled explainer HTML output

### Behavior

- **Idempotent**: running the same command twice produces identical file content; no duplicate blocks are added.
- **Non-destructive**: content outside the managed block is never removed or reordered.
- **Malformed-safe**: if only one marker is present (truncated file), the file is left unchanged and a fresh block is appended.
- **New file**: if `.gitignore` does not exist it is created containing only the managed block.

### Opt-out

Set `AGENT_FLOW_NO_GITIGNORE=1` in the environment before running any agent-flow command and the script exits without touching `.gitignore`.

Alternatively, delete the entire managed block (from the start marker through the end marker inclusive) to opt out permanently for that project.

### Agent-flow repo self-skip

If `.claude-plugin/plugin.json` exists in the project and its `name` field equals `"agent-flow"`, the script exits immediately without modifying `.gitignore`. This prevents the plugin from modifying its own development repository.

---

## Observability Files

The observability layer writes several files under `.claude/observability/`. All paths are gitignored.

### `.claude/observability/events.db`

Primary SQLite WAL store. The database is opened in WAL mode so live-hook writes during a session do not block concurrent reads. The store is append-only by convention — the `retention` subcommand is the only supported deletion mechanism.

See [Observability Schema](observability-schema.md) for the full table and view reference.

### `.claude/observability/events.jsonl`

Fallback sink. When the database is locked (e.g. a long-running query holds a read lock), hook events are appended here as newline-delimited JSON. The next successful `load` run ingests and merges these lines into the database.

### `.claude/observability/report.md`

The latest all-sessions report produced by `bash scripts/analyze.sh report`. Overwritten on each run.

### `.claude/observability/<session_id>.md`

Per-session report produced by `bash scripts/analyze.sh report --session <id>`.

### `.claude/observability/export.jsonl`

Output of the JSONL exporter (`bash scripts/analyze.sh export`). Overwritten on each run.

### `.claude/observability/labels-export.csv`

CSV output of `bash scripts/analyze.sh label export`. Columns: `label_id`, `session_id`, `agent_type`, `verdict`, `note`, `ts`.

### `.claude/observability.json`

Exporter configuration file. JSON format (not TOML — chosen for Python 3.9 stdlib compatibility).

**Schema:**

```json
{
  "exporters": [
    { "type": "jsonl" },
    {
      "type": "mlflow",
      "tracking_uri": "http://localhost:5000",
      "experiment": "agent-flow"
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `exporters` | Array of exporter objects; executed in order |
| `exporters[].type` | `"jsonl"` (default, stdlib) or `"mlflow"` (opt-in, requires `mlflow` package) |
| `exporters[].tracking_uri` | MLflow tracking server URI (mlflow only) |
| `exporters[].experiment` | MLflow experiment name (mlflow only) |

If the file is absent, `export` defaults to the JSONL exporter.

---

## State File Management

### Location

All state files are stored in `.claude/` directory:

```
.claude/
├── orchestration.local.md
├── team-orchestration.local.md
└── deep-dive.local.md
```

### Naming Convention

Files use `.local.md` suffix to indicate:
- Session-scoped (not committed to git)
- Human-readable (Markdown format)
- Machine-parseable (YAML frontmatter)

### Git Handling

Add to `.gitignore`:

```gitignore
# Agent Flow state files
.claude/*.local.md
```

### Cleanup

State files are ephemeral and can be safely deleted:

```bash
# Remove all state files
rm -f .claude/*.local.md

# Remove specific state
rm -f .claude/orchestration.local.md
rm -f .claude/team-orchestration.local.md
```

### Atomic Updates

State files are updated atomically using temp file + mv pattern:

```bash
# Write to temp file
cat > "$STATE_FILE.tmp.$$" << EOF
...content...
EOF

# Atomically move to final location
mv "$STATE_FILE.tmp.$$" "$STATE_FILE"
```

This prevents partial writes and corruption.

## Related Documentation

- [Commands Reference](commands.md) - Command specifications
- [Hooks Reference](hooks.md) - Hook system details
- [Architecture Overview](../architecture/overview.md) - System design
