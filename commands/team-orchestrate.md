---
name: team-orchestrate
description: Orchestrate a complex multi-step task using Agent Teams for parallel phases
argument-hint: [--use-deep-dive] [--force-sequential] <task description>
---

# Team Orchestrate Command

Coordinate complex tasks through sequential delegation to specialist agents, with PARALLEL execution of Review + Verification phases using Agent Teams when available.

## Arguments

- `--use-deep-dive`: Use existing deep-dive context to skip or accelerate exploration phase
- `--force-sequential`: Force sequential mode even if Agent Teams is available
- `<task description>`: The task to orchestrate

## State Initialization

**FIRST**: Initialize team orchestration state by running:

```bash
# Parse flags from arguments
USE_DEEP_DIVE=false
FORCE_SEQUENTIAL=false
TASK_ARGS="$ARGUMENTS"

if [[ "$ARGUMENTS" == *"--use-deep-dive"* ]]; then
  USE_DEEP_DIVE=true
  TASK_ARGS=$(echo "$TASK_ARGS" | sed 's/--use-deep-dive//' | xargs)
fi

if [[ "$ARGUMENTS" == *"--force-sequential"* ]]; then
  FORCE_SEQUENTIAL=true
  TASK_ARGS=$(echo "$TASK_ARGS" | sed 's/--force-sequential//' | xargs)
fi

# Build init command
INIT_CMD="bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-team-orchestration.sh"
[[ "$USE_DEEP_DIVE" == true ]] && INIT_CMD="$INIT_CMD --use-deep-dive"
[[ "$FORCE_SEQUENTIAL" == true ]] && INIT_CMD="$INIT_CMD --force-sequential"
INIT_CMD="$INIT_CMD $TASK_ARGS"

eval "$INIT_CMD"
```

This creates `.claude/team-orchestration.local.md` to track:
- Current phase and iteration
- Orchestration mode (team vs sequential)
- Parallel group status (review_verification with sub-phases)
- Gate results for each phase
- Agent actions and timestamps

## Prompt Refinement (Pre-Phase)

Before beginning orchestration, ensure the task is well-defined:

1. **Check Task Clarity**: Does "$ARGUMENTS" specify:
   - What needs to be changed?
   - Where in the codebase?
   - What problem it solves?

2. **If Vague**: Ask ONE clarifying question before proceeding
   - Provide options when possible
   - Reference prompt-refinement skill for guidance

3. **If Clear**: Transform into structured format:
   - **Goal**: One-sentence outcome
   - **Description**: What and why (2-3 sentences)
   - **Actions**: Concrete steps

Only proceed to Phase 1 (Exploration) once the task is well-defined.

## Your Role

You are coordinating a multi-agent workflow with HYBRID execution model:
- **Phases 1-3**: Sequential (Exploration → Planning → Implementation)
- **Phases 4-5**: PARALLEL (Review + Verification via Agent Teams)
- **Phase 6**: Report & Completion

**CRITICAL BEHAVIORAL CONSTRAINTS:**
- Do NOT claim "task complete" or "looks good" without running verification commands
- Do NOT skip any phase or verification step
- Do NOT output the completion promise until ALL gates pass
- Do NOT assume success - verify with actual command output
- ALWAYS update state after each phase transition

## Available Specialist Agents

- **Riko** (explorer): Fast codebase exploration and information gathering
- **Senku** (planner): Strategic planning and implementation strategy
- **Loid** (executor): Code implementation and modifications
- **Lawliet** (reviewer): Code quality assurance and static analysis
- **Alphonse** (verifier): Test execution and validation

## Orchestration Workflow

For the task: "$ARGUMENTS"

### Mode Detection

After initialization, check the orchestration mode:

```bash
MODE=$(grep '^mode:' .claude/team-orchestration.local.md | sed 's/mode: *//' | tr -d '"')
TEAM_AVAILABLE=$(grep '^team_available:' .claude/team-orchestration.local.md | sed 's/team_available: *//')
```

The workflow adapts based on mode:
- **mode="team"**: Use Agent Teams for parallel Review + Verification
- **mode="sequential"**: Fall back to sequential execution

### Phase 1: Exploration

**Check for existing deep-dive context:**

