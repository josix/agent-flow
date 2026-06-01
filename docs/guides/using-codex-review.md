---
title: Using Codex co-review in Phase 4
---

# Using Codex co-review in Phase 4

## What Codex co-review adds

When the Codex CLI is installed and authenticated, the `/orchestrate` command automatically enlists it as a second reviewer in Phase 4 alongside Lawliet. This gives you a cross-vendor second opinion on every diff: Lawliet provides linter-grounded static analysis via Claude Sonnet (including an **intent-fidelity check** that flags `intent-mismatch` when the patch passes static analysis but doesn't satisfy the stated Goal/Constraints), while Codex brings OpenAI's model perspective. The two verdicts are reconciled by the disagreement protocol described below, so you get stronger signal without any extra steps in your workflow.

This applies to both `/agent-flow:orchestrate` and `/agent-flow:team-orchestrate` —
Phase 4 in both commands routes through the same Codex dispatch helper
(`scripts/dispatch-codex-review.sh`) with identical reconciliation rules.

## Data boundary — what leaves your machine

Every Phase 4 review with Codex enabled transmits the following to OpenAI's
servers via your authenticated Codex CLI session:

- The full diff under review (`git merge-base HEAD <default-branch>..HEAD` plus
  any uncommitted working-tree changes).
- The task description as recorded in the orchestrator's state file:
  `.claude/orchestration.local.md` for `/agent-flow:orchestrate`, or
  `.claude/team-orchestration.local.md` for `/agent-flow:team-orchestrate`
  (the shared helper accepts the path via `--state-file`).
- Lawliet's full review reply (file:line findings and reasoning).

**Do not enable Codex co-review in repositories that contain:**
- Regulated data (PII, PHI, payment data, etc.)
- Secrets, credentials, or API keys (even in `.env.example` or test fixtures)
- Proprietary algorithms or third-party code under restrictive licenses
- Any code your organization's data-handling policy prohibits from leaving
  the perimeter

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

The `AGENT_FLOW_NO_CODEX=1` env var applies to both `/agent-flow:orchestrate`
and `/agent-flow:team-orchestrate`. The detector (`scripts/detect-codex-context.sh`)
is invoked by both init scripts and bakes `available: false` into the relevant
state file when the env var is set at Claude Code startup.

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

Each Codex invocation during Phase 4 counts against your ChatGPT subscription's usage allotment. Higher reasoning effort and larger prompt (full diff + Lawliet findings) increase per-review token usage. Cost scales with diff size. Be aware of this if you are on a plan with limited allotment.

## Team-orchestrate integration

`/agent-flow:team-orchestrate` runs Phase 4 + 5 in parallel via Agent Teams
(Review + Verification teammates) when team mode is available. Codex co-review
is layered onto the Review side:

- **Team mode**: After Lawliet (the review teammate) completes and the
  orchestrator collects its verdict via `SendMessage`, the orchestrator invokes
  `scripts/dispatch-codex-review.sh` sequentially. Codex reads Lawliet's
  findings and the diff, then emits its own verdict. The two verdicts are
  reconciled (same truth table as `/orchestrate`) before the orchestrator writes
  the review teammate's gate result.

- **Sequential fallback mode**: Behavior is identical to `/agent-flow:orchestrate` —
  Lawliet first, Codex second, reconcile, then record gate result.

Codex runs after Lawliet (not as a third parallel teammate) because Codex
requires Lawliet's findings as input. This adds the Codex wall-time (typically
up to 120s when `timeout` or `gtimeout` is installed; unbounded on systems
without either, with a warning logged to stderr) sequentially to the Phase 4+5
parallel group, but only when
Codex is available. The cost matches `/orchestrate`'s Phase 4 — no
team-specific overhead.

## What context Codex receives

Each Codex invocation in Phase 4 is given the following context:

- Task description — read from the orchestrator's state file:
  `.claude/orchestration.local.md` for `/agent-flow:orchestrate`, or
  `.claude/team-orchestration.local.md` for `/agent-flow:team-orchestrate`.
  The shared helper accepts the state-file path via its `--state-file` flag.
- Lawliet's verdict + findings (the immediately preceding Phase 4 review)
- Full `git diff` of changes under review
- `AGENTS.md` at the repo root (auto-loaded by codex on every `exec` invocation)

Codex runs with `model_reasoning_effort=high` for accuracy.

## Disagreement protocol

**Disagreement rule:** See the canonical truth table in
`commands/orchestrate.md` Phase 4 (Codex co-review). The summary: Lawliet's
NEEDS_CHANGES always wins; Codex's NEEDS_CHANGES/BLOCKED requires a `file:line`
citation to flip the verdict.

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
# Team-mode init also emits the codex: block
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
# Expected: prints "codex_ran: false" on stdout, exit code 0
```

## Reporting issues

If the Codex co-review misbehaves (timeouts, mis-parsed verdicts, false BLOCKED, data-egress concerns), please open an issue at https://github.com/josix/agent-flow/issues with:
- The output of `bash scripts/detect-codex-context.sh`
- The `codex:` block from `.claude/orchestration.local.md`
- The relevant Codex stderr lines (look for `warn:` prefixes from Phase 4)
