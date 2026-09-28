---
name: orchestrate
description: Orchestrate a complex multi-step task using the multi-agent system
argument-hint: [--use-deep-dive] <task description>
---

# Orchestrate Command

Coordinate complex tasks through delegation to specialist agents.

## Arguments

- `--use-deep-dive`: Use existing deep-dive context to skip or accelerate exploration phase
- `<task description>`: The task to orchestrate

How much of the pipeline runs is decided by the orchestrator, not by user
flags — see Execution Profile.

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
   - **Constraints**: Non-negotiable limits
   - **Assumptions**: Things believed true that, if false, would change the approach

4. **Classify task complexity** using the `task-classification` skill tiers (Trivial / Exploratory / Implementation / Complex / Research). `task_complexity` is this tier, NOT complexipy code/cognitive complexity.

5. **Detect explicit written-report request**: independently of the tier, set `REPORT_REQUESTED_FLAG` to `true` only if the user explicitly asked for a written report, investigation guide, or planning document.

6. **Persist intent payload + task_complexity + report_requested to state** immediately after refinement (tier in canonical **lowercase**, e.g. `complex`):
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
     --set-task-complexity "complex" \
     --set-report-requested "false" \
     --set-intent-goal "One-sentence goal" \
     --set-intent-description "What and why" \
     --set-intent-actions "Concrete steps" \
     --set-intent-constraints "Non-negotiable limits" \
     --set-intent-assumptions "Believed-true assumptions"
   ```

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

Dispatch each agent with `Agent(subagent_type="agent-flow:<Name>", prompt=...)`.

### Dispatch Protocol

- **Wait for completion, not launch.** Subagents run in the background and their results arrive as completion notifications. Dispatch a phase, then WAIT for that agent's completion notification before updating state or advancing. Never advance on the launch acknowledgement, and do not poll.
- **Parallel dispatch** is allowed for independent Riko explorations and for Phase 4 + Phase 5 (Lawliet, Codex, and Alphonse are all read-only, so they run together — see "Phase 4 + 5"). Phases 1 → 2 → 3 stay sequential.
- **One state write per transition.** Combine flags into a single `update-orchestration-state.sh` call (e.g. `--phase review --gate-result passed --agent Loid --message ...`). Do not issue separate calls for each flag — every extra Bash call costs a full model round-trip.

- **Report-length rule.** End every dispatch prompt with: "If your report exceeds ~3000 characters, write the full report to `.claude/agent-reports/<agent>-<phase>.md` and return only a ≤1500-char summary, your verdict, and that path." When a reply cites such a path, Read the file before acting on the report (long reports relayed as notifications get truncated).

### Execution Profile (orchestrator-decided)

The orchestrator picks the profile itself — never ask the user to choose, and
there are no mode flags. Decide once, right after Prompt Refinement, from the
persisted `task_complexity` tier plus risk signals in the intent and target
files:

- **fast** — tier `trivial`, or `implementation` with a clear, localized target (1–2 files, no auth/security/data-migration/public-API surface).
- **thorough** — tier `complex`, or any tier touching auth, security, payments, data migration, concurrency, or a public API/schema.
- **standard** — everything else.

| | fast | standard | thorough |
|---|---|---|---|
| Phase 1 Riko | skip (Loid locates its own target) | skip for `trivial` | always |
| Phase 2 Senku | skip | skip for `trivial` | always |
| Phase 4 Lawliet | yes | yes | yes |
| Phase 4 Codex | skip | yes (if available) | yes (if available) |
| Phase 5 Alphonse | yes | yes | yes |
| Max review-fix rounds | 1 | 2 | 3 |

**Escalate mid-run, never downgrade:** if Loid or a reviewer reports the
change is wider or riskier than classified (more files, security surface,
failing unrelated tests), move up one profile for the rest of the run.

When Phases 1–2 are skipped, dispatch Loid with the full intent payload (Goal,
Constraints, Assumptions) in place of Senku's plan and tell it to locate the
target itself. Research/exploratory tiers still use the Research Short-Circuit.
Log the choice once with its reason: `info: execution profile <profile> (tier <tier>; <reason>)`.

### Dispatch Recovery

Applies to dispatch failures in **all** phases.

- On an API/transport error or a completely empty reply, auto-retry the same dispatch **ONCE**, silently; surface the failure only if the retry also fails. Log the retry:
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
    --message "Dispatch retry: <agent> (transport error/empty reply on first attempt)"
  ```
