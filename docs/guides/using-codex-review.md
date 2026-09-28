---
title: Using Codex co-review in Phase 4
---

# Using Codex co-review in Phase 4

## What Codex co-review adds

When the Codex CLI is installed and authenticated, the `/orchestrate` command automatically enlists it as a second reviewer in Phase 4 alongside Lawliet. This gives you a cross-vendor second opinion on every diff: Lawliet provides linter-grounded static analysis via Claude Sonnet (including an **intent-fidelity check** that flags `intent-mismatch` when the patch passes static analysis but doesn't satisfy the stated Goal/Constraints), while Codex brings OpenAI's model perspective. The two verdicts are reconciled by the disagreement protocol described below, so you get stronger signal without any extra steps in your workflow.

Inside `/agent-flow:orchestrate`, Phases 3–5 run as the plugin workflow
`/agent-flow:implement-review-verify` (`workflows/implement-review-verify.js`).
Lawliet, Codex, and Alphonse are dispatched **in parallel** in the Review &
Verify step; Codex goes through the shared helper
`scripts/dispatch-codex-review.sh`. Codex runs only when the orchestrator's
Execution Profile allows it (skipped under `fast`) and `codex.available: true`.
(`/agent-flow:team-orchestrate` is deprecated and simply forwards to
`/orchestrate`.)

## Data boundary — what leaves your machine

Every Phase 4 review with Codex enabled transmits the following to OpenAI's
servers via your authenticated Codex CLI session:

- The full diff under review (`git merge-base HEAD <default-branch>..HEAD` plus
  any uncommitted working-tree changes), or — in review-fix rounds 2+ — only
  the changes since the previous round (`--diff-base <rev>`). Untracked
  binaries, artifact directories, and files over `AGENT_FLOW_CODEX_MAX_FILE_BYTES`
  are listed as omitted rather than inlined; a diff over
  `AGENT_FLOW_CODEX_MAX_DIFF_CHARS` is replaced by `git diff --stat`.
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

### AGENT_FLOW_CODEX_MODEL

Override the model passed to `codex exec -m`. Set this before launching Claude Code
if your account requires a specific model that differs from the value in `~/.codex/config.toml`:

```bash
export AGENT_FLOW_CODEX_MODEL=gpt-5.5
claude  # then run /agent-flow:orchestrate "..."
```

When set, this takes precedence over the `model` key in `~/.codex/config.toml`.
When neither is set, no `-m` flag is passed and Codex uses its built-in default.

### AGENT_FLOW_NO_CODEX

To opt out for a single run without uninstalling, set the env var when
launching Claude Code (the env var must be present at Claude Code startup, not
at slash-command invocation time):

```bash
# Option 1: Export before launching Claude Code
export AGENT_FLOW_NO_CODEX=1
claude  # then run /agent-flow:orchestrate "..."

# Option 2: Inline for a single Claude Code session
AGENT_FLOW_NO_CODEX=1 claude
# then run /agent-flow:orchestrate "..." inside that session
```

To opt out permanently, run `codex logout`. The orchestrator falls back to
Lawliet-only Phase 4 with no further changes.

The detector (`scripts/detect-codex-context.sh`) is invoked by the init script
and bakes `available: false` into `.claude/orchestration.local.md` when the env
var is set at Claude Code startup.

### Prompt size guards

Codex rejects prompts over roughly 1M characters, so the helper caps what it
inlines:

| Env var | Default | Effect |
|---------|---------|--------|
| `AGENT_FLOW_CODEX_MAX_FILE_BYTES` | `100000` | Untracked files larger than this (plus binaries and common artifact dirs) are listed as omitted instead of inlined. |
| `AGENT_FLOW_CODEX_MAX_DIFF_CHARS` | `800000` | If the assembled diff exceeds this, Codex receives `git diff --stat` instead and reads the files itself. |

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

## Opt out

Codex co-review is availability-gated: if Codex is not installed or not logged in, Phase 4 behaves identically to a Lawliet-only review. No configuration change is needed.

To explicitly opt out after installing Codex:

```bash
codex logout
```

The detector will then emit `available: false` and Phase 4 reverts to Lawliet-only.

## Cost note

Each Codex invocation during Phase 4 counts against your ChatGPT subscription's usage allotment. Higher reasoning effort and larger prompts (bigger diffs) increase per-review token usage. Cost scales with diff size; review-fix rounds send only the fix diff (`--diff-base`). Be aware of this if you are on a plan with limited allotment.

## Parallel dispatch and review-fix rounds

Codex runs as a third parallel reviewer next to Lawliet and Alphonse — it does
not wait for Lawliet and does not receive Lawliet's findings. The `AGENTS.md`
rubric tells Codex to skip linter-level work (Lawliet's domain), so the two
reviews stay complementary. Codex wall-time (up to `AGENT_FLOW_CODEX_TIMEOUT`
seconds, default 480, when `timeout` or `gtimeout` is installed; unbounded
without either, with a warning on stderr) overlaps with the other two
reviewers instead of adding to Phase 4+5.

In review-fix rounds 2+, the helper is called with `--diff-base <rev>` so Codex
reviews only the fix, not the whole branch again.

!!! note "Team-orchestrate (deprecated)"
    `/agent-flow:team-orchestrate` no longer has its own Phase 4. It forwards
    to `/orchestrate`, so the behavior above applies unchanged.

## What context Codex receives

Each Codex invocation in Phase 4 is given the following context:

- Task description — read from the orchestrator's state file
  `.claude/orchestration.local.md`. The shared helper accepts the state-file
  path via its `--state-file` flag.
- `git diff` of changes under review (whole branch in round 1; only the fix
  diff via `--diff-base` in later rounds; subject to the size guards above)
- Lawliet's findings — only on a sequential re-check (`--lawliet-findings`),
  never in the default parallel flow
- `AGENTS.md` at the repo root (auto-loaded by codex on every `exec` invocation)

Codex runs with `model_reasoning_effort=high` for accuracy. The model is
resolved explicitly and passed via `-m` because `--ignore-user-config` would
otherwise drop the user's model preference from `~/.codex/config.toml`. The
resolution order is:

1. `AGENT_FLOW_CODEX_MODEL` environment variable (if non-empty)
2. Top-level `model` key in `${CODEX_HOME:-~/.codex}/config.toml`
3. No `-m` flag — Codex CLI selects its default (current behavior when no
   config or env var is present)

## Disagreement protocol

**Disagreement rule:** See the canonical truth table in
`skills/verification-gates/references/codex-co-review.md` (loaded by `/orchestrate` Phase 4). The summary: Lawliet's
NEEDS_CHANGES always wins; Codex's NEEDS_CHANGES/BLOCKED requires a `file:line`
citation to flip the verdict.

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

## Review rubric: AGENTS.md

The primary context mechanism for Codex's review rubric is `AGENTS.md` at the repo root. Codex auto-loads this file on every `exec` invocation. It defines the output contract, severity scale, and repo-specific blocker checklist (shell safety, heredoc expansion, YAML validity, hardcoded paths, and secrets).

A user-side skill file at `~/.codex/skills/agent-flow-review/SKILL.md` is a deferred enhancement — it is not created by agent-flow and not required for the review pipeline to work. `AGENTS.md` is the authoritative rubric.

## Testing this integration

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
# Legacy: the deprecated team-mode init script also emits the codex: block
cd $(mktemp -d) && bash /path/to/agent-flow/scripts/init-team-orchestration.sh "dummy task"
grep -A3 '^codex:' .claude/team-orchestration.local.md

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
