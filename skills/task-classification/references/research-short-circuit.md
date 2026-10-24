# Research Short-Circuit (research / exploratory tiers)

Loaded on demand by `/orchestrate` on the report-only route — right after Phase 1 when Senku is skipped, otherwise after the Phase 2 Assumption Escalation Gate, and always before Post-Plan Confirmation.

Read the task complexity tier and report-requested flag from state:
```bash
TASK_COMPLEXITY=$(grep '^task_complexity:' .claude/orchestration.local.md | sed 's/task_complexity: *//' | tr -d '"' | tr '[:upper:]' '[:lower:]')
REPORT_REQUESTED=$(grep '^report_requested:' .claude/orchestration.local.md | sed 's/report_requested: *//' | tr -d '"' | tr '[:upper:]' '[:lower:]')
```

**Trigger condition:** short-circuit activates when `TASK_COMPLEXITY` is `research` or `exploratory`, OR when `REPORT_REQUESTED` is `true` (persisted during Phase 0 prompt refinement when the user explicitly requested a written report, investigation guide, or planning document).

**Profile interaction:** this route overrides fast/standard/thorough: Riko (Phase 1) always runs; Senku (Phase 2) runs unless the tier is `exploratory` with no report requested (`compile-research-report.sh` requires a Plan/Recommendations section for scope `research`). Post-Plan Confirmation and the `--phase implementation` write are skipped.

**If NOT triggered:** continue with Post-Plan Confirmation and Phase 3 unchanged.

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

2. Compile findings from Phase 1 (Riko) exploration and Phase 2 (Senku) synthesis directly into the report (Senku's synthesis only when Phase 2 ran — see Profile interaction above), then mark it complete:
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

3. Emit the Intent Ledger (same format as Phase 6, sourced from state), then the research completion tag:

   ```
   <research-report-complete>REPORT WRITTEN: <REPORT_PATH></research-report-complete>
   ```

   This replaces the `<orchestration-complete>` promise for this path.

4. Mark orchestration complete:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
     --complete --agent Orchestrator \
     --message "Research report written: $REPORT_PATH"
   ```

The report file at `$REPORT_PATH` is gitignored via `.claude/*.local.*` and persists for the user to keep and reference.

## Plan-approved continuation

If a research/plan-only run has finished and the user then approves implementing it (e.g. "ok", "go ahead", "implement it"), do NOT edit code in the main thread. Re-enter the pipeline at Phase 3: re-activate the state file (re-run `init-orchestration.sh` with the task, re-persist the approved intent via `--set-intent-*`, then `update-orchestration-state.sh --phase implementation --agent Orchestrator --message "Plan approved — resuming at Phase 3"`), dispatch Loid with the approved plan (from the report / `.claude/agent-reports/`), then run Phases 4–6 (Lawliet + Codex, Alphonse, Report) as normal.
