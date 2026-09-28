# Research Short-Circuit (research / exploratory tiers)

Loaded on demand by `/orchestrate` after Phase 2 when the short-circuit trigger condition holds.

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

## Plan-approved continuation

If a research/plan-only run has finished and the user then approves implementing it (e.g. "ok", "go ahead", "implement it"), do NOT edit code in the main thread. Re-enter the pipeline at Phase 3: re-activate the state file (re-run `init-orchestration.sh` with the task, re-persist the approved intent via `--set-intent-*`, then `update-orchestration-state.sh --phase implementation --agent Orchestrator --message "Plan approved — resuming at Phase 3"`), dispatch Loid with the approved plan (from the report / `.claude/agent-reports/`), then run Phases 4–6 (Lawliet + Codex, Alphonse, Report) as normal.
