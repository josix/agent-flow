---
title: Using Codex co-review in Phase 4
---

# Using Codex co-review in Phase 4

## What Codex co-review adds

When the Codex CLI is installed and authenticated, the `/orchestrate` command automatically enlists it as a second reviewer in Phase 4 alongside Lawliet. This gives you a cross-vendor second opinion on every diff: Lawliet provides linter-grounded static analysis via Claude Sonnet, while Codex brings OpenAI's model perspective. The two verdicts are reconciled by the disagreement protocol described below, so you get stronger signal without any extra steps in your workflow.

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

## What context Codex receives

Each Codex invocation in Phase 4 is given the following context:

- Task description (from `.claude/orchestration.local.md`)
- Lawliet's verdict + findings (the immediately preceding Phase 4 review)
- Full `git diff` of changes under review
- `AGENTS.md` at the repo root (auto-loaded by codex on every `exec` invocation)

Codex runs with `model_reasoning_effort=high` for accuracy.

## Disagreement protocol

When both reviewers run, their verdicts are reconciled as follows:

| Lawliet verdict | Codex verdict | Codex has file:line citation? | Final verdict |
|-----------------|---------------|-------------------------------|---------------|
| APPROVED | APPROVED | n/a | APPROVED |
| APPROVED | BLOCKED or NEEDS_CHANGES | yes | NEEDS_CHANGES (Codex cite surfaced) |
| APPROVED | BLOCKED or NEEDS_CHANGES | no | APPROVED (advisory only) |
| NEEDS_CHANGES | any | any | NEEDS_CHANGES (Lawliet wins) |

Codex findings without a `file:line` citation are advisory only and never block the workflow. Lawliet always wins on linter-grounded findings when it returns NEEDS_CHANGES.

Full rule reference: [`skills/verification-gates/SKILL.md`](../../skills/verification-gates/SKILL.md) — "Multi-reviewer disagreement (Codex co-review)".

## Review rubric: AGENTS.md

The primary context mechanism for Codex's review rubric is `AGENTS.md` at the repo root. Codex auto-loads this file on every `exec` invocation. It defines the output contract, severity scale, and repo-specific blocker checklist (shell safety, heredoc expansion, YAML validity, hardcoded paths, and secrets).

A user-side skill file at `~/.codex/skills/agent-flow-review/SKILL.md` is a deferred enhancement — it is not created by agent-flow and not required for the review pipeline to work. `AGENTS.md` is the authoritative rubric.
