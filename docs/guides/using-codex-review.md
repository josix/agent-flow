---
title: Using Codex co-review in Phase 4
---

# Using Codex co-review in Phase 4

## What Codex co-review adds

Under the standard and thorough profiles, when the Codex CLI is installed and authenticated, `/orchestrate` enlists it as a second reviewer in Phase 4 alongside Lawliet. Lawliet provides linter-grounded static analysis via Claude Sonnet (including an **intent-fidelity check** that flags `intent-mismatch` when the patch passes static analysis but doesn't satisfy the stated Goal/Constraints); Codex brings OpenAI's model perspective. The two verdicts are reconciled by the [disagreement protocol](#disagreement-protocol) below.

Phases 3–5 run as the plugin workflow `agent-flow:implement-review-verify`. Lawliet, Codex and Alphonse are dispatched **in parallel**; Codex goes through `scripts/dispatch-codex-review.sh`. Codex is skipped under `fast`, and when `codex.available` is false. (`/agent-flow:team-orchestrate` is deprecated and forwards to `/orchestrate`.)

## Install

Choose one of the following:

```bash
# macOS (Homebrew Cask)
brew install --cask codex

# npm (global)
npm i -g @openai/codex
```

## Auth

Codex authenticates via your ChatGPT subscription — no separate API key is required.

```bash
codex login
```

Follow the browser prompt. When login completes, Codex writes an auth artifact to `~/.codex/`. The detector looks for `~/.codex/auth.json` (or `~/.codex/session.json` as a fallback).

## How to verify

Run the detector directly to confirm availability:

```bash
bash scripts/detect-codex-context.sh
```

Expected output when Codex is ready:

```yaml
codex:
  available: true
  binary: "/usr/local/bin/codex"
  auth_present: true
```

If `available: false`, check the stderr message — it will tell you whether the binary is missing or auth is absent.

## Data boundary — what leaves your machine

Every Phase 4 review with Codex enabled transmits the following to OpenAI's
servers via your authenticated Codex CLI session:

- The full diff under review (`git merge-base HEAD <default-branch>..HEAD` plus
  any uncommitted working-tree changes), or — in re-reviews after a fix round — only
  the changes since the previous round (`--diff-base <rev>`). Only untracked
  files created or modified during this run are inlined — files that already
  existed before the run (per the snapshot taken at Phase 3 start) are left
  out and only counted. Untracked binaries, artifact/scratch directories, and
  files over `AGENT_FLOW_CODEX_MAX_FILE_BYTES` are listed as omitted rather
  than inlined; secret-like filenames (`.env`, `*.pem`, `id_rsa*`, ...) are
  never inlined; a diff over `AGENT_FLOW_CODEX_MAX_DIFF_CHARS` is replaced by
  `git diff --stat`.
- The task description as recorded in the orchestrator's state file
  `.claude/orchestration.local.md` (the shared helper accepts the path via
  `--state-file`).
- Lawliet's review reply is **not** sent in the default parallel flow. It is
  included only when the orchestrator runs Codex sequentially after Lawliet
  (e.g. re-checking a disputed finding) via `--lawliet-findings`.

**Do not enable Codex co-review in repositories that contain:**
- Regulated data (PII, PHI, payment data, etc.)
- Secrets, credentials, or API keys (even in `.env.example` or test fixtures)
- Proprietary algorithms or third-party code under restrictive licenses
- Any code your organization's data-handling policy prohibits from leaving
  the perimeter

## Configuration

| Env var | Default | Effect |
|---------|---------|--------|
| `AGENT_FLOW_NO_CODEX` | unset | Any non-empty value (e.g. `1`) skips Codex for the Claude Code session. Must be set when Claude Code starts, not at slash-command time (`AGENT_FLOW_NO_CODEX=1 claude`). The detector then records `available: false`. |
| `AGENT_FLOW_CODEX_MODEL` | unset | Model passed to `codex exec -m`; overrides `model` in `~/.codex/config.toml`. |
| `AGENT_FLOW_CODEX_TIMEOUT` | `480` | Seconds before the helper reports `timeout` (needs `timeout` or `gtimeout`; see [Parallel dispatch](#parallel-dispatch-and-review-fix-rounds)). |
| `AGENT_FLOW_CODEX_MAX_FILE_BYTES` | `100000` | Untracked files larger than this (plus binaries and common artifact dirs) are listed as omitted instead of inlined. |
| `AGENT_FLOW_CODEX_MAX_DIFF_CHARS` | `800000` | If the assembled diff exceeds this, Codex receives `git diff --stat` instead and reads the files itself. |
| `AGENT_FLOW_CODEX_INLINE_UNTRACKED` | `1` | Set to `0` to disable inlining untracked files entirely when the untracked-file baseline (below) is missing or stale. |

The model is resolved in this order: `AGENT_FLOW_CODEX_MODEL`, then the top-level `model` in `${CODEX_HOME:-~/.codex}/config.toml`, then no `-m` flag (Codex picks its default). The explicit `-m` is needed because `--ignore-user-config` would otherwise drop your configured model. Codex runs with `model_reasoning_effort=high`.

To opt out permanently, run `codex logout`; Phase 4 then reverts to Lawliet-only with no other changes.

### Prompt size and scope guards

Codex rejects prompts over roughly 1M characters, so the helper caps what it inlines (see [Configuration](#configuration)).

Before Phase 3 begins, `scripts/snapshot-untracked.sh` records every untracked
file already in the working tree (`.claude/review-baseline-untracked.local.txt`,
tied to the run's `started_at`). `dispatch-codex-review.sh` reads that
baseline and skips any untracked file that predates this run and hasn't been
touched since — so Codex only sees files this run actually created or edited,
not pre-existing clutter (aider chat history, doc-site exports, other
tickets' scratch notes, ...). The helper also excludes an extended set of
artifact/scratch paths (`tmp/`, `.aider*`, `*-results.json`, patch/diff
leftovers, doc-site/coverage build output, `.senku/`, logs, DBs) and never
inlines a secret-like filename, using the same basename set as
`hooks/scripts/validate-changes.sh`.

**Fallback:** if no baseline exists yet, or it doesn't match this run's
`started_at` (stale — e.g. the dispatcher was run directly, or the snapshot
task failed), the helper falls back to inlining untracked files as before
(still subject to the guards above) and prints a `warn:` line. Set
`AGENT_FLOW_CODEX_INLINE_UNTRACKED=0` to disable inlining entirely in that
fallback instead. Every run reports which path was taken via a new,
informational `codex_untracked: inlined=<n> preexisting=<n> artifact=<n>
secret=<n> oversize_or_binary=<n> baseline=<used|missing|stale>` line — no
existing output key changes.

## Cost note

Each Codex invocation during Phase 4 counts against your ChatGPT subscription's usage allotment. Higher reasoning effort and larger prompts (bigger diffs) increase per-review token usage. Cost scales with diff size; review-fix rounds send only the fix diff (`--diff-base`). Be aware of this if you are on a plan with limited allotment.

## Parallel dispatch and review-fix rounds

Codex runs as a third parallel reviewer next to Lawliet and Alphonse — it does
not wait for Lawliet and does not receive Lawliet's findings. The plugin
rubric (`templates/codex/review-rubric.md`) tells Codex to skip linter-level work (Lawliet's domain), so the two
reviews stay complementary. Codex wall-time (up to `AGENT_FLOW_CODEX_TIMEOUT`
seconds, default 480, when `timeout` or `gtimeout` is installed; unbounded
without either, with a warning on stderr) overlaps with the other two
reviewers instead of adding to Phase 4+5.

In the workflow path Codex runs in a foreground Bash call. The Bash tool caps
calls at 600000 ms (10 min) unless `BASH_MAX_TIMEOUT_MS` is raised, so values
above ~540 need that too. When the cap is lower than the configured timeout
needs, the workflow's Codex step clamps `AGENT_FLOW_CODEX_TIMEOUT` to the cap
minus 60 s for that call, so the helper reports a clean `timeout` (ADVISORY)
instead of being killed mid-run with no output.

In re-reviews after a fix round, the helper is called with `--diff-base <rev>` so Codex
reviews only the fix, not the whole branch again.

## Disagreement protocol

**Disagreement rule:** See the canonical truth table in
`skills/verification-gates/references/codex-co-review.md` (loaded by `/orchestrate` Phase 4). The summary: any cited Lawliet
ERROR/WARNING blocks (even under APPROVED); Codex flips the verdict only with a `file:line`-cited ERROR/WARNING — INFO
is advisory; Codex runs only under standard/thorough with `codex.available: true`.

### Divergence Cap

If Lawliet keeps approving with no cited ERROR/WARNING while Codex keeps citing the same `file:line` findings and verification is clean, the orchestrator counts divergence rounds (`codex_divergence_rounds`). After 2 in a row it stops re-dispatching Loid and asks you: Accept Codex / Accept Lawliet / give guidance (default Lawliet). On the workflow path this returns `status: divergence`; a standoff that repeats at the round cap is reported as `capped`. Mechanics: `skills/verification-gates/references/codex-co-review.md`.

## Degraded mode

If `codex exec` fails at runtime, the dispatch helper degrades gracefully
instead of blocking Phase 4. On a timeout (exit 124 under the `AGENT_FLOW_CODEX_TIMEOUT`
`timeout`/`gtimeout` cap) it emits `codex_skip_reason: timeout`; on any other
non-zero exit (e.g. an auth failure) it emits `codex_skip_reason: error`. In
both cases the helper reports `codex_verdict: ADVISORY` alongside
`codex_ran: true`, `codex_exit`, and `codex_raw_path`, and the run proceeds
with Lawliet-only reconciliation. When Codex is not available at all, the
helper emits `codex_ran: false` with `codex_skip_reason: unavailable`. The
header comment of `scripts/dispatch-codex-review.sh` is the authoritative
output contract.

## Review rubric

The rubric — Codex's role next to Lawliet, the output contract (one verdict line plus `SEVERITY: file:line: issue` findings), the severity scale, what to defer to Lawliet, re-review scope, and the tie-breaker — ships with the plugin at `templates/codex/review-rubric.md`. `scripts/dispatch-codex-review.sh` inlines it at the top of every review prompt, so Codex follows the same contract in any project, not only in repos that carry an `AGENTS.md`.

A project may still add its own `AGENTS.md`; Codex auto-loads it, and its repo-specific checklist applies on top of the rubric. agent-flow's own `AGENTS.md` is such a checklist (shell safety, heredoc expansion, YAML validity, hardcoded paths, secrets, hook output contracts, workflow script rules).

Note that Claude Code loads a project's `AGENTS.md` as its instructions when the project has no `CLAUDE.md` (the "Project instructions" setting, default `claude-md-or-agents-md`). Keep a `CLAUDE.md` (or `.claude/CLAUDE.md`, as agent-flow does) in any repo whose `AGENTS.md` is written for Codex, so Claude sessions don't adopt the reviewer role.

??? note "For contributors: testing this integration"

    The Codex co-review surface can be smoke-tested with:

    ```bash
    # Syntax check the shell scripts
    bash -n scripts/detect-codex-context.sh
    bash -n scripts/init-orchestration.sh

    # Verify detector emits valid YAML in three states
    bash scripts/detect-codex-context.sh                          # Normal (binary + auth detected)
    AGENT_FLOW_NO_CODEX=1 bash scripts/detect-codex-context.sh    # Opt-out path
    PATH=/usr/bin bash scripts/detect-codex-context.sh            # Codex unavailable path

    # Dry-run init in a temp dir
    cd $(mktemp -d) && bash /path/to/agent-flow/scripts/init-orchestration.sh "dummy task"
    grep -A3 '^codex:' .claude/orchestration.local.md
    ```

    Expected: each detector invocation emits exit code 0 and a `codex:` YAML block; `init-orchestration.sh` writes the block into `.claude/orchestration.local.md` between `personal_kb:` and `gates:`.

    ```bash
    # Verify the shared helper is syntactically valid and gates on availability
    bash -n /path/to/agent-flow/scripts/dispatch-codex-review.sh

    # Helper smoke test with codex.available: false
    printf 'codex:\n  available: false\n  binary: ""\n  auth_present: false\ntask: "dummy"\n' > /tmp/fake-state.md
    : > /tmp/empty-findings.md
    bash /path/to/agent-flow/scripts/dispatch-codex-review.sh \
      --state-file /tmp/fake-state.md \
      --lawliet-findings /tmp/empty-findings.md
    # Expected: prints "codex_ran: false" and "codex_skip_reason: unavailable"
    # on stdout, exit code 0
    ```

## Reporting issues

If the Codex co-review misbehaves (timeouts, mis-parsed verdicts, false BLOCKED, data-egress concerns), please open an issue at https://github.com/josix/agent-flow/issues with:
- The output of `bash scripts/detect-codex-context.sh`
- The `codex:` block from `.claude/orchestration.local.md`
- The relevant Codex stderr lines (look for `warn:` prefixes from Phase 4)
