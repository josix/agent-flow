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
   - **Constraints**: Non-negotiable limits
   - **Assumptions**: Things believed true that, if false, would change the approach

4. **Classify task complexity** using the `task-classification` skill tiers (Trivial / Exploratory / Implementation / Complex / Research). Note: `task_complexity` is the task-classification tier, NOT complexipy code/cognitive complexity.

5. **Detect explicit written-report request**: independently of the complexity tier, determine whether the user explicitly asked for a written report, investigation guide, or planning document (e.g., "write me a report", "give me an investigation guide", "produce a planning doc"). Set `REPORT_REQUESTED_FLAG` to `true` or `false` accordingly.

6. **Persist intent payload + task_complexity + report_requested to state** immediately after refinement. Persist the tier in **lowercase** (e.g., `complex`); the Post-Plan Confirmation gate normalizes to lowercase before comparing, so either casing works, but lowercase is the canonical form:
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

### Dispatch Recovery

This subsection governs dispatch failures across **all** phases, not just one.

- If a dispatched agent returns an API/transport error, or a completely empty reply, auto-retry the same dispatch **ONCE**, silently. Only surface the failure to the user if the retry also fails. Log the retry:
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
    --message "Dispatch retry: <agent> (transport error/empty reply on first attempt)"
  ```
- **Idempotent, read-only agents** (Riko, Lawliet, Alphonse): always safe to auto-retry — they make no mutating changes, so a retry cannot compound damage.
- **Loid** (mutating): retry only after confirming no partial write landed — check `git status` / relevant state before retrying. If a partial write may exist, do **NOT** auto-retry; surface to the user instead so they can decide how to reconcile the partial change.
- **Crash discriminator:** an explicit error string (transport/API error) or an empty reply with no output-contract markers (e.g. missing the agent's expected verdict/summary structure) counts as a crash. A well-formed but short reply is **NOT** a crash and should be accepted as-is.

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

Note: `task_complexity` is the task-classification tier (NOT complexipy code/cognitive complexity). The gate compares against lowercase `complex`; either `complex` or `Complex` in the state file will match.

- If `TASK_COMPLEXITY` is NOT `complex` (including missing or `unclassified`) → skip this gate entirely, log `info: post-plan confirmation skipped (task_complexity != complex)`, and proceed directly to Phase 3. **No prompt.**
- If `TASK_COMPLEXITY` is `complex` → extract Senku's `<plan-interpretation>` block and the `intent` payload from state, then call **AskUserQuestion** ONCE:

  Present: goal, key-assumptions, constraints, approach-summary from the `<plan-interpretation>` block alongside the persisted intent. Ask the user:
  - A) Confirm — proceed to implementation
  - B) Correct an assumption or constraint — specify what
  - C) Adjust scope — specify how

  On A → Phase 3 immediately.
  On B or C → persist correction via `--set-intent-assumptions` / `--set-intent-constraints` as appropriate, then optionally re-dispatch Senku ONCE if the correction is material; otherwise proceed to Phase 3 with the updated intent.

  **Hard cap: one interruption max** — after one user answer, proceed; never re-prompt this gate.

**Step 3.** Only after no pending escalation and user confirmed/corrected (Steps 1–2 complete), advance state:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
  --phase implementation --gate-result passed --agent Senku \
  --message "Plan created with N steps"
```

Proceed only when you have a clear, actionable plan.

### Research Short-Circuit (research / exploratory tiers)

Read the task complexity tier and report-requested flag from state:
```bash
TASK_COMPLEXITY=$(grep '^task_complexity:' .claude/orchestration.local.md | sed 's/task_complexity: *//' | tr -d '"' | tr '[:upper:]' '[:lower:]')
REPORT_REQUESTED=$(grep '^report_requested:' .claude/orchestration.local.md | sed 's/report_requested: *//' | tr -d '"' | tr '[:upper:]' '[:lower:]')
```

**Trigger condition:** short-circuit activates when `TASK_COMPLEXITY` is `research` or `exploratory`, OR when `REPORT_REQUESTED` is `true` (persisted during Phase 0 prompt refinement when the user explicitly requested a written report, investigation guide, or planning document).

