# State Files Reference

Complete reference for Agent Flow state files, including formats, fields, and management.

## Overview

Agent Flow uses state files to track workflow progress across sessions. These files are stored in the `.claude/` directory and use YAML frontmatter with Markdown content.

| File | Command | Purpose | Scope |
|------|---------|---------|-------|
| `orchestration.local.md` | /orchestrate | Phase and gate tracking | Session |
| `team-orchestration.local.md` | /team-orchestrate | Team phase and parallel group tracking | Session |
| `deep-dive.local.md` | /deep-dive | Codebase context | Session |

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

# Mark complete
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --complete \
  --agent Orchestrator \
  --message "All phases completed successfully"
```

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