- **Read-only agents** (Riko, Lawliet, Alphonse): always safe to auto-retry.
- **Loid** (mutating): retry only after confirming via `git status` / state that no partial write landed. If one may exist, do **NOT** auto-retry — surface to the user to reconcile.
- **Crash discriminator:** an explicit transport/API error string, or an empty reply with no output-contract markers (no expected verdict/summary structure), is a crash. A well-formed but short reply is **NOT** a crash — accept it as-is.

## Orchestration Workflow

For the task: "$ARGUMENTS"

Follow this workflow by delegating to specialist agents:

### Phase 1: Exploration

**If `--use-deep-dive` was specified:** read `${CLAUDE_PLUGIN_ROOT}/skills/exploration-strategy/references/deep-dive-reuse.md` — when `.claude/deep-dive.local.md` has `phase: complete`, dispatch Riko for *targeted* exploration seeded with that context (skipping general architecture exploration) and advance state as described there.

**If no deep-dive context available (standard flow):**

**Delegate to Riko** to find relevant files and patterns, understand the existing architecture, and identify key areas to modify. After Riko completes, update state and review findings:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase planning --gate-result passed --agent Riko \
  --message "Exploration complete"
```

Proceed only when you have sufficient context.

#### Context preambles (graph / personal KB / AgentsView)

For each of `graph`, `personal_kb`, and `agentsview` marked `available: true` in `.claude/orchestration.local.md`, inject the corresponding preamble into every Riko, Senku, and Lawliet dispatch (never Loid or Alphonse). Read `${CLAUDE_PLUGIN_ROOT}/skills/exploration-strategy/references/context-preambles.md` for the status checks and exact preamble text before the first dispatch.

### Phase 2: Planning
**Delegate to Senku** to design the approach from Riko's findings, identify files to modify, note risks and edge cases, and return the plan as a numbered markdown checklist (if long, written to `.claude/agent-reports/senku-<slug>.md` with the path returned). Senku's `effort: high` frontmatter sets its reasoning depth; no prompt-level thinking hint is needed.

After Senku completes, run the gates below before advancing state.

#### Assumption Escalation Gate (after Phase 2 dispatch)

**Step 1.** Scan Senku's reply for `<escalation type="assumption-contradicted">`.

- **Absent** → proceed normally (no prompt).
- **Present** → call **AskUserQuestion** surfacing the assumption, contradiction, A/B/C options, and recommendation from the block. On answer:
  - **A or B** → update `intent.assumptions` via `--set-intent-assumptions`, re-dispatch Senku with the corrected assumption. Increment iteration via `--iteration` if this is a repeat.
  - **C** → record user clarification text into `intent.assumptions` via `--set-intent-assumptions`, re-dispatch Senku with the clarified assumption.
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
    --set-intent-assumptions "<corrected assumption>" \
    --iteration <N>
  ```

#### Post-Plan Confirmation (Complex tasks only)

**Step 2.** Read the task complexity tier from state and normalize to lowercase:
```bash
TASK_COMPLEXITY=$(grep '^task_complexity:' .claude/orchestration.local.md | sed 's/task_complexity: *//' | tr -d '"' | tr '[:upper:]' '[:lower:]')
```

- NOT `complex` (including missing or `unclassified`) → skip the gate, log `info: post-plan confirmation skipped (task_complexity != complex)`, go to Phase 3. **No prompt.**
- `complex` → call **AskUserQuestion** ONCE, presenting goal, key-assumptions, constraints, and approach-summary from Senku's `<plan-interpretation>` block alongside the persisted intent:
  - A) Confirm → Phase 3 immediately.
  - B) Correct an assumption or constraint / C) Adjust scope → persist via `--set-intent-assumptions` / `--set-intent-constraints`, re-dispatch Senku ONCE only if the correction is material, else proceed to Phase 3 with the updated intent.

  **Hard cap: one interruption max** — never re-prompt this gate.

