# JEV intent signal (optional, opt-in, shadow-mode, advisory)

Loaded on demand by `/orchestrate` Phase 4 (dispatch) and Phase 6 (reporting).

JEV (typesafe.ai "System One") answers four narrow, typed questions about the
full change against the stated intent. It is **not** a reviewer: it never
produces a `file:line` finding, never changes the Phase 4 truth table, never
blocks, and never triggers a fix round. Its calibration is vendor-claimed and
was measured on a small P0 eval set with low confidence — treat every score
as unverified until more real-run data accumulates in the shadow log.

## Availability check

```bash
JEV_AVAILABLE=$(grep -A1 '^jev:' .claude/orchestration.local.md | grep 'available:' | sed 's/.*available: *//')
```

A missing `jev:` block (legacy state file) reads as unavailable, the same
defensive-grep pattern as `codex-co-review.md:8`.

## What runs, and when

- All profiles (fast, standard, thorough) when `jev.available: true` — including
  `fast`, where Codex is skipped. JEV is cheap enough to always run.
- In parallel with Lawliet, Codex (if enabled) and Alphonse — every Phase 4 round,
  on the full change (never `--diff-base`; the questions judge the whole diff
  against the Goal, and a fix-only diff would score `addresses_task` low by
  construction).
- Opt-in only: `AGENT_FLOW_JEV=1` plus an API key in the env var named by
  `AGENT_FLOW_JEV_API_KEY_ENV` (default `TYPESAFE_API_KEY`). Unlike Codex, JEV
  is never on just because a binary/key happens to be present — a stray key
  set for another tool should not start sending diffs to a new vendor.
  `AGENT_FLOW_NO_JEV=1` is a per-run kill switch that wins over the opt-in.

## The workflow path

Pass `jev: true` in the `implement-review-verify` workflow call args when
`jev.available: true`. The workflow adds the task itself; there is nothing
else to do.

## The manual path (Phase 4 + 5 run turn by turn)

Dispatch in the background alongside Lawliet/Codex/Alphonse:

```bash
mkdir -p .claude/jev
bash ${CLAUDE_PLUGIN_ROOT}/scripts/dispatch-jev-review.sh \
  --state-file .claude/orchestration.local.md --round <N> > .claude/jev/jev-result.txt
```

Parse the key/value output (`jev_ran`, `jev_skip_reason`, `jev_over_threshold`,
`jev_surfaced`, the four `jev_score_<id>` lines, `jev_model`, `jev_threshold`,
`jev_truncated`, `jev_latency_ms`). Only ids in `jev_surfaced` become INFO
advisories — `jev_over_threshold` also includes record-only ids, which are
recorded in history but never surfaced.

## Stdout contract and skip reasons

```
jev_ran: true|false
jev_skip_reason: <reason>            (only when jev_ran: false)
jev_questions_version: v1
jev_model: <id>
jev_threshold: <tau>
jev_truncated: true|false
jev_score_addresses_task: <0..1>
jev_score_unrelated_changes: <0..1>
jev_score_needs_clarification: <0..1>
jev_score_security_surface: <0..1>
jev_over_threshold: none|<comma-separated ids>
jev_surfaced: none|<comma-separated ids>     (subset of over_threshold; surface:true only)
jev_latency_ms: <int>
```

Skip reasons: `bad_mode`, `disabled` (kill switch), `not_enabled` (no opt-in),
`unavailable`, `missing_dep` (curl/jq), `questions_missing`, `no_key`,
`bad_key`, `bad_url`, `no_diff`, `secret_suspected`, `timeout`, `network`,
`too_large` (HTTP 400 `max_tokens_exceeded`), `auth`, `bad_request`,
`rate_limited`, `overloaded`, `http_<code>`, `error` (malformed response).
Every path exits 0.

## Surfaced vs record-only, and why

Only `addresses_task` (low polarity) and `unrelated_changes` (high polarity)
surface as INFO advisories. `needs_clarification` and `security_surface` are
record-only (written to the shadow log, never surfaced) because the P0 eval
set showed `needs_clarification` producing false positives on every recorded
flag, and `security_surface`'s calibration is unlabeled. `templates/jev/questions.v1.json`
marks each question with `surface: true|false`; the workflow enforces a
matching code-side allowlist (`JEV_SURFACE` in `workflows/implement-review-verify.js`)
so a Bash-agent parse drift can never surface a record-only question.

## The rules (advisory only)

- JEV never produces a finding with `file:line`.
- JEV never causes a `NEEDS_CHANGES` verdict.
- JEV never triggers a fix round or is added to `open`/`toFix`.
- JEV output is never passed to Loid or Lawliet — this keeps Lawliet's
  `intent_mismatch` label usable as an independent calibration signal.

## The Phase 6 record block

After the workflow returns (or the manual Phase 4+5 flow completes), run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/record-jev-shadow.sh --state-file .claude/orchestration.local.md <<'JEV_OUTCOME_EOF'
{"status": "<workflow status>", "profile": "<profile>", "history": <the workflow result's history array, verbatim JSON>}
JEV_OUTCOME_EOF
```

The quoted heredoc delimiter is intentional — the body is literal JSON with
no `$VAR` references (`AGENTS.md`, heredoc blocker class).

## The data boundary

- **Sent:** Goal, Constraints and Description (from `intent:`), plus the diff
  (capped at `AGENT_FLOW_JEV_MAX_DIFF_CHARS`, default 90000 chars — live 400s
  were seen between 100000 and 150000; secret-like paths and artifact paths
  are omitted, never inlined; the run aborts before any network call if a
  secret pattern is detected in the assembled text).
- **Never sent:** `intent.actions`, `intent.assumptions`, the raw `task` text
  (once a Goal is set), any plan or agent report, Lawliet's or Codex's output,
  or the API key outside the `Authorization` header (which itself only
  reaches curl via `--config -` on stdin, never argv/a file/stdout/stderr).

## When JEV is unavailable

Log one info line and continue — Phase 4 behaves identically to today:

```
info: JEV signal skipped (jev.available: false)
```

## Shadow log and re-evaluation

`.claude/jev/shadow-log.jsonl` (gitignored) accumulates one `"kind":"score"`
line per dispatch and one `"kind":"outcome"` line per Phase 6 report. Re-run
the P0-style calibration against this log once at least 20 real runs have
accumulated, before considering P2a (gate mode). See
`.claude/agent-reports/senku-jev-integration-plan.md` section 3 for the
P0 exit criteria this reuses.
