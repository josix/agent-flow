# Intent Ledger

Loaded on demand by `/orchestrate` Phase 6 (and the Research Short-Circuit) before emitting the completion promise.

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
