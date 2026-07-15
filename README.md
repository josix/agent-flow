# Agent Flow Plugin

Transform Claude Code into a multi-agent orchestrated system with verification gates.

## Features

- **Specialized Agent Delegation**: Route tasks to expert agents (Riko, Senku, Loid, Lawliet, Alphonse, Speedwagon)
- **Mandatory Verification Gates**: Stop hooks ensure tests pass before task completion
- **Domain Expertise**: Skills provide guidance on task classification and verification
- **Cost-Aware Model Selection**: Opus for exploration/planning, Sonnet for execution/review/verification
- **Knowledge Graph Integration**: Graphify MCP server gives Riko/Senku/Lawliet structural codebase queries (blast-radius, communities, shortest path)
- **Personal Knowledge Base**: Personal-kb MCP server surfaces cross-project prior decisions and patterns for Riko/Senku/Lawliet
- **Codex Co-Review (optional)**: When the Codex CLI is installed and authenticated, Phase 4 routes the diff to OpenAI's Codex as a second reviewer alongside Lawliet, with availability-gated fallback. See [Using Codex Co-Review](docs/guides/using-codex-review.md).

## Prerequisites

| Requirement | Version | Purpose |
|---|---|---|
| Claude Code CLI | latest | Plugin host |
| Bash | 4+ | Hook scripts |
| `jq` | any | Plugin validation + hook scripts |
| `git` | any | Installation |
| Python 3.9+ with `graphifyy[mcp]` | optional | Knowledge graph queries (install via `pipx install graphifyy && pipx inject graphifyy mcp`) |

## Installation

### Method 0: Claude Code Marketplace (Recommended)

```
/plugin marketplace add josix/agent-flow
/plugin install agent-flow@josix-plugins
```

### Method 1: Local Plugin Directory (Development)

```bash
claude --plugin-dir /path/to/agent-flow
```

### Method 2: Git Clone

```bash
git clone https://github.com/josix/agent-flow.git
cd agent-flow
claude --plugin-dir .
```

**New to agent-flow?** Walk through [your first orchestration](docs/getting-started/first-orchestration.md) — a fresh-repo demo that exercises all 5 agents end-to-end.

### Validating Your Installation

Before running your first orchestration, verify the plugin is wired up correctly:

```bash
bash scripts/validate-plugin.sh
```

The script runs 16 structural checks covering:
- `plugin.json` and `hooks/hooks.json` are valid JSON
- All agent, skill, and command frontmatter parse correctly
- Hook scripts exist, are executable, and have valid syntax
- `validate-changes.sh` guardrails: path traversal, sensitive files, and system paths are blocked; valid writes are allowed
- Unit test suites for `ensure-gitignore.sh`, `verify-completion.sh`, `dispatch-codex-review.sh`, init-state escaping, and the research-report scripts
- Lawliet verdict-enum regression guard (Test 16): asserts `agents/Lawliet.md` still declares `[APPROVED | NEEDS_CHANGES]` and never emits `BLOCKED`

If all checks pass, you see: `✓ All tests passed`.

## Commands

### /deep-dive

Gather comprehensive codebase context using parallel exploration agents. Creates a reusable context file that accelerates subsequent orchestration tasks.

```
/deep-dive                    # Full codebase exploration
/deep-dive --focus=src/auth   # Focus on specific path
/deep-dive --refresh          # Refresh existing context
```

**Output**: `.claude/deep-dive.local.md` - Ephemeral, session-scoped context file

**Workflow**:
1. Fire 5+ parallel Riko agents exploring different aspects (structure, conventions, anti-patterns, etc.)
2. Senku synthesizes findings into unified context
3. Compile output to structured markdown

**Integration with /orchestrate**:
```
/orchestrate --use-deep-dive Add user authentication
```

When used with `--use-deep-dive`, orchestration leverages existing context to skip redundant exploration.

### /orchestrate

Coordinate complex multi-step tasks through the agent system. This command delegates to specialist agents in sequence:

1. **Riko** explores the codebase for context
2. **Senku** creates an implementation plan
3. **Loid** implements the changes
4. **Lawliet** reviews code quality
5. **Alphonse** runs verification gates

