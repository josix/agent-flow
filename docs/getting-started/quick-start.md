# Quick Start

Get productive with Agent Flow in 5 minutes.

## Installation

```
/plugin marketplace add josix/agent-flow
/plugin install agent-flow@josix-plugins
```

Or clone and load it directly:

```bash
git clone https://github.com/josix/agent-flow.git ~/agent-flow
claude --plugin-dir ~/agent-flow
```

## Your First Orchestration

### Step 1: Start a Session

Navigate to your project:

```bash
cd your-project
claude          # add --plugin-dir ~/agent-flow if you cloned
```

### Step 2: Run Your First Task

```
/orchestrate Add input validation to the user registration form
```

> **Working in a fresh project with no existing code?** Try the [first orchestration walkthrough](first-orchestration.md) instead — the example above assumes an existing form to modify.

Watch as:
1. **Riko** explores your codebase
2. **Senku** creates an implementation plan
3. **Loid** implements the changes
4. **Lawliet** reviews code quality
5. **Alphonse** verifies tests and build

Depending on the profile, Riko and Senku may be skipped; Lawliet and Alphonse always run, in parallel, and Codex joins under standard/thorough if installed. Complex tasks pause once for plan confirmation.

### Step 3: Review the Result

When you see:
```
<orchestration-complete>TASK VERIFIED</orchestration-complete>
```

Your task is complete with:
- All tests passing
- No type or lint errors (checked by Lawliet)
- Build successful

If review findings remain after the round cap, the report lists them under "Open findings" and no completion marker is printed.

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
| `/team-orchestrate <task>` | Deprecated — forwards to `/orchestrate` |
| `/deep-dive` | Explore entire codebase |
| `/deep-dive --focus=<path>` | Explore specific area |
| `/deep-dive --refresh` | Update existing context |
| `/agent-flow:explain <topic>` | Generate an interactive HTML explainer for a codebase topic |
| `/agent-flow:analyze` | Load session transcripts and report on subagent behavior |

### Agents

| Agent | Role | When Active |
|-------|------|-------------|
| Riko | Explorer | Finding files, understanding patterns |
| Senku | Planner | Creating implementation strategy |
| Loid | Executor | Writing and editing code |
| Lawliet | Reviewer | Checking code quality |
| Alphonse | Verifier | Running tests and validation |
| Speedwagon | Author | Writing `/explain` modules (not part of `/orchestrate`) |

### State Files

| File | Purpose |
|------|---------|
| `.claude/orchestration.local.md` | Tracks orchestration progress |
| `.claude/deep-dive.local.md` | Stores codebase context |

You don't need to edit `.gitignore`. agent-flow adds a managed block to it the first time a command runs. Set `AGENT_FLOW_NO_GITIGNORE` to any non-empty value to opt out.

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

3. **Trust the verification** - When it says VERIFIED, the code passed all checks (a capped run lists open findings instead)

4. **Let the system ask questions** - If your request is vague, it will clarify

5. **Check the summary** - Always review what was implemented and verified

## Next Steps

- [Your First Orchestration](first-orchestration.md) - Walkthrough for an empty project
- [Installation Guide](installation.md) - Detailed setup instructions
- [Using Orchestrate](../guides/using-orchestrate.md) - In-depth orchestration guide
- [Using Deep-Dive](../guides/using-deep-dive.md) - Context gathering guide
- [The "Subagents LIE" Principle](../concepts/subagents-lie.md) - Why verification matters