```bash
# Check if deep-dive context exists and is usable
if [[ -f ".claude/deep-dive.local.md" ]]; then
  DEEP_DIVE_PHASE=$(grep '^phase:' .claude/deep-dive.local.md | sed 's/phase: *//' | tr -d '"')
  if [[ "$DEEP_DIVE_PHASE" == "complete" ]]; then
    echo "Deep-dive context available and complete"
  fi
fi
```

**If `--use-deep-dive` was specified AND deep-dive.local.md exists with phase=complete:**

1. Read the deep-dive context:
   ```bash
   cat .claude/deep-dive.local.md
   ```

2. Provide context summary to Riko for targeted exploration:
   ```
   Task(agent="Riko", prompt="
   TARGETED EXPLORATION using existing deep-dive context:

   [Include relevant sections from deep-dive.local.md]

   Focus only on:
   - Files directly relevant to: [task description]
   - Any recent changes not covered by deep-dive
   - Task-specific patterns not in general context

   Skip general architecture exploration - use the context above.
   ")
   ```

3. Update state:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
     --phase planning --gate-result passed --agent Riko \
     --message "Targeted exploration using deep-dive context"
   ```

**If no deep-dive context available (standard flow):**

**Delegate to Riko** to gather context:
- Find relevant files and patterns
- Understand existing architecture
- Identify key areas to modify

After Riko completes, update state and review findings:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --phase planning --gate-result passed --agent Riko \
  --message "Exploration complete"
```

Proceed only when you have sufficient context.

#### Graph-aware mode

If `.claude/team-orchestration.local.md` contains `graph: available: true`, inject a one-line graph preamble into every `Task(...)` call for Riko, Senku, and Lawliet:

```
Knowledge graph available at graphify-out/graph.json. See the
graphify-usage skill for query patterns and tool selection.
```

Loid and Alphonse do NOT receive this preamble.

### Phase 2: Planning

**Delegate to Senku** to create implementation strategy:
- Design the approach based on Riko's findings
- Identify files to modify
- Create step-by-step plan via TodoWrite
- Note risks and edge cases

After Senku completes, update state:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --phase implementation --gate-result passed --agent Senku \
  --message "Plan created with N steps"
```

Proceed only when you have a clear, actionable plan.

### Phase 3: Implementation

**Delegate to Loid** to implement the changes:
- Follow Senku's plan
- Write/edit code
- Ensure changes align with existing patterns
- Run tests after each change (sanity checks)

After Loid completes, update state:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --phase review_verification --gate-result passed --agent Loid \
  --message "Implementation complete"
```

Proceed only when Loid confirms changes are implemented.

### Phase 4+5: Review & Verification (THE KEY DIFFERENCE)

**Check mode and execute accordingly:**

```bash
MODE=$(grep '^mode:' .claude/team-orchestration.local.md | sed 's/mode: *//' | tr -d '"')
```

#### IF MODE IS "team" (PARALLEL EXECUTION):

**Step 1: Mark parallel group as in-progress**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --parallel-group review_verification --gate-result in_progress \
  --message "Starting parallel review and verification"
```

**Step 2: Create Agent Team**

Use the `TeamCreate` tool to create a team named "review-verify-team":

```
TeamCreate(
  team_name="review-verify-team",
  description="Parallel code review and verification team"
)
```

**Step 3: Create Tasks**

Use `TaskCreate` tool to create two tasks:

```
TaskCreate(
  team_name="review-verify-team",
  task_name="code-review",
  description="Run static analysis and check code quality"
)

