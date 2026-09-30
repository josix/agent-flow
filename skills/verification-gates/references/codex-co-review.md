# Codex co-review (optional)

Loaded on demand by `/orchestrate` Phase 4 before launching Codex or reconciling its verdict with Lawliet's.

Check whether Codex is available:

```bash
CODEX_AVAILABLE=$(grep -A1 '^codex:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

**When `CODEX_AVAILABLE` is `true`**, run Codex as a co-reviewer via Bash (NOT a subagent dispatch — Codex is an external CLI):

In the default parallel flow (Phase 4 + 5), launch the helper with Bash `run_in_background: true`, without `--lawliet-findings`, writing its key/value output to a file:

```bash
mkdir -p .claude/codex
bash ${CLAUDE_PLUGIN_ROOT}/scripts/dispatch-codex-review.sh \
  --state-file .claude/orchestration.local.md > .claude/codex/codex-result.txt
```

On every review after a fix round, append `--diff-base "$REVIEW_BASE"` so Codex reviews only the fix. The helper also guards prompt size: untracked artifacts/binaries/files over `AGENT_FLOW_CODEX_MAX_FILE_BYTES` (default 100000) are listed as omitted rather than inlined, and a diff over `AGENT_FLOW_CODEX_MAX_DIFF_CHARS` (default 800000) is replaced by `git diff --stat` for Codex to read files itself — previously oversized diffs hit Codex's ~1M-char input cap and degraded Phase 4 to ADVISORY.

The helper also scopes untracked files to this run: it reads `.claude/review-baseline-untracked.local.txt` (written by `scripts/snapshot-untracked.sh` before Phase 3) and skips any untracked file that already existed before this run and hasn't been modified since (counted, not listed, in a `# N untracked file(s) that existed before this run...` summary line). It also excludes an extended set of artifact/scratch paths (`tmp/`, `.aider*`, `*-results.json`, patch/diff leftovers, doc-site/coverage build output, `.senku/`, logs, DBs) and never inlines a secret-like basename (`.env`, `*.pem`, `id_rsa*`, ...; same set as `hooks/scripts/validate-changes.sh`). When no baseline exists or it doesn't match this run's `started_at`, the helper falls back to inlining all untracked files (still subject to the guards above) and prints a `warn:` line; set `AGENT_FLOW_CODEX_INLINE_UNTRACKED=0` to disable inlining entirely in that fallback instead. A new informational `codex_untracked: inlined=<n> preexisting=<n> artifact=<n> secret=<n> oversize_or_binary=<n> baseline=<used|missing|stale>` line is added to stdout; no existing key changes.

When its completion notification arrives, set `CODEX_RESULT=$(cat .claude/codex/codex-result.txt)` and parse it with the same `CODEX_RAN` / `CODEX_VERDICT` / `CODEX_RAW_PATH` lines shown below. Skip the persistence step below; it is only for running Codex after Lawliet (e.g. re-checking a disputed finding).

When running Codex after Lawliet, the orchestrator MUST first persist Lawliet's findings to a fixed well-known path so the Codex dispatch can include them. Lawliet's full markdown response lives in the orchestrator's conversation memory — use the Write tool to write Lawliet's full markdown response verbatim to `.claude/codex/lawliet-findings.tmp.md` before running the dispatch block below. Create the directory if needed: `mkdir -p .claude/codex`.

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

The output contract and severity scale are defined in the plugin rubric `templates/codex/review-rubric.md`, which the helper inlines at the top of every Codex prompt (so it applies in any project). A project's own `AGENTS.md`, which Codex auto-loads, adds repo-specific checks on top.

If the shared helper (`scripts/dispatch-codex-review.sh`) detects that `codex exec` exited non-zero (timeout, auth failure, network), Phase 4 falls back to Lawliet-only — the helper exits 0 but emits `codex_verdict: ADVISORY` so the orchestrator can detect the degraded state. The final verdict is whatever Lawliet emitted.

The helper builds the diff, task description, and (only when `--lawliet-findings` is passed) Lawliet's findings internally. `$CODEX_RAW` contains Codex's full reply (as written by `--output-last-message`): the first non-blank line is the verdict (`APPROVED` / `NEEDS_CHANGES` / `BLOCKED`); subsequent lines of the form `<severity>: <file>:<line>: <issue>` are findings. Findings without a `file:line` token are advisory only and cannot trigger a NEEDS_CHANGES verdict. If the first non-blank line is not one of `APPROVED`, `NEEDS_CHANGES`, or `BLOCKED`, treat the entire Codex output as advisory and log `warn: Codex verdict unparseable — treating as advisory`.

**Findings without a `file:line` citation are advisory only** — they do not affect the final verdict and Loid is NOT routed back for them.

## Disagreement rule (truth table)

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

## Divergence Cap (Lawliet/Codex standoff)

**In the workflow path** (`workflows/implement-review-verify.js`) the cap is enforced in code: the run returns `status: "divergence"` when Lawliet is `APPROVED`, verification is clean, and the Codex-only blocking citations are identical to the previous round's — i.e. the second consecutive round of the same standoff. The state counter below applies only to the manual, turn-by-turn flow.

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

**When `DIV` reaches 2:** STOP looping — do NOT re-dispatch Loid again for the same standoff. Call **AskUserQuestion** (mirroring the Assumption Escalation Gate pattern in `/orchestrate`) presenting the persistent Codex citation and Lawliet's `APPROVED` stance, with options:
- **A)** Accept Codex — route to Loid to fix the cited issue.
- **B)** Accept Lawliet — proceed to Phase 5.
- **C)** Provide guidance.

**Default when unanswered: B** (favor Lawliet, matching the truth table's linter-grounded bias).

After the standoff is resolved (either by user answer or by a genuine new issue breaking the loop), reset the counter: `--set-codex-divergence-rounds 0`.

## When Codex is unavailable

**When `CODEX_AVAILABLE` is `false`**, skip the Codex co-review entirely. Phase 4 behaves identically to today (Lawliet-only). Log one info line:

```
info: Codex co-review skipped (codex.available: false)
```
