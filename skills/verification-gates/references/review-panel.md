# Review panel (multi-lens, cross-examined)

Loaded on demand by `/orchestrate` Phase 4 when the run has a review panel. The workflow (`workflows/implement-review-verify.js`) runs all of this itself; follow this page by hand only on the manual path.

## When it runs

- Profiles **standard** and **thorough**, when state `review_panel` is non-empty. **fast** stays Lawliet-only.
- `review_panel` is set by `init-orchestration.sh`: all four lenses by default, `--review-panel <list|none>` or `AGENT_FLOW_REVIEW_PANEL` to change it.

## Reviewers

Lawliet keeps static analysis (types, lint, semgrep, complexipy) and intent fidelity. Each lens is a read-only `agent-flow:Lawliet` dispatch narrowed to one angle. Lenses do not run linters or report style nits.

| Lens | Looks for |
|---|---|
| `correctness` | logic errors; edge cases (empty, null, boundaries, ordering, concurrency, reruns); error handling that hides failures; data consistency |
| `security` | secrets and credentials; permissions; injection; guards on deletes, production operations and other irreversible writes; missing dry-run, confirmation or rollback |
| `maintainability` | fit with the repo's architecture and patterns; duplication; naming; unnecessary complexity |
| `tests` | whether new and changed behaviour is tested; tests that assert real behaviour, not mocks; regression tests for the bug fixed |

Every ERROR/WARNING must cite `file:line` and state the concrete failure (inputs or state → wrong result), because the other reviewers will check it.

## Cross-examination

1. **Pool** every cited ERROR/WARNING from Lawliet, the lenses and Codex (when enabled). Findings at the same `file:line` merge into one candidate: the higher severity wins and every author is listed.
2. **Vote.** Each panel member (Lawliet and every lens) receives the candidates it did not raise and, after reading the cited code itself, votes on each: `ACCEPT` (real and worth fixing now), `REJECT` (wrong, unreachable, out of scope, or not worth fixing now) or `MODIFY` (real, but the issue or fix should differ; say how), with a one-sentence reason. Authors never vote on their own finding. Codex raises findings but does not vote.
3. **Adopt** by majority of the votes cast by non-authors. `MODIFY` counts as agreement, and its note goes to Loid with the finding.
   - More agree than half → adopted, sent to Loid.
   - Exactly half → an ERROR is kept (the conservative choice); a WARNING is rejected.
   - Fewer than half → rejected.
   - No votes cast (every voter failed) → kept.
4. **Not put to a vote:** Lawliet's uncited `intent-mismatch` and Alphonse's failures. Both go straight to Loid.

INFO findings never trigger a fix round and are not voted on; they go to the report as advisory.

## Rounds

Each fix round re-runs Lawliet and the lenses on the fix diff (`git diff $REVIEW_BASE` plus new untracked files) and cross-examines the new findings the same way. The profile's round cap (1 / 2 / 3, plus at most one extra round when ERRORs dropped) still bounds the loop. The Codex truth table and the Divergence Cap do not apply with a panel: the vote settles disagreements.

## What the report must show

- **Rejected by the review panel:** each rejected finding with its authors, the tally (e.g. `rejected 2/3`) and every voter's reason, so the user can overrule the panel.
- **Review degraded:** every reviewer that was meant to run but did not (a lens or a vote failed, Codex did not run and why). Name it in the report's first line as a caveat; a run with a degraded review is "done with caveats", not "done".

## Manual path

Dispatch Lawliet, each lens, Alphonse and (if enabled) Codex in one turn. When they report, build the candidate list, dispatch one vote per panel member that has candidates to judge (in one turn), apply the adoption rule above, and send Loid only the adopted findings plus any intent mismatch and verification failures.
