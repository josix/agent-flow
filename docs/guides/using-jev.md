---
title: Using the JEV intent signal in Phase 4
---

# Using the JEV intent signal in Phase 4

## What the JEV signal adds (and what it is not)

JEV (typesafe.ai "System One") is a narrow, typed classifier: given the task
Goal/Constraints/Description and a diff, it answers four Noul (boolean +
calibrated probability) questions. When opted in, `/orchestrate` dispatches
it as an **advisory-only** shadow signal alongside Lawliet, Codex, and
Alphonse in Phase 4.

**What it is not:**
- Not a reviewer. It never produces a `file:line` finding, and it can never
  cause a `NEEDS_CHANGES` verdict, block, or trigger a fix round.
- Not fact-checked. "Type safety is not factual correctness" — the same
  critique applied to typed-answer classifiers on Hacker News (HN 49717558)
  applies here: a well-calibrated probability about an ambiguous typed
  question is still not a guarantee the diff is correct.
- Not a replacement for Lawliet's `intent-mismatch` check, which stays the
  authoritative gate. JEV output is never shown to Lawliet or Loid, so it
  never contaminates that label.
- Vendor-claimed calibration. It was measured once, on a small P0 eval set
  built from this repo's own history, with low statistical confidence
  (`unrelated_changes` precision 0.882, CI [0.657, 0.967]). Treat every score
  as unverified until the shadow log accumulates enough real runs to
  re-evaluate.

## Opt in

Set both before launching Claude Code:

```bash
export AGENT_FLOW_JEV=1
export TYPESAFE_API_KEY=<your key>
claude  # then run /agent-flow:orchestrate "..."
```

Unlike Codex co-review, JEV is never enabled just because a key happens to be
present — `AGENT_FLOW_JEV=1` is required, so a key exported for another tool
never silently starts sending diffs to a new vendor.

## Environment variables

| Var | Default | Purpose |
|---|---|---|
| `AGENT_FLOW_JEV` | unset | Opt-in (must be `1`) |
| `AGENT_FLOW_NO_JEV` | unset | Per-run kill switch; wins over the opt-in |
| `AGENT_FLOW_JEV_API_KEY_ENV` | `TYPESAFE_API_KEY` | Name of the env var holding the API key |
| `AGENT_FLOW_JEV_MODEL` | `jev-1.13.0` | Pinned model id |
| `AGENT_FLOW_JEV_BASE_URL` | `https://api.typesafe.ai` | Override for a self-hosted or open-alternative endpoint (and for tests) |
| `AGENT_FLOW_JEV_THRESHOLD` | `0.8` | τ; valid range 0.5–1.0 |
| `AGENT_FLOW_JEV_TIMEOUT` | `20` (seconds) | `curl --max-time` |
| `AGENT_FLOW_JEV_MAX_DIFF_CHARS` | `90000` | Diff size cap (live 400 `max_tokens_exceeded` responses were seen between 100000–150000 chars) |
| `AGENT_FLOW_JEV_MAX_FILE_BYTES` | `100000` | Per-untracked-file size guard |

## Data boundary

**Sent:** the task Goal, Constraints, and Description (from
`intent:` in the orchestration state file), plus the diff under review
(size-capped; secret-like and artifact paths listed as omitted, never
inlined). The request always covers the full change — JEV never receives
`--diff-base`-scoped fix-only diffs, because the questions judge the whole
change against the Goal.

**Never sent:** `intent.actions`, `intent.assumptions`, the raw task text
once a Goal is set, any plan or agent report, Lawliet's or Codex's output, or
the API key outside the `Authorization` header (which itself reaches curl
only via `--config -` on stdin — never argv, a file, or stdout/stderr).

Before every network call, the dispatcher scans the assembled request text
for secret-pattern signatures (AWS keys, PEM private key headers, common
vendor token prefixes) and aborts with no network call on a match.

**Do not enable the JEV signal in repositories with the same constraints
listed in [Using Codex co-review](using-codex-review.md#data-boundary--what-leaves-your-machine).**

## Surfaced vs record-only questions

| Question | Surfaced as INFO advisory? |
|---|---|
| `addresses_task` | Yes |
| `unrelated_changes` | Yes |
| `needs_clarification` | No — record-only (every P0 flag was a false positive) |
| `security_surface` | No — record-only (unlabeled in P0) |

## Cost and latency

P0 measurements: p95 latency 688ms, cost $0.00041 per diff. Both are
recorded per-dispatch in the shadow log for ongoing monitoring.

## Skip reasons / degraded mode

The dispatcher always exits 0 and degrades gracefully — a JEV failure never
blocks Phase 4. Skip reasons include `not_enabled`, `disabled` (kill switch),
`unavailable`, `missing_dep`, `no_key`/`bad_key`, `bad_url`, `no_diff`,
`secret_suspected`, `timeout`, `network`, `too_large`, `auth`,
`bad_request`, `rate_limited`, `overloaded`, `http_<code>`, and `error`. See
`skills/verification-gates/references/jev-signal.md` for the full table.

## Shadow log and re-evaluation

Every dispatch and every Phase 6 report appends one JSON line to
`.claude/jev/shadow-log.jsonl` (gitignored). This is the calibration dataset
for re-evaluating JEV once enough real runs accumulate — nothing is sent
anywhere from this file; it stays local.

## Team mode not supported

`/agent-flow:team-orchestrate` is deprecated and forwards to `/orchestrate`;
the JEV signal, like Codex co-review, is only wired into the
`/orchestrate` pipeline.

## Testing this integration

```bash
bash scripts/test-detect-jev-context.sh
bash scripts/test-dispatch-jev-review.sh
node scripts/test-implement-review-verify.js
bash scripts/validate-plugin.sh
```

Every test stubs `curl` and pins `AGENT_FLOW_JEV_BASE_URL` to an
`.invalid` domain — no test ever makes a real network call or sends a real
API key.
