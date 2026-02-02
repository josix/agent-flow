# Quick Start

Get productive with Agent Flow in 5 minutes.

## Installation

```bash
# Clone Agent Flow
git clone https://github.com/your-org/agent-flow.git ~/agent-flow

# Launch Claude Code with the plugin
claude --plugin-dir ~/agent-flow
```

## Your First Orchestration

### Step 1: Start a Session

Navigate to your project:

```bash
cd your-project
claude --plugin-dir ~/agent-flow
```

### Step 2: Run Your First Task

```
/orchestrate Add input validation to the user registration form
```

Watch as:
1. **Riko** explores your codebase
2. **Senku** creates an implementation plan
3. **Loid** implements the changes
4. **Lawliet** reviews code quality
5. **Alphonse** verifies everything passes

### Step 3: Review the Result

When you see:
```
<orchestration-complete>TASK VERIFIED</orchestration-complete>
```

Your task is complete with:
- All tests passing
- No type errors
- No lint errors
- Build successful

## Deep-Dive for Context

For larger tasks, gather context first:

```
/deep-dive
```

Then use that context:

```
/orchestrate --use-deep-dive Add password reset functionality
```

## Quick Reference

### Commands

| Command | Purpose |
|---------|---------|
| `/orchestrate <task>` | Execute a complex task |
| `/orchestrate --use-deep-dive <task>` | Execute with existing context |
| `/deep-dive` | Explore entire codebase |
| `/deep-dive --focus=<path>` | Explore specific area |
| `/deep-dive --refresh` | Update existing context |

### Agents

| Agent | Role | When Active |
|-------|------|-------------|
| Riko | Explorer | Finding files, understanding patterns |
| Senku | Planner | Creating implementation strategy |
| Loid | Executor | Writing and editing code |
| Lawliet | Reviewer | Checking code quality |
| Alphonse | Verifier | Running tests and validation |

### State Files

| File | Purpose |
|------|---------|
| `.claude/orchestration.local.md` | Tracks orchestration progress |
| `.claude/deep-dive.local.md` | Stores codebase context |

Add to `.gitignore`:
```
.claude/*.local.md
```

## Example Workflow

```bash
# Start new session
claude --plugin-dir ~/agent-flow

# Gather codebase context (optional but recommended)
/deep-dive

# Implement features using context
/orchestrate --use-deep-dive Add user authentication
/orchestrate --use-deep-dive Add password reset
/orchestrate --use-deep-dive Add email verification

# Refresh context after major changes
/deep-dive --refresh
```

## Tips for Success

1. **Be specific** - "Add JWT authentication with refresh tokens" > "Add auth"

2. **Use deep-dive first** - For unfamiliar codebases, the upfront investment pays off

3. **Trust the verification** - When it says VERIFIED, the code passed all checks

4. **Let the system ask questions** - If your request is vague, it will clarify

5. **Check the summary** - Always review what was implemented and verified

## Next Steps

- [Installation Guide](installation.md) - Detailed setup instructions
- [Using Orchestrate](../guides/using-orchestrate.md) - In-depth orchestration guide
- [Using Deep-Dive](../guides/using-deep-dive.md) - Context gathering guide
- [The "Subagents LIE" Principle](../concepts/subagents-lie.md) - Why verification matters