**Step 3.** Only after no pending escalation and user confirmed/corrected (Steps 1–2 complete), advance state:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase implementation --gate-result passed --agent Senku \
  --message "Plan created with N steps"
```

Proceed only when you have a clear, actionable plan.

### Research Short-Circuit (stub)

**Trigger:** `task_complexity` is `research` or `exploratory`, OR `report_requested` is `true` in state. When triggered, Phases 3–5 are skipped and the orchestrator writes a research report instead of the `<orchestration-complete>` promise. Read `${CLAUDE_PLUGIN_ROOT}/skills/task-classification/references/research-short-circuit.md` before proceeding. If NOT triggered, proceed to Phase 3 unchanged.

**Plan-approved continuation:** if the user later approves implementing a research/plan-only result, never edit code in the main thread — re-enter the pipeline at Phase 3 (dispatch Loid, then Phases 4–6) per that reference.

### Phase 3: Implementation
**Delegate to Loid** to implement Senku's plan in line with existing patterns, running only the tests covering the changed code (sanity checks) — the full suite is Alphonse's job in Phase 5, so Loid must not run it too.

Before dispatching Loid, snapshot the tree so later review rounds can be
scoped to just the new fixes:

```bash
REVIEW_BASE=$(git stash create 2>/dev/null); REVIEW_BASE=${REVIEW_BASE:-$(git rev-parse HEAD)}
```

After Loid completes, run the gate below before advancing state.

#### Assumption Escalation Gate (after Phase 3 dispatch)

**Step 1.** Scan Loid's reply for `<escalation type="assumption-contradicted">` and handle it exactly as the Phase 2 gate does (absent → no prompt; present → AskUserQuestion, persist via `--set-intent-assumptions` / `--iteration`), except that you re-dispatch **Loid** with the corrected or clarified assumption.

**Step 2.** Only after no pending escalation resolves (Step 1 complete), advance state:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase review --gate-result passed --agent Loid \
  --message "Implementation complete"
```

Proceed only when Loid confirms changes are implemented.

### Phase 4 + 5: Parallel Review & Verification

Lawliet, Codex, and Alphonse never write code, so launch them **in one turn**
instead of back-to-back:

1. `Agent(subagent_type="agent-flow:Lawliet", ...)` — Phase 4 review (below).
2. `Agent(subagent_type="agent-flow:Alphonse", ...)` — Phase 5 verification (below).
3. Codex (when the profile includes it) — run the parallel dispatch block from
   `skills/verification-gates/references/codex-co-review.md` with Bash `run_in_background: true` and **without**
   `--lawliet-findings`; Codex's AGENTS.md rubric already excludes
   linter-level findings, and the verdicts are reconciled afterwards.

Wait for all launched reviewers to report, then compute the Phase 4 verdict
(Codex truth table) and read Alphonse's verdict. If both pass, write ONE state
update that records both gates and moves to completion. If either fails, run
a review-fix round.

#### Review-fix rounds (capped)

A round = one Loid fix dispatch followed by re-review/re-verify. Each round:

- **Batch everything.** Send Loid ALL blocking findings from Lawliet, Codex,
  and Alphonse in one dispatch — never one finding per round.
- **Only ERROR/WARNING with `file:line` triggers a round.** INFO items and
  advisory notes go straight to the Phase 6 report.
- **Scope the re-review to the fix.** Snapshot `REVIEW_BASE` before the fix
  dispatch (see Phase 3) and tell Lawliet/Codex to review only
  `git diff $REVIEW_BASE` plus new untracked files, and to confirm the
  previous findings are resolved. Re-run Alphonse in parallel.
- **Stop at the profile's cap** (1 / 2 / 3) — decided by the orchestrator,
  not the user. When the cap is reached with findings still open:
  - If the last round reduced the number of open ERROR findings and an ERROR
    remains → allow exactly ONE extra round.
  - Otherwise stop: do not dispatch Loid again, and list every open
    `file:line` finding under "Open findings" in the Phase 6 report.
  Only an open ERROR the orchestrator judges unsafe to ship (security issue,
  data loss, broken build) may pause for AskUserQuestion.

