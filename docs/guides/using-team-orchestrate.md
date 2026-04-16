# Using Team Orchestrate

A practical guide to executing complex tasks with parallel review and verification using Agent Teams.

## What is Team Orchestrate?

Team orchestrate is an enhanced orchestration workflow that parallelizes the review and verification phases using Agent Teams. While the traditional `/orchestrate` command executes phases sequentially, `/team-orchestrate` spawns parallel teammates for independent validation tasks.

**Key Difference**: Review (static analysis) and Verification (test execution) run concurrently, reducing wall-clock time by 30-40% with minimal token overhead.

## Prerequisites

### Enable Agent Teams Feature

Set the experimental flag in your environment:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Add to your shell profile (`.bashrc`, `.zshrc`, etc.) to persist across sessions:

```bash
# Enable Claude Code Agent Teams
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### Verify Availability

The system automatically detects Agent Teams availability during initialization. You can verify manually:

```bash
bash scripts/check-team-availability.sh
```

Expected output when available:
```json
{
  "available": true,
  "message": "Agent Teams feature is available (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)"
}
```

## Quick Start

### Basic Usage

Execute a task with team orchestration:

```
/team-orchestrate Add user authentication with JWT tokens
```

The system will:
1. Initialize state with mode detection
2. Run sequential phases (exploration, planning, implementation)
3. Spawn parallel teammates for review and verification
4. Merge results and report completion

### Using Deep-Dive Context

Accelerate exploration by leveraging existing context:

```
/team-orchestrate --use-deep-dive Add password reset functionality
```

Prerequisites:
- Run `/deep-dive` first to generate context
- Verify `.claude/deep-dive.local.md` exists with `phase: complete`

### Force Sequential Mode

Disable parallel execution even when Agent Teams is available:

```
/team-orchestrate --force-sequential Refactor the database layer
```

Use cases:
- Debugging team coordination issues
- Comparing sequential vs parallel performance
- Environments where Agent Teams may be unstable

## Command Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--use-deep-dive` | Off | Use existing deep-dive context for exploration |
| `--force-sequential` | Off | Disable parallel execution |

### Flag Combinations

```bash
# Standard team orchestration
/team-orchestrate Add feature X

# With deep-dive context
/team-orchestrate --use-deep-dive Add feature X

# Force sequential mode
/team-orchestrate --force-sequential Add feature X

# Sequential with deep-dive
/team-orchestrate --use-deep-dive --force-sequential Add feature X
```

## When to Use Team-Orchestrate vs Orchestrate

### Use /team-orchestrate When

- **Agent Teams is available**: Feature flag enabled
- **Time-sensitive tasks**: Faster feedback desired
- **Independent validation**: Review and verification are truly independent
- **Normal complexity**: Standard features, refactoring, bug fixes

### Use /orchestrate When

- **Agent Teams unavailable**: Feature not enabled
- **Sequential debugging**: Need to isolate phases
- **Simple tasks**: Overhead not justified
- **Learning the system**: Easier to understand sequential flow

### Decision Tree

```
Need multi-agent workflow?
    ├─ Yes
    │   └─ Agent Teams available?
    │       ├─ Yes → /team-orchestrate
    │       └─ No  → /orchestrate
    └─ No  → Use Claude directly or specialized tools
```

## Understanding the Workflow

### Hybrid Execution Model

Team orchestrate uses a hybrid approach:

**Sequential Phases (1-3)**:
1. Exploration (Riko)
2. Planning (Senku)
3. Implementation (Loid)

**Parallel Phase (4+5)**:
4. Review (Lawliet) ─┐
5. Verification (Alphonse) ─┘ (concurrent)

**Completion (6)**:
6. Report results

### Observing Parallel Execution

During phase 4+5, you'll see:
```
Implementation complete. Now starting PARALLEL review and verification.

Creating team: review-verify-team
Spawning teammates:
  - Reviewer (Lawliet): Static analysis and pattern checks
  - Verifier (Alphonse): Test suite and build validation

Waiting for parallel completion...
```