```
/orchestrate Add user authentication with JWT tokens
/orchestrate --use-deep-dive Add user profile page   # Use existing deep-dive context
```

**Arguments**:
- `--use-deep-dive`: Use existing deep-dive context for accelerated exploration

Note: Planning and verification are handled by agents (Senku, Alphonse) within the orchestration workflow rather than as standalone commands. This prevents responsibility conflicts in multi-agent coordination.

### /team-orchestrate

Execute complex tasks with parallel review and verification using Agent Teams. This command follows the same workflow as /orchestrate but runs Lawliet (review) and Alphonse (verification) concurrently after implementation, reducing wall-clock time by 30-40%.

```
/team-orchestrate Add user authentication with JWT tokens
/team-orchestrate --use-deep-dive Add user profile page
/team-orchestrate --force-sequential Add feature  # Fall back to sequential mode
```

**Arguments**:
- `--use-deep-dive`: Use existing deep-dive context for accelerated exploration
- `--force-sequential`: Force sequential execution instead of parallel review+verification

**Workflow**:
1. **Riko** explores the codebase (sequential)
2. **Senku** creates an implementation plan (sequential)
3. **Loid** implements the changes (sequential)
4. **Lawliet + Alphonse** run in parallel (team mode)
5. Results merged and processed

### /agent-flow:explain

Generate an interactive single-module HTML explainer for a codebase topic. Riko gathers code scope, Senku designs the teaching arc, Speedwagon authors the module brief and HTML fragment, and the assembler produces `explain-out/index.html`.

```bash
/agent-flow:explain how does orchestration work
/agent-flow:explain --revise orchestration-pipeline   # revise an existing module
```

Requires `.claude/deep-dive.local.md` (run `/deep-dive` first). Output is gitignored; open `explain-out/index.html` in a browser after generation.