**If NOT triggered:** proceed to Phase 3 (Implementation) unchanged.

**When triggered:**

Phases 3–5 (Loid/Lawliet/Alphonse) are skipped — this is an information-only deliverable. The orchestrator performs all write steps directly (script-mediated state write — see Delegation Decision Matrix exception).

1. Initialize the report artifact (capturing the path from stdout).
   Normalize the scope before calling init — `init-research-report.sh` only
   accepts `research` or `exploratory`. If the tier is neither (e.g. `complex`
   or `implementation` on the explicit-ask path), pass `--scope research`:
   ```bash
   if [[ "$TASK_COMPLEXITY" == "exploratory" ]]; then
     INIT_SCOPE="exploratory"
   else
     INIT_SCOPE="research"
   fi
   REPORT_PATH=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-research-report.sh \
     --goal "<intent.goal>" \
     --scope "$INIT_SCOPE")
   ```

2. Compile findings from Phase 1 (Riko) exploration and Phase 2 (Senku) synthesis directly into the report, then mark it complete:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-research-report.sh \
     --report-path "$REPORT_PATH" \
     --summary "<one-paragraph summary of findings>" \
     --findings "<detailed findings from Riko + Senku>" \
     --plan "<recommendations or N/A for exploratory>" \
     --open-questions "<any unresolved questions>" \
     --sources "<files read, URLs, evidence>" \
     --mark-complete
   ```

3. Emit the research completion tag and Intent Ledger:

   ```
   <research-report-complete>REPORT WRITTEN: <REPORT_PATH></research-report-complete>
   ```

   Then the Intent Ledger (same format as Phase 6 completion, sourced from state). This replaces the `<orchestration-complete>` promise for this path.

4. Mark orchestration complete:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
     --complete --agent Orchestrator \
     --message "Research report written: $REPORT_PATH"
   ```

The report file at `$REPORT_PATH` is gitignored via `.claude/*.local.*` and persists for the user to keep and reference.

### Phase 3: Implementation
**Delegate to Loid** to implement the changes:
- Follow Senku's plan
- Write/edit code
- Ensure changes align with existing patterns
- Run tests after each change (sanity checks)

After Loid completes, run the gate below before advancing state.

#### Assumption Escalation Gate (after Phase 3 dispatch)

**Step 1.** Scan Loid's reply for `<escalation type="assumption-contradicted">`.