Both teammates work concurrently. The orchestrator waits for both before proceeding.

## Reading State Files

Team orchestration uses `.claude/team-orchestration.local.md` to track progress.

### Check Current Mode

```bash
grep '^mode:' .claude/team-orchestration.local.md
```

Output:
```yaml
mode: "team"        # Agent Teams enabled
mode: "sequential"  # Fallback mode
```

### Check Current Phase

```bash
grep '^current_phase:' .claude/team-orchestration.local.md
```

Output:
```yaml
current_phase: "exploration"
current_phase: "planning"
current_phase: "implementation"
current_phase: "review_verification"  # Parallel phase
current_phase: "complete"
```

### Check Parallel Group Status

```bash
grep 'parallel_groups:' -A15 .claude/team-orchestration.local.md
```

Output during parallel execution:
```yaml
parallel_groups:
  review_verification:
    status: "in_progress"
    started_at: "2024-01-15T10:45:00Z"
    review:
      status: "in_progress"
      agent: "Lawliet"
      timestamp: "2024-01-15T10:45:05Z"
    verification:
      status: "in_progress"
      agent: "Alphonse"
      timestamp: "2024-01-15T10:45:10Z"
```

### Check Gate Results

```bash
grep 'gates:' -A20 .claude/team-orchestration.local.md
```

Output:
```yaml
gates:
  exploration:
    status: "passed"
  planning:
    status: "passed"
  implementation:
    status: "passed"
  review_verification:
    status: "in_progress"
  review:
    status: "in_progress"
  verification:
    status: "in_progress"
```

## Troubleshooting Common Issues

### Agent Teams Not Available

**Symptom**: Mode is "sequential" even though you expected "team"

**Check**:
```bash
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
```

**Fix**:
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
# Then restart Claude Code session
```

**Verify**:
```bash
bash scripts/check-team-availability.sh
```

### Team Creation Fails

**Symptom**: Error during "Creating team" step

**Fallback**: System automatically switches to sequential mode

**Resolution**:
1. Check state file for mode:
   ```bash
   grep '^mode:' .claude/team-orchestration.local.md
   ```
2. If mode switched to "sequential", workflow continues normally
3. No action required - graceful degradation in effect

### Parallel Phase Hangs

**Symptom**: Orchestrator stuck waiting for teammates

**Diagnosis**:
```bash
# Check parallel group status
grep 'parallel_groups:' -A15 .claude/team-orchestration.local.md
```

**Resolution**:
- Check which teammate is stuck (review or verification)
- Verify teammate task output for errors
- Use `--force-sequential` flag to retry sequentially

### Results Not Merged

**Symptom**: Both teammates complete but orchestrator doesn't proceed

**Diagnosis**:
```bash
# Run merge script manually
bash scripts/merge-parallel-results.sh --parallel-group review_verification
```

**Fix**:
- Check merge script output for errors
- Verify state file format is valid YAML
- Update teammate statuses manually if needed

### Iteration Loop

**Symptom**: Orchestrator repeatedly retries implementation phase

**Check iteration count**:
```bash
grep '^iteration:' .claude/team-orchestration.local.md
```

**Common causes**:
- Review finds persistent issues
- Verification gates consistently fail
- Implementation not addressing feedback

**Resolution**:
1. Read review and verification outputs
2. Identify root cause of failures
3. If max iterations reached, review task complexity
4. Consider breaking into smaller tasks

## Best Practices

### 1. Always Enable Agent Teams for Complex Tasks

For multi-step implementations, the latency reduction is significant:

```bash
# Add to shell profile
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### 2. Use Deep-Dive Context for Unfamiliar Codebases

Generate context once, use for multiple tasks:

```bash
# First session
/deep-dive

# Subsequent tasks
/team-orchestrate --use-deep-dive Task A
/team-orchestrate --use-deep-dive Task B
/team-orchestrate --use-deep-dive Task C
```

### 3. Monitor State During Long Tasks

Track progress to understand where time is spent:

```bash
# Watch current phase
watch -n 5 'grep "^current_phase:" .claude/team-orchestration.local.md'

# View full state
tail -f .claude/team-orchestration.local.md
```

### 4. Use Sequential Mode for Debugging

When diagnosing issues, sequential mode provides clearer flow:

```bash
/team-orchestrate --force-sequential Debug issue X
```

Easier to identify which phase is problematic.

### 5. Clean State Between Sessions

Remove state files after completion to avoid stale data:

```bash
rm .claude/team-orchestration.local.md
```

Or keep for reference if needed for debugging.

## Example Session

### Complete Workflow

```
User: /team-orchestrate Add user profile page with avatar upload

Claude: Agent Flow Team Orchestration initialized.

Task: Add user profile page with avatar upload
Max Iterations: 10
Mode: team (team_available=true, force_sequential=false)

TEAM MODE ENABLED:
  - Phases 1-3: Sequential (Exploration -> Planning -> Implementation)
  - Phase 4+5: Parallel (Review + Verification using Agent Teams)
  - Phase 6: Report & Completion

Current Phase: exploration
Iteration: 1/10

Delegating to Riko for exploration...

[Riko explores codebase]

Exploration complete. Proceeding to planning phase.

Delegating to Senku for planning...

[Senku creates implementation plan]

Plan complete with 7 steps. Proceeding to implementation.

Delegating to Loid for implementation...

[Loid implements changes]

Implementation complete. Now starting PARALLEL review and verification.

Creating team: review-verify-team
Spawning teammates:
  - Reviewer (Lawliet): Checking code quality
  - Verifier (Alphonse): Running verification gates

[Both teammates work concurrently]

Parallel execution complete. Merging results...

Review: APPROVED
  - Type check: PASS (0 errors)
  - Lint: PASS (0 warnings)
  - Patterns: Followed existing conventions
  - Security: No issues found

Verification: VERIFIED
  - Tests: PASS (23/23 passed)
  - Types: PASS (npx tsc --noEmit - clean)
  - Lint: PASS (npm run lint - clean)
  - Build: PASS (npm run build - success)

All phases completed successfully.

<orchestration-complete>TASK VERIFIED</orchestration-complete>

Summary:
- Mode: team (parallel review + verification)
- Files modified: 5 (src/components/Profile.tsx, src/api/users.ts, ...)
- Tests: 23/23 passed
- Verification: All gates passed
- Duration: Reduced via parallel execution
```

## Comparing with /orchestrate

### Feature Comparison

| Feature | /orchestrate | /team-orchestrate |
|---------|-------------|-------------------|
| Exploration | Sequential | Sequential |
| Planning | Sequential | Sequential |
| Implementation | Sequential | Sequential |
| Review | Sequential | Parallel (team mode) |
| Verification | Sequential | Parallel (team mode) |
| Fallback | N/A | Sequential mode |
| Prerequisites | None | Agent Teams feature |

### Performance Characteristics

**Sequential** (/orchestrate):
- Predictable execution order
- Easier to debug
- No team coordination overhead
- Works in all environments

**Team** (/team-orchestrate):
- 30-40% faster wall-clock time
- Parallel review + verification
- Graceful fallback if unavailable
- Small token overhead (~2-5%)

## Related Documentation

- [Team Orchestration Architecture](../architecture/team-orchestration.md) - Design and implementation
- [Commands Reference: /team-orchestrate](../reference/commands.md#team-orchestrate) - Command specification
- [State Files: team-orchestration.local.md](../reference/state-files.md#team-orchestrationlocalmd) - State format
- [Parallel Safety](../concepts/parallel-safety.md) - Safety guarantees