The teaching primitives, content philosophy, and interactive-element patterns are built on ideas from [zarazhangrui/codebase-to-course](https://github.com/zarazhangrui/codebase-to-course), vendored locally as `skills/explainer-design-system/` and adapted for the single-module pipeline. See [Acknowledgments](#acknowledgments).

### /agent-flow:analyze

Parse Claude Code session transcripts and live hook events to surface subagent behaviour,
tool usage, token costs, and improvement opportunities. All data stays local in a SQLite
database — no network calls, no dependencies beyond Python stdlib.

```bash
# Load all sessions and generate a report
bash scripts/analyze.sh load --all-sessions && bash scripts/analyze.sh report

# Report for a single session
bash scripts/analyze.sh report --session <session_id>

# List all sessions in the database
bash scripts/analyze.sh sessions

# Ad-hoc SQL against the store
bash scripts/analyze.sh sql "SELECT agent_type, tool_name, COUNT(*) n FROM events GROUP BY agent_type, tool_name ORDER BY n DESC"

# Prune sessions older than 30 days
bash scripts/analyze.sh retention --days 30
```

The report covers tool usage by agent, MCP/skill invocations, thinking effort, token spend,
subagent dispatch rates, rejection rates, and automated improvement heuristics (high iteration
rate, tool allowlist violations, missing MCP usage, model mismatches).

Output files (gitignored): `.claude/observability/events.db`, `.claude/observability/report.md`

For the complete subcommand reference (including `label`, `export`, and exporter configuration) see [docs/guides/using-analyze.md](docs/guides/using-analyze.md).

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| Senku | Opus | Creates detailed implementation strategies |
| Riko | Opus | Fast codebase exploration |
| Loid | Sonnet | Implements code changes |
| Lawliet | Sonnet | Code quality assurance |
| Alphonse | Sonnet | Runs tests and validation |
| Speedwagon | Sonnet | Authors interactive explainer modules for /explain |

## Hooks

### UserPromptSubmit Hook (Deterministic command hook)

**`hooks/scripts/refine-prompt-gate.sh`** — a fixed shell script, not an LLM prompt hook. It never blocks:

- Skips silently on system-generated `<task-notification>`/system-tag payloads
- Skips silently on follow-ups while an orchestration is actively running (state `active: true`, `current_phase` non-terminal, and modified within the last 24h)
- Skips silently on short pronoun follow-ups ("fix it", "try again")
- Injects a refinement-nudge `additionalContext` payload only for new, unscoped task-verb prompts (a task verb like fix/add/implement with no concrete target — no filename, path, identifier, or quoted string)
- Fail-open: if `jq` is unavailable or the prompt is empty, it exits 0 immediately with no output

### PreToolUse Hook (enforce-delegation.sh)

**Provides delegation guidance**: Reminds agents about proper delegation patterns when writing files.

**Allowed silently**: Writing to `.senku/` directory (planning files)
**Allowed with reminder**: Writing to other files (shows delegation guidance message)

Note: Agent tool restrictions are the primary enforcement mechanism - Riko, Senku, and Lawliet do not have Write/Edit tools in their definitions. This hook provides helpful context rather than blocking.

### PreToolUse Hook (validate-changes.sh)

Validates file writes before execution to prevent:

- Path traversal attacks (`..` in paths)
- Writes to sensitive files (`.env`, credentials, keys)
- Writes to system paths (`/etc`, `/usr`, `/bin`)

### PostToolUse Hook (Task verification reminder)

**Context-aware verification guidance**: After delegation via Task tool, provides agent-specific verification guidance.

Verification levels by agent type:

- **Riko (exploration)**: Accept findings, no code verification needed
- **Senku (planning)**: Review plan completeness
- **Loid (implementation)**: Full verification required (read files, run tests, check types)
- **Lawliet (review)**: Consider feedback
- **Alphonse (verification)**: Check test results

This ensures appropriate verification without unnecessary friction for non-implementation tasks.

### PostToolUse Hook (validate-changes.sh)

Validates file writes after execution using the same guardrails as PreToolUse.

### Observability Hooks (log-event.sh)

Four lightweight hooks feed the local observability store (`.claude/observability/events.db`) used by `/agent-flow:analyze`:

- **PreToolUse** (matcher `Agent|Task`): Records subagent dispatches before they run
- **PostToolUse** (matcherless — all tools): Records tool results and token usage
- **SubagentStop**: Records final output and timing when a subagent finishes
- **SessionEnd**: Marks the session closed and triggers configured exporters

Each invokes `hooks/scripts/log-event.sh`, a thin wrapper around the Python sink `hooks/scripts/log-event.py`. Events fall back to `.claude/observability/events.jsonl` if the database is locked.

### Stop Hook (verify-completion.sh)

Runs before task completion to verify:

**Node.js Projects:**
- Tests: `npm test` (when `package.json` has test script)
- TypeScript: `npx tsc --noEmit` (when `tsconfig.json` exists)

**Python Projects:**
- Tests: pytest detection priority chain:
  - Custom command (from `.claude/test-command` file)
  - `uv run pytest` (when `uv.lock` present)
  - Global `pytest` (when `tests/` directory exists)
- Import/collection errors: `ImportError`, `ModuleNotFoundError`, `SyntaxError` treated as fatal
- Known failures: Only blocks on NEW failures not in `.claude/known-test-failures` list
- Type checking: `mypy .` (requires both `mypy` command and `mypy.ini` file)

**Configuration Files:**

| File | Purpose |
|------|---------|
| `.claude/skip-test-verification` | Bypass all test verification (first line used as reason) |
| `.claude/known-test-failures` | List of expected failures (one test name per line) |
| `.claude/test-command` | Custom test command to run (first non-comment line used) |

### SessionStart Hook (load-project-context.sh)

Detects project type and sets environment:

- Project type (nodejs, python, rust, go, java)
- Test framework (jest, pytest, cargo-test, etc.)
- Available tooling (TypeScript, ESLint, Ruff)

### SessionStart Hook (graph path export)

A second SessionStart command exports `AGENT_FLOW_GRAPH_PATH` into `$CLAUDE_ENV_FILE` when `graphify-out/graph.json` exists in the project, making the knowledge graph discoverable by the graphify MCP server. It exits silently when the graph or env file is absent.

### TeammateIdle Hook (teammate-idle-check.sh)

Validates teammate output quality using role-based criteria:

- **Input**: JSON from stdin with `teammate_role` and `teammate_output` fields
- **Reviewer (Lawliet)**: Must contain verdict (APPROVED/NEEDS_CHANGES) + static analysis evidence
- **Verifier (Alphonse)**: Must contain at least 2 verification gate results + command output
- **Other roles**: Approved without specific checks
- **Output**: Always exits 0; decision communicated via JSON `decision` field (`approve` or `block`) written to stdout

### TaskCompleted Hook (task-completed-check.sh)

Validates task completion messages for concrete evidence:

- **Input**: JSON from stdin with `task_status` and `completion_message` fields
- **Validation**: Only for complete/done/finished tasks
- **Evidence checks**: Message length >= 20 chars, file mentions, verification indicators, concrete actions, results/metrics
- **Output**: Always exits 0; decision communicated via JSON `decision` field (`approve` or `block`) written to stdout

## Skills

Skills are domain expertise modules that provide behavioral patterns and best practices. Each skill has an **owner agent** responsible for embodying it and **consumer agents** that reference it.

For the complete skill-agent mapping, see [skills/skill-agent-mapping/SKILL.md](skills/skill-agent-mapping/SKILL.md).

### Skill-Agent Relationships

| Skill | Owner | Consumers |
|-------|-------|-----------|
| exploration-strategy | Riko | Senku, Loid |
| task-classification | Senku | Riko, Orchestrator |
| prompt-refinement | Senku | Orchestrator |
| verification-gates | Alphonse | Loid, Lawliet |
| agent-behavior-constraints | System | All |
| team-decision | Senku | Orchestrator |
| graphify-usage | Riko | Senku, Lawliet |
| personal-kb-usage | Riko | Senku, Lawliet |
| explainer-design-system | Vendored (upstream: zarazhangrui) | Speedwagon |
| skill-agent-mapping | System | All |

### Task Classification

Guidance on routing tasks to appropriate agents:
- Trivial → Direct handling
- Exploratory → Explorer agent
- Implementation → Executor + Verifier
- Complex → Orchestrator

### Verification Gates

Mandatory validation patterns:
- Pre-commit gates (type check, lint)
- Pre-complete gates (tests, build)
- Override rules (when skipping is allowed)

### Exploration Strategy

Parallel context gathering and search stop rules.

### Prompt Refinement

Ambiguous request clarification and structured task specification.

### Agent Behavior Constraints

Model routing, tool access permissions, and universal behavioral guardrails.

## Architecture Principles

### The "Subagents LIE" Principle

Never trust unverified output. Every significant change requires mandatory testing, linting, and type-checking before acceptance.

### Orchestrator Discipline

Orchestrators delegate work rather than implementing directly. Specialists handle domain-specific tasks.

### Cost-Aware Model Selection

- **Opus**: Strategic/planning tasks - deep reasoning (Riko, Senku)
- **Sonnet**: Execution/verification tasks - speed (Loid, Lawliet, Alphonse)

## Documentation

For detailed documentation, see the [docs/](docs/) directory:

- **Architecture**: [Overview](docs/architecture/overview.md), [Team Orchestration](docs/architecture/team-orchestration.md)
- **Concepts**: [Parallel Safety](docs/concepts/parallel-safety.md)
- **Guides**: [Using Team-Orchestrate](docs/guides/using-team-orchestrate.md)
- **Reference**: [Commands](docs/reference/commands.md), [Hooks](docs/reference/hooks.md), [Skills](docs/reference/skills.md), [State Files](docs/reference/state-files.md)

See also [CHANGELOG.md](CHANGELOG.md) for version history.

## Acknowledgments

The `/agent-flow:explain` pipeline (Speedwagon agent + `skills/explainer-design-system/`) is built on ideas, content philosophy, and HTML interactive-element patterns from [**codebase-to-course**](https://github.com/zarazhangrui/codebase-to-course) by [Zara Zhang](https://github.com/zarazhangrui). The upstream skill targets multi-module course directories; we vendor it under `skills/explainer-design-system/` and adapt it to our single-module assembler in `scripts/compile-explain.sh`. Original SKILL.md content is preserved verbatim under the adapter note for design-guidance reference.

## License

MIT