The Codex Divergence Cap (in `codex-co-review.md`) still applies inside these rounds.

### Phase 4: Review
**Delegate to Lawliet** to review the changes: static analysis (types, lint), security issues, and adherence to patterns. Pass the intent Goal + Constraints from state so Lawliet also checks intent fidelity; an `intent-mismatch` NEEDS_CHANGES verdict routes back to Loid via the normal NEEDS_CHANGES path.

  Intent (from state):
  Goal: [insert intent.goal from state]
  Constraints: [insert intent.constraints from state]

After Lawliet completes, record its verdict (`APPROVED` or `NEEDS_CHANGES`).

#### Codex co-review (stub)

Codex runs only when the profile includes it AND state has `codex.available: true`; otherwise Phase 4 is Lawliet-only. It is an external CLI launched via Bash (not a subagent) in the background, in parallel with Lawliet and Alphonse. The final Phase 4 verdict follows the Lawliet/Codex truth table (only `file:line`-cited Codex findings can force NEEDS_CHANGES), and same-citation standoffs are bounded by the Divergence Cap.

Read `${CLAUDE_PLUGIN_ROOT}/skills/verification-gates/references/codex-co-review.md` before launching Codex or reconciling its verdict.

After computing the final Phase 4 verdict:
- If APPROVED: Update state and proceed
- If NEEDS_CHANGES: Delegate back to Loid with specific issues

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase verification --gate-result passed --agent Lawliet \
  --message "Code review passed"
```

### Phase 5: Verification
**Delegate to Alphonse** to run the FULL test suite, build, type checking, and linting, and confirm ALL tests pass.

**VERIFICATION EVIDENCE REQUIRED:** Alphonse MUST provide exact command outputs (not summaries), pass/fail counts with specifics, and zero errors confirmed for tests, types, lint, and build.

After Alphonse completes, branch on Alphonse's `### Overall:` verdict (three-way):
- **VERIFIED** (all gates PASS): Update state and proceed to completion.
- **FAILED** (a real code defect — test/type/lint/build failure not explained by an environment mismatch): Delegate back to Loid with failure details.
- **ENVIRONMENT_BLOCKED** (a gate failed solely due to an interpreter/dependency/environment mismatch the change did not introduce — see the triage rule in `skills/verification-gates/references/failure-handling.md`): Do **NOT** route to Loid — it cannot fix the local environment. Log `warn: verification environment-blocked — proceeding with caveat` with Alphonse's exact error signature, record the blocker in state, and proceed to completion with the caveat in the Intent Ledger's "Environment gates (P1-2)" line.

**If VERIFIED:**
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase verification --gate-result passed --agent Alphonse \
  --message "All verification gates passed"
```

**If ENVIRONMENT_BLOCKED** (warn-and-proceed — do NOT claim all gates passed; preserve the blocker in the message):
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase verification --gate-result passed --agent Alphonse \
  --message "Verification environment-blocked: <exact error signature> — proceeded with caveat"
```

### Phase 6: Report & Completion
Once ALL phases pass verification, provide a summary:
- What was implemented
- Which files were modified
- Test results (with counts)
- Verification evidence
- Any `.claude/agent-reports/` files written this run (scratch output; safe to delete after review)

**Intent Ledger (required)** — emit it before the completion promise, sourced
from state and from what actually happened this run; render empty fields as
"none recorded" and never fabricate gap-handler lines. Read
`${CLAUDE_PLUGIN_ROOT}/skills/verification-gates/references/intent-ledger.md`
for the exact template (including the "Environment gates (P1-2)" line) before
emitting it.

**COMPLETION PROMISE:**
ONLY after Alphonse confirms ALL gates pass (tests, types, lint, build) as `VERIFIED`, OR the only outstanding gate is `ENVIRONMENT_BLOCKED` (proceeding with the caveat noted in the Intent Ledger per the Phase 5 three-way branch above), output:

```
<orchestration-complete>TASK VERIFIED</orchestration-complete>
```

Then mark orchestration complete:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --complete --agent Orchestrator \
  --message "All phases completed successfully"
```

**WARNING:** Do NOT output the completion promise if any tests fail, type or lint errors exist, the build fails, or any gate is not confirmed `VERIFIED` or `ENVIRONMENT_BLOCKED` (the latter is a permitted warn-and-proceed state, not a block).

## Delegation Decision Matrix

Before using any tool directly, check this table. If a persona owns the
tool, dispatch instead of inlining — the orchestrator should coordinate,
not execute.

| Tool(s) | Owner persona | Exception |
| --- | --- | --- |
| Read, Grep, Glob | Riko | single-line config read; reading `.claude/agent-reports/*` files an agent cited; reading reference files this command points to |
| Write, Edit, NotebookEdit | Loid | orchestration.local.md state updates; `.claude/research-*.local.md` (script-mediated via compile-research-report.sh in research short-circuit) |
| Bash (tests, build, lint) | Alphonse | none |
| Bash (static analysis) | Lawliet | none |
| Plan tracking | Senku | plans are markdown checklists persisted in the state file / `.claude/agent-reports/` (no todo tool) |
| Agent dispatch | Orchestrator | — |
| mcp__plugin_agent-flow_graphify__* | Riko / Senku / Lawliet | orchestrator may peek for routing decisions |
| mcp__plugin_agent-flow_agentsview__* | Riko / Senku / Lawliet | orchestrator may peek for routing decisions |

### Cache-read heuristic

If a non-Bash tool call would read >200 lines of code OR repeats a
file already read in this phase, dispatch instead of inlining. Each
direct Read grows the orchestrator's own context (and every later turn
replays it); a persona dispatch keeps that work in a smaller, cheaper
context.

### Anti-pattern (do NOT do this)

> Orchestrator calls `Read src/auth/login.ts`, `Grep "validateToken"`,
> then `Edit src/auth/login.ts` — 3 direct tool calls. Correct pattern:
> one `Agent(subagent_type="agent-flow:Riko", prompt="locate validateToken in login.ts")`
> followed by one `Agent(subagent_type="agent-flow:Loid", prompt="edit validateToken to …")`.

## Critical Rules

1. **ALWAYS DELEGATE** - Use the Agent tool to invoke specialist agents
2. **NEVER DO THE WORK YOURSELF** - You coordinate, specialists execute
3. **PHASE ORDER** - Phases 1 → 2 → 3 complete in order; Phase 4 + 5 run in parallel (see Dispatch Protocol)
4. **PASS CONTEXT (LOSSLESS)** - Do NOT re-summarize the intent payload between phases. After Prompt Refinement, persist the structured intent (Goal/Description/Actions/Constraints/Assumptions) to state via update-orchestration-state.sh --set-intent-*. When delegating to each phase agent, pass the intent block VERBATIM from state. You may still add phase-specific context (e.g., "Riko found X in file Y"), but the intent payload itself must not be paraphrased.
5. **VERIFY RESULTS** - Check each agent's output before proceeding
6. **UPDATE STATE** - Run update-orchestration-state.sh once per phase transition, with all flags combined into that single call
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

## Iteration Handling

If a phase fails (review issues, test failures):
1. Log the failure with update-orchestration-state.sh
2. Delegate back to Loid with specific issues
3. Increment iteration if needed
4. Re-run the failed phase
5. Continue only when gate passes

Maximum iterations are tracked in state. If reached, report status and stop.

When `max_iterations` is reached, or the run is abandoned/errored and will not continue, the orchestrator MUST run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh --complete --agent Orchestrator --message "Aborted: <reason>"` so state reaches a terminal value (`active: false`). `--complete` means **terminal**, not successful — the message records the reason (e.g. "Aborted: max iterations reached"). Otherwise the `refine-prompt-gate.sh` UserPromptSubmit hook mistakes the stalled run for an active orchestration and suppresses the refinement nudge for the next new task.

## Task

Begin the orchestration workflow for: $ARGUMENTS

Start by initializing state and delegating to Riko for exploration.
