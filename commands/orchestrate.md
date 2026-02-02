---
name: orchestrate
description: Orchestrate a complex multi-step task using the multi-agent system
argument-hint: [--use-deep-dive] <task description>
---

# Orchestrate Command

Coordinate complex tasks through sequential delegation to specialist agents.

## Arguments

- `--use-deep-dive`: Use existing deep-dive context to skip or accelerate exploration phase
- `<task description>`: The task to orchestrate

## State Initialization

**FIRST**: Initialize orchestration state by running:

```bash
# Check for --use-deep-dive flag
USE_DEEP_DIVE=false
TASK_ARGS="$ARGUMENTS"
if [[ "$ARGUMENTS" == *"--use-deep-dive"* ]]; then
  USE_DEEP_DIVE=true
  TASK_ARGS=$(echo "$ARGUMENTS" | sed 's/--use-deep-dive//' | xargs)
fi

bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-orchestration.sh "$TASK_ARGS"
```

This creates `.claude/orchestration.local.md` to track:
- Current phase and iteration
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

You are coordinating a multi-agent workflow. You will delegate each phase to a specialist agent and pass context between them.

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

Follow this workflow by delegating to specialist agents:

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
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
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
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase planning --gate-result passed --agent Riko \
  --message "Exploration complete"
```

Proceed only when you have sufficient context.

### Phase 2: Planning
**Delegate to Senku** to create implementation strategy:
- Design the approach based on Riko's findings
- Identify files to modify
- Create step-by-step plan via TodoWrite
- Note risks and edge cases

After Senku completes, update state:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
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
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase review --gate-result passed --agent Loid \
  --message "Implementation complete"
```

Proceed only when Loid confirms changes are implemented.

### Phase 4: Review
**Delegate to Lawliet** to check code quality:
- Review implemented changes
- Run static analysis (type checking, linting)
- Check for security issues
- Verify adherence to patterns

After Lawliet completes:
- If APPROVED: Update state and proceed
- If NEEDS_CHANGES: Delegate back to Loid with specific issues

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase verification --gate-result passed --agent Lawliet \
  --message "Code review passed"
```

### Phase 5: Verification
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
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase verification --gate-result passed --agent Alphonse \
  --message "All verification gates passed"
```

### Phase 6: Report & Completion
Once ALL phases pass verification, provide a summary:
- What was implemented
- Which files were modified
- Test results (with counts)
- Verification evidence

**COMPLETION PROMISE:**
ONLY after Alphonse confirms ALL gates pass (tests, types, lint, build), output:

```
<orchestration-complete>TASK VERIFIED</orchestration-complete>
```

Then mark orchestration complete:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
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
3. **SEQUENTIAL PROCESSING** - Complete each phase before starting the next
4. **PASS CONTEXT** - When delegating, summarize relevant info from previous phases
5. **VERIFY RESULTS** - Check each agent's output before proceeding
6. **UPDATE STATE** - Run update-orchestration-state.sh after each phase
7. **QUALITY GATES** - Don't proceed if review or tests fail
8. **ITERATE IF NEEDED** - Loop back to Loid if issues are found
9. **EVIDENCE REQUIRED** - Demand actual command outputs, not claims
10. **NO FALSE COMPLETION** - Never claim complete without verified evidence

## State Monitoring

Check current orchestration state:
```bash
head -30 .claude/orchestration.local.md
```

Check current phase:
```bash
grep '^current_phase:' .claude/orchestration.local.md
```

## Example Delegation

```
Use the Riko agent to explore the authentication system and find
where user login is implemented
```

After Riko returns results:

```
Use the Senku agent to plan how to add OAuth2 support based on
Riko's findings that login is in src/auth/login.ts
```

Continue this pattern through all phases.

## Iteration Handling

If a phase fails (review issues, test failures):
1. Log the failure with update-orchestration-state.sh
2. Delegate back to Loid with specific issues
3. Increment iteration if needed
4. Re-run the failed phase
5. Continue only when gate passes

Maximum iterations are tracked in state. If reached, report status and stop.

## Task

Begin the orchestration workflow for: $ARGUMENTS

Start by initializing state and delegating to Riko for exploration.
