# Agent Flow Plugin

Transform Claude Code into a multi-agent orchestrated system with verification gates.

## Features

- **Specialized Agent Delegation**: Route tasks to expert agents (Riko, Senku, Loid, Lawliet, Alphonse)
- **Mandatory Verification Gates**: Stop hooks ensure tests pass before task completion
- **Domain Expertise**: Skills provide guidance on task classification and verification
- **Cost-Aware Model Selection**: Sonnet for execution, Opus for exploration/planning/review

## Installation

Enable the plugin by adding to your Claude Code configuration:

```bash
claude --plugin-dir /path/to/agent-flow
```

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

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| Senku | Opus | Creates detailed implementation strategies |
| Riko | Opus | Fast codebase exploration |
| Loid | Sonnet | Implements code changes |
| Lawliet | Sonnet | Code quality assurance |
| Alphonse | Sonnet | Runs tests and validation |

## Hooks

### UserPromptSubmit Hook (Prompt-based)

**Analyzes user prompts for task clarity**:

- Evaluates if the request is well-defined
- Applies prompt refinement when needed
- Transforms vague requests into structured format (Goal, Description, Actions)

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
- **Lawliet (review)**: Consider feedback for action
- **Alphonse (verification)**: Check test results

This ensures appropriate verification without unnecessary friction for non-implementation tasks.

### PostToolUse Hook (validate-changes.sh)

Validates file writes after execution using the same guardrails as PreToolUse.

### Stop Hook (verify-completion.sh)

Runs before task completion to verify:

- Tests pass (`npm test` / `pytest`)
- TypeScript compiles (if applicable)
- Type checking passes (if `mypy` configured)

### SessionStart Hook (load-project-context.sh)

Detects project type and sets environment:

- Project type (nodejs, python, rust, go, java)
- Test framework (jest, pytest, cargo-test, etc.)
- Available tooling (TypeScript, ESLint, Ruff)

## Skills

Skills are domain expertise modules that provide behavioral patterns and best practices. Each skill has an **owner agent** responsible for embodying it and **consumer agents** that reference it.

For the complete skill-agent mapping, see [skills/skill-agent-mapping.md](skills/skill-agent-mapping.md).

### Skill-Agent Relationships

| Skill | Owner | Consumers |
|-------|-------|-----------|
| exploration-strategy | Riko | Senku, Loid |
| task-classification | Senku | Riko, Orchestrator |
| prompt-refinement | Senku | Orchestrator |
| verification-gates | Alphonse | Loid, Lawliet |
| agent-behavior-constraints | System | All |

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

## License

MIT
