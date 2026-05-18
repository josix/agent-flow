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

#### Graph-aware mode

If `.claude/orchestration.local.md` contains `graph: available: true`, inject a one-line graph preamble into every `Task(...)` call for Riko, Senku, and Lawliet:

```
# Read current graph status
GRAPH_AVAILABLE=$(grep -A1 '^graph:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

When `GRAPH_AVAILABLE` is `true`, prepend to each agent prompt:

```
Knowledge graph available at graphify-out/graph.json. See the
graphify-usage skill for query patterns and tool selection.
```

Loid and Alphonse do NOT receive this preamble (they are write/verify-only).

#### Personal KB-aware mode

If `.claude/orchestration.local.md` contains `personal_kb: available: true`, inject a one-line personal KB preamble into every `Task(...)` call for Riko, Senku, and Lawliet:

```
# Read current personal KB status
PERSONAL_KB_AVAILABLE=$(grep -A1 '^personal_kb:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

When `PERSONAL_KB_AVAILABLE` is `true`, prepend to each agent prompt:

```
Personal knowledge base available via mcp__personal-kb__* tools. See the
personal-kb-usage skill for cross-project recall query patterns.
```

Loid and Alphonse do NOT receive this preamble (they are write/verify-only).

### Phase 2: Planning
**Delegate to Senku** to create implementation strategy:
- Design the approach based on Riko's findings
- Identify files to modify
- Create step-by-step plan via TodoWrite
- Note risks and edge cases

### Senku thinking-budget hint

When dispatching Senku for planning or synthesis, append the following
to the prompt body:

> Take extended time to think through edge cases, file-level scope,
> and acceptance criteria before writing the plan. Budget ~8K tokens
> of deliberation before producing output.

This is a dispatch-time hint; Claude Code's agent frontmatter does not
currently expose a native thinking-budget field, so we steer via the
prompt instead.

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

After Lawliet completes, record its verdict (`APPROVED` or `NEEDS_CHANGES`).

#### Codex co-review (optional)

Check whether Codex is available:

```bash
CODEX_AVAILABLE=$(grep -A1 '^codex:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

**When `CODEX_AVAILABLE` is `true`**, run Codex as a co-reviewer via Bash (NOT a subagent dispatch — Codex is an external CLI):

Before dispatching Codex, the orchestrator MUST persist Lawliet's findings to a fixed well-known path so the Codex dispatch can include them. Lawliet's full markdown response lives in the orchestrator's conversation memory — use the Write tool to write Lawliet's full markdown response verbatim to `.claude/codex/lawliet-findings.tmp.md` before running the dispatch block below. Create the directory if needed: `mkdir -p .claude/codex`.

Then dispatch Codex with the task description, Lawliet's findings, and the full diff:

```bash
TASK_DESC=$(grep '^task:' .claude/orchestration.local.md | sed 's/^task: *//')
GIT_DIFF=$(git diff HEAD)
LAWLIET_FINDINGS=$(cat .claude/codex/lawliet-findings.tmp.md)
CODEX_OUT=$(mktemp)

BODY=$(printf '%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s' \
  "You are the Phase 4 co-reviewer. Follow the rubric in AGENTS.md at the repo root." \
  "## Task description" \
  "$TASK_DESC" \
  "## Lawliet's review (already completed — do not duplicate)" \
  "$LAWLIET_FINDINGS" \
  "## Diff under review" \
  "$GIT_DIFF")

printf '%s' "$BODY" | codex exec \
  -s read-only \
  --ignore-user-config \
  -c model_reasoning_effort="high" \
  --output-last-message "$CODEX_OUT" \
  -

CODEX_RAW=$(cat "$CODEX_OUT")
rm -f "$CODEX_OUT" .claude/codex/lawliet-findings.tmp.md
```

The output contract and severity scale are defined in `AGENTS.md` at the repo root, which Codex auto-loads on every invocation.

Codex's prompt now contains the task description, Lawliet's verdict + findings, and the full diff. Codex no longer needs to run `git diff` itself.

Parse `$CODEX_RAW` (the file content written by `--output-last-message` contains only Codex's final reply, plain text): the first non-blank line is the verdict (`APPROVED` / `NEEDS_CHANGES` / `BLOCKED`); subsequent lines of the form `<severity>: <file>:<line>: <issue>` are findings. Findings without a `file:line` token are advisory only and cannot trigger a NEEDS_CHANGES verdict. If the first non-blank line is not one of `APPROVED`, `NEEDS_CHANGES`, or `BLOCKED`, treat the entire Codex output as advisory and log `warn: Codex verdict unparseable — treating as advisory`.

**Findings without a `file:line` citation are advisory only** — they do not affect the final verdict and Loid is NOT routed back for them.

**Disagreement rule (truth table):**

Note: Lawliet emits only `APPROVED` or `NEEDS_CHANGES`. `BLOCKED` is a Codex-only verdict (used when Codex finds a severity-blocker with a `file:line` cite).

| Lawliet verdict | Codex verdict | Codex has file:line citation? | Final Phase 4 verdict |
|-----------------|---------------|-------------------------------|-----------------------|
| APPROVED | APPROVED | n/a | APPROVED |
| APPROVED | BLOCKED | yes | NEEDS_CHANGES (surface Codex cite) |
| APPROVED | BLOCKED | no | APPROVED (advisory only) |
| APPROVED | NEEDS_CHANGES | yes | NEEDS_CHANGES (surface Codex cite) |
| APPROVED | NEEDS_CHANGES | no | APPROVED (advisory only) |
| NEEDS_CHANGES | APPROVED | n/a | NEEDS_CHANGES (Lawliet wins on linter-grounded findings) |
| NEEDS_CHANGES | BLOCKED or NEEDS_CHANGES | any | NEEDS_CHANGES |

When the final verdict is NEEDS_CHANGES, delegate back to Loid with specific issues from Lawliet and/or Codex (file:line citations required).

**When `CODEX_AVAILABLE` is `false`**, skip the Codex co-review entirely. Phase 4 behaves identically to today (Lawliet-only). Log one info line:

```
info: Codex co-review skipped (codex.available: false)
```

After computing the final Phase 4 verdict:
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

## Delegation Decision Matrix

Before using any tool directly, check this table. If a persona owns the
tool, dispatch instead of inlining — the orchestrator should coordinate,
not execute.

| Tool(s) | Owner persona | Exception |
| --- | --- | --- |
| Read, Grep, Glob | Riko | single-line config read |
| Write, Edit, NotebookEdit | Loid | orchestration.local.md state updates |
| Bash (tests, build, lint) | Alphonse | none |
| Bash (static analysis) | Lawliet | none |
| TodoWrite, TaskCreate/Update | Orchestrator / Senku | — |
| Agent dispatch | Orchestrator | — |
| mcp__plugin_agent-flow_graphify__* | Riko / Senku / Lawliet | orchestrator may peek for routing decisions |

### Cache-read heuristic

If a non-Bash tool call would read >200 lines of code OR repeats a
file already read in this phase, dispatch instead of inlining. Each
direct Read replays the full orchestrator context through opus; a
persona dispatch forks to a smaller, cheaper cache footprint.

### Anti-pattern (do NOT do this)

> Orchestrator calls `Read src/auth/login.ts`, `Grep "validateToken"`,
> then `Edit src/auth/login.ts` — 3 direct tool calls. Correct pattern:
> one `Task(agent="Riko", prompt="locate validateToken in login.ts")`
> followed by one `Task(agent="Loid", prompt="edit validateToken to …")`.

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