- **Absent** → proceed normally (no prompt).
- **Present** → call **AskUserQuestion** surfacing the assumption, contradiction, A/B/C options, and recommendation from the block. On answer:
  - **A or B** → update `intent.assumptions` via `--set-intent-assumptions`, re-dispatch Loid with the corrected assumption. Increment iteration if this is a repeat.
  - **C** → record user clarification text into `intent.assumptions` via `--set-intent-assumptions`, re-dispatch Loid with the clarified assumption.
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
    --set-intent-assumptions "<corrected assumption>" \
    --iteration <N>
  ```

**Step 2.** Only after no pending escalation resolves (Step 1 complete), advance state:
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
- Pass the intent Goal + Constraints from state so Lawliet can check intent fidelity, not just static cleanliness. An `intent-mismatch` NEEDS_CHANGES verdict routes back to Loid via the existing NEEDS_CHANGES path.

  Intent (from state):
  Goal: [insert intent.goal from state]
  Constraints: [insert intent.constraints from state]

After Lawliet completes, record its verdict (`APPROVED` or `NEEDS_CHANGES`).

#### Codex co-review (optional)

Check whether Codex is available:

```bash
CODEX_AVAILABLE=$(grep -A1 '^codex:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

**When `CODEX_AVAILABLE` is `true`**, run Codex as a co-reviewer via Bash (NOT a subagent dispatch — Codex is an external CLI):

Before dispatching Codex, the orchestrator MUST persist Lawliet's findings to a fixed well-known path so the Codex dispatch can include them. Lawliet's full markdown response lives in the orchestrator's conversation memory — use the Write tool to write Lawliet's full markdown response verbatim to `.claude/codex/lawliet-findings.tmp.md` before running the dispatch block below. Create the directory if needed: `mkdir -p .claude/codex`.

Then dispatch Codex via the shared helper:

```bash
LAWLIET_FINDINGS_FILE=".claude/codex/lawliet-findings.tmp.md"
CODEX_RESULT=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/dispatch-codex-review.sh \
  --state-file .claude/orchestration.local.md \
  --lawliet-findings "$LAWLIET_FINDINGS_FILE")
CODEX_RAN=$(echo "$CODEX_RESULT" | grep '^codex_ran:' | sed 's/.*: *//')
CODEX_VERDICT=$(echo "$CODEX_RESULT" | grep '^codex_verdict:' | sed 's/.*: *//')
CODEX_RAW_PATH=$(echo "$CODEX_RESULT" | grep '^codex_raw_path:' | sed 's/.*: *//')
CODEX_RAW=""
if [[ -n "$CODEX_RAW_PATH" && -f "$CODEX_RAW_PATH" ]]; then
  CODEX_RAW=$(cat "$CODEX_RAW_PATH")
  rm -f "$CODEX_RAW_PATH"
fi
rm -f "$LAWLIET_FINDINGS_FILE"
```

The output contract and severity scale are defined in `AGENTS.md` at the repo root, which Codex auto-loads on every invocation.

If the shared helper (`scripts/dispatch-codex-review.sh`) detects that `codex exec` exited non-zero (timeout, auth failure, network), Phase 4 falls back to Lawliet-only — the helper exits 0 but emits `codex_verdict: ADVISORY` so the orchestrator can detect the degraded state. The final verdict is whatever Lawliet emitted.

The helper builds the diff, task description, and Lawliet's findings internally. `$CODEX_RAW` contains Codex's full reply (as written by `--output-last-message`): the first non-blank line is the verdict (`APPROVED` / `NEEDS_CHANGES` / `BLOCKED`); subsequent lines of the form `<severity>: <file>:<line>: <issue>` are findings. Findings without a `file:line` token are advisory only and cannot trigger a NEEDS_CHANGES verdict. If the first non-blank line is not one of `APPROVED`, `NEEDS_CHANGES`, or `BLOCKED`, treat the entire Codex output as advisory and log `warn: Codex verdict unparseable — treating as advisory`.

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

#### Divergence Cap (Lawliet/Codex standoff)

A **divergence round** is a Phase-4 round where Lawliet's verdict is `APPROVED` but the final verdict is `NEEDS_CHANGES` driven solely by a Codex `file:line` citation (i.e. the `APPROVED`/`BLOCKED` or `APPROVED`/`NEEDS_CHANGES` rows of the truth table above).

Read the counter defensively before evaluating the round:

```bash
DIV=$(grep '^codex_divergence_rounds:' .claude/orchestration.local.md | sed 's/.*: *//')
DIV=${DIV:-0}
```

- If the current round is a divergence round **and** the Codex citation is the **same** `file:line` as the previous divergence round → increment `DIV` and persist it:
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh --set-codex-divergence-rounds <DIV+1>
  ```
- If the citation changed (a genuinely new issue) or Lawliet itself emitted `NEEDS_CHANGES` → reset the counter to 0 (persist via `--set-codex-divergence-rounds 0`) and treat this as a normal fix round.

**When `DIV` reaches 2:** STOP looping — do NOT re-dispatch Loid again for the same standoff. Call **AskUserQuestion** (mirroring the Assumption Escalation Gate pattern above) presenting the persistent Codex citation and Lawliet's `APPROVED` stance, with options:
- **A)** Accept Codex — route to Loid to fix the cited issue.
- **B)** Accept Lawliet — proceed to Phase 5.
- **C)** Provide guidance.

**Default when unanswered: B** (favor Lawliet, matching the truth table's linter-grounded bias).

After the standoff is resolved (either by user answer or by a genuine new issue breaking the loop), reset the counter: `--set-codex-divergence-rounds 0`.

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

After Alphonse completes, branch on Alphonse's `### Overall:` verdict (three-way):
- **VERIFIED** (all gates PASS): Update state and proceed to completion.
- **FAILED** (a real code defect — test/type/lint/build failure not explained by an environment mismatch): Delegate back to Loid with failure details.
- **ENVIRONMENT_BLOCKED** (a gate failed solely due to an interpreter/dependency-version/environment mismatch the change did not introduce — see `skills/verification-gates/references/failure-handling.md` triage rule): Do **NOT** route to Loid — Loid cannot fix the local interpreter/environment. Log `warn: verification environment-blocked — proceeding with caveat` including the exact error signature Alphonse cited, record the blocker in state, and proceed to completion with the caveat noted in the Intent Ledger (see the "Environment gates (P1-2)" line below).

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

**Intent Ledger** — emit this block before the completion promise, sourcing
intent fields from `.claude/orchestration.local.md` (persisted during Prompt
Refinement via `--set-intent-*`/`--set-task-complexity`) and from what actually
happened during this run. If a field is empty, render "none recorded". Be
truthful for every gap-handler line: if a handler never fired, say so explicitly
("none" / "not needed" / "skipped"). Do not fabricate. This ledger makes the
otherwise-silent always-on gap-handlers (Gaps 4/5/6) and the conditional ones
(1/2/3/7) observable in one place.

```
## Intent Ledger

**Captured intent** (from state file):
- Goal: <intent.goal>
- Constraints: <intent.constraints or "none recorded">
- Key assumptions: <intent.assumptions or "none recorded">
- Task complexity: <task_complexity>

**Gap-handlers that fired this run:**
- Intent clarification (Gap 1): <"asked: <q>" | "not needed — task was clear">
- Interpretation/rationale confirm (Gaps 2/3): <"shown & confirmed" | "shown & corrected: <what>" | "skipped — task_complexity != complex">
- Lossless context pass-through (Gap 4): <"intent passed verbatim across phases" — always on>
- Behavioral guardrails (Gap 5): <"no plan deviations" | "deviations flagged: <what>">
- Assumption escalations (Gap 7): <"none" | one line per escalation: assumption → resolution>
- Intent-fidelity review (Gap 6): <"PASS" | "intent-mismatch flagged: <what>, resolved in iteration N">
- Environment gates (P1-2): <"none" | "environment-blocked: <what>, proceeded with caveat">
```

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

**WARNING:** Do NOT output the completion promise if:
- Any tests are failing
- Type errors exist
- Lint errors exist
- Build fails
- Any verification gate is not confirmed `VERIFIED` or `ENVIRONMENT_BLOCKED` (see Phase 5's three-way branch — `ENVIRONMENT_BLOCKED` is a permitted warn-and-proceed completion state, not a block)

## Delegation Decision Matrix

Before using any tool directly, check this table. If a persona owns the
tool, dispatch instead of inlining — the orchestrator should coordinate,
not execute.

| Tool(s) | Owner persona | Exception |
| --- | --- | --- |
| Read, Grep, Glob | Riko | single-line config read |
| Write, Edit, NotebookEdit | Loid | orchestration.local.md state updates; `.claude/research-*.local.md` (script-mediated via compile-research-report.sh in research short-circuit) |
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
4. **PASS CONTEXT (LOSSLESS)** - Do NOT re-summarize the intent payload between phases. After Prompt Refinement, persist the structured intent (Goal/Description/Actions/Constraints/Assumptions) to state via update-orchestration-state.sh --set-intent-*. When delegating to each phase agent, pass the intent block VERBATIM from state. You may still add phase-specific context (e.g., "Riko found X in file Y"), but the intent payload itself must not be paraphrased.
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

When `max_iterations` is reached, or the run is abandoned/errored and will not continue, the orchestrator MUST run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh --complete --agent Orchestrator --message "Aborted: <reason>"` so state reaches a terminal value (`active: false`). Note that `--complete` marks the run **terminal**, not necessarily successful — the message records the abort reason (e.g. "Aborted: max iterations reached", "Aborted: unrecoverable dispatch failure"). This prevents the `refine-prompt-gate.sh` hook (see Phase 4 Divergence Cap and the P0-2 UserPromptSubmit wiring) from mistaking a stalled/abandoned run for an active orchestration and suppressing the refinement nudge for the next genuinely-new task.

## Task

Begin the orchestration workflow for: $ARGUMENTS

Start by initializing state and delegating to Riko for exploration.
