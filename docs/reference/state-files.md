# State Files Reference

Complete reference for Agent Flow state files, including formats, fields, and management.

## Overview

Agent Flow uses state files to track workflow progress across sessions. These files are stored in the `.claude/` directory and use YAML frontmatter with Markdown content.

| File | Command | Purpose | Scope |
|------|---------|---------|-------|
| `orchestration.local.md` | /orchestrate | Phase and gate tracking | Session |
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

## deep-dive.local.md

Stores comprehensive codebase context from deep-dive exploration.

### Format

```yaml
---
generated: "2024-01-15T10:00:00Z"
scope: "full"
focus_path: null
phase: "complete"
expires_hint: "refresh when codebase significantly changes"
agents_used: 6
exploration_aspects:
  - structure
  - conventions
  - antipatterns
  - build_ci
  - architecture
  - testing
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
| `phase` | string | Generation phase |
| `expires_hint` | string | When to refresh |
| `agents_used` | integer | Number of parallel agents |
| `exploration_aspects` | array | Aspects explored |

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