TaskCreate(
  team_name="review-verify-team",
  task_name="verification",
  description="Run full test suite, type checking, lint, and build verification"
)
```

**Step 4: Spawn Parallel Teammates**

Use `Task` tool with `team_name` parameter to spawn two teammates:

**Reviewer (Lawliet's role):**
```
Task(
  agent="Lawliet",
  team_name="review-verify-team",
  prompt="
  REVIEW PHASE

  Review the implemented changes from Loid:
  - **Blast-radius check (if graph available)**: run `get_neighbors` on each changed file/symbol to find callers and dependents before judging impact
  - **Pattern adherence (if graph available)**: run `get_community` on changed nodes to compare against sibling modules in the same cluster
  - Run static analysis (type checking with tsc/mypy)
  - Run linters (eslint/ruff)
  - Check for security issues
  - Verify adherence to codebase patterns (cross-reference graph-surfaced siblings)
  - Look for potential bugs or edge cases (include callers from blast-radius output)

  Implementation files to review:
  [List files modified by Loid]

  Provide verdict:
  - APPROVED: Changes look good, no blocking issues
  - NEEDS_CHANGES: Specific issues that must be fixed (cite line numbers)

  Be thorough but focus on blockers, not style preferences.
  "
)
```

**Verifier (Alphonse's role):**
```
Task(
  agent="Alphonse",
  team_name="review-verify-team",
  prompt="
  VERIFICATION PHASE

  Run ALL verification gates for this project:

  1. Test Suite:
     - Run: npm test (or pytest for Python)
     - Report: Pass/fail counts with specific failures

  2. Type Checking:
     - Run: npx tsc --noEmit (or mypy . for Python)
     - Report: Count of type errors with details

  3. Linting:
     - Run: npm run lint (or ruff check . for Python)
     - Report: Count of lint errors

  4. Build:
     - Run: npm run build (or python -m build for Python)
     - Report: Build success/failure

  Provide structured results:
  - Tests: PASS/FAIL (X/Y passed)
  - Types: PASS/FAIL (N errors)
  - Lint: PASS/FAIL (N errors)
  - Build: PASS/FAIL
  - Overall: VERIFIED / FAILED

  CRITICAL: Report EXACT command outputs, not summaries.
  "
)
```

**Step 5: Assign Tasks**

Use `TaskUpdate` to assign tasks to teammates:

```
TaskUpdate(
  team_name="review-verify-team",
  task_name="code-review",
  assigned_to="[reviewer_teammate_id]",
  status="in_progress"
)

TaskUpdate(
  team_name="review-verify-team",
  task_name="verification",
  assigned_to="[verifier_teammate_id]",
  status="in_progress"
)
```

**Step 6: Wait for Completion**

Both teammates run in parallel. Wait for both to complete via `SendMessage` or status checks.

**Step 7: Collect Results**

Use `SendMessage` to gather results from both teammates:

```
SendMessage(
  team_name="review-verify-team",
  recipient="[reviewer_teammate_id]",
  message="What is your final verdict on the code review?"
)

SendMessage(
  team_name="review-verify-team",
  recipient="[verifier_teammate_id]",
  message="What are your final verification results?"
)
```

**Step 8: Update Teammate Statuses**

Update state for each teammate result:

```bash
# Update review status
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --parallel-group review_verification --teammate review \
  --gate-result passed --agent Lawliet \
  --message "Code review passed"

# Update verification status
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --parallel-group review_verification --teammate verification \
  --gate-result passed --agent Alphonse \
  --message "All verification gates passed: tests (15/15), types (0 errors), lint (0 errors), build (success)"
```

**Step 9: Merge Parallel Results**

Run the merge script to check if both sub-phases passed:

```bash
MERGE_RESULT=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/merge-parallel-results.sh --parallel-group review_verification)
ALL_PASSED=$(echo "$MERGE_RESULT" | grep -o '"all_passed": *[^,}]*' | sed 's/"all_passed": *//')
SUMMARY=$(echo "$MERGE_RESULT" | grep -o '"summary": *"[^"]*"' | sed 's/"summary": "//' | sed 's/"$//')

echo "Parallel Group Results: $SUMMARY"
```

**Step 10: Handle Results**

- **If ALL_PASSED is true**:
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
    --phase complete --gate-result passed \
    --message "Both review and verification passed"
  ```
  Proceed to Phase 6 (Completion)

- **If ALL_PASSED is false**:
  Extract failed phases and delegate back to Loid:
  ```bash
  FAILED_PHASES=$(echo "$MERGE_RESULT" | grep -o '"failed_phases": *\[[^]]*\]')
  ```

  Delegate to Loid with specific issues:
  ```
  Task(agent="Loid", prompt="
  Fix the issues found in parallel review/verification:

  Review Issues (if any):
  [Include Lawliet's feedback]

  Verification Issues (if any):
  [Include Alphonse's failures]

  Fix these issues and re-run local tests.
  ")
  ```

  After fixes, loop back to Phase 4+5 (increment iteration if needed)

#### IF MODE IS "sequential" (FALLBACK):

**Phase 4: Review (Sequential)**

**Delegate to Lawliet** to check code quality:
- Review implemented changes
- Run static analysis (type checking, linting)
- Check for security issues
- Verify adherence to patterns

After Lawliet completes:
- If APPROVED: Update state and proceed
- If NEEDS_CHANGES: Delegate back to Loid with specific issues

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --phase verification --gate-result passed --agent Lawliet \
  --message "Code review passed"
```

**Phase 5: Verification (Sequential)**

**Delegate to Alphonse** to validate:
- Run FULL test suite
- Verify builds succeed
- Run type checking
- Run linting
- Check that ALL tests pass

**VERIFICATION EVIDENCE REQUIRED:**
Alphonse MUST provide:
- Exact command outputs (not summaries)
- Pass/fail counts with specifics
- Zero errors confirmed for: tests, types, lint, build

After Alphonse completes:
- If ALL PASS: Update state and proceed to completion
- If ANY FAIL: Delegate back to Loid with failure details

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --phase verification --gate-result passed --agent Alphonse \
  --message "All verification gates passed"
```

### Phase 6: Report & Completion

Once ALL phases pass verification (whether parallel or sequential), provide a summary:
- What was implemented
- Which files were modified
- Test results (with counts)
- Verification evidence
- Mode used (team vs sequential)

**COMPLETION PROMISE:**
ONLY after verification confirms ALL gates pass (tests, types, lint, build), output:

```
<orchestration-complete>TASK VERIFIED</orchestration-complete>
```

Then mark orchestration complete:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-team-state.sh \
  --complete --agent Orchestrator \
  --message "All phases completed successfully"
```

**WARNING:** Do NOT output the completion promise if:
- Any tests are failing
- Type errors exist
- Lint errors exist
- Build fails
- Any verification gate is not confirmed PASS

## Critical Rules

1. **ALWAYS DELEGATE** - Use the Task tool to invoke specialist agents
2. **NEVER DO THE WORK YOURSELF** - You coordinate, specialists execute
3. **USE PARALLEL EXECUTION** - When mode="team", leverage Agent Teams for Review + Verification
4. **SEQUENTIAL FALLBACK** - When mode="sequential", execute phases sequentially
5. **PASS CONTEXT** - When delegating, summarize relevant info from previous phases
6. **VERIFY RESULTS** - Check each agent's output before proceeding
7. **UPDATE STATE** - Run update-team-state.sh after each phase/teammate completion
8. **QUALITY GATES** - Don't proceed if review or tests fail
9. **ITERATE IF NEEDED** - Loop back to Loid if issues are found
10. **EVIDENCE REQUIRED** - Demand actual command outputs, not claims
11. **NO FALSE COMPLETION** - Never claim complete without verified evidence

## State Monitoring

Check current orchestration state:
```bash
head -40 .claude/team-orchestration.local.md
```

Check current mode:
```bash
grep '^mode:' .claude/team-orchestration.local.md
```

Check parallel group status:
```bash
grep 'parallel_groups:' -A10 .claude/team-orchestration.local.md
```

## Example Team Delegation Flow

### Parallel Mode (Team):

1. **After Implementation Phase:**
   ```
   Implementation complete. Now starting PARALLEL review and verification.
   ```

2. **Create Team:**
   ```
   TeamCreate(team_name="review-verify-team", description="Parallel review and verification")
   ```

3. **Spawn Teammates Simultaneously:**
   - Reviewer: Task(agent="Lawliet", team_name="review-verify-team", prompt="[review instructions]")
   - Verifier: Task(agent="Alphonse", team_name="review-verify-team", prompt="[verification instructions]")

4. **Collect Results:**
   - Both complete in parallel
   - SendMessage to gather verdicts

5. **Merge & Decide:**
   - Run merge-parallel-results.sh
   - If both passed: Mark complete
   - If either failed: Iterate back to Loid

### Sequential Mode (Fallback):

1. **Phase 4 - Review:**
   ```
   Task(agent="Lawliet", prompt="Review the changes...")
   ```

2. **Phase 5 - Verification:**
   ```
   Task(agent="Alphonse", prompt="Run full verification...")
   ```

3. **Phase 6 - Complete:**
   ```
   All gates passed. Mark complete.
   ```

## Iteration Handling

If a phase fails (review issues, test failures):
1. Log the failure with update-team-state.sh
2. Delegate back to Loid with specific issues
3. Increment iteration if needed
4. Re-run the failed phase(s)
5. Continue only when gate passes

Maximum iterations are tracked in state. If reached, report status and stop.

## Task

Begin the team orchestration workflow for: $ARGUMENTS

Start by initializing state, detecting mode, and delegating to Riko for exploration.
