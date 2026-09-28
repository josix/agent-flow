---
name: team-orchestrate
description: "[DEPRECATED — use /orchestrate] Former Agent Teams variant of /orchestrate"
argument-hint: [--use-deep-dive] [--force-sequential] <task description>
---

# Team Orchestrate Command (Deprecated)

`/team-orchestrate` is deprecated and no longer runs its own pipeline.

**Why:** it was built on `TeamCreate` / `TeamDelete` / `TaskCreate` /
`TaskUpdate`, which current Claude Code removed — every session now has one
implicit team, and subagents already run in the background. `/orchestrate`
now covers the same ground (background dispatch, parallel Riko exploration,
Lawliet + Codex review, Alphonse verification), and the TeammateIdle /
TaskCompleted quality hooks this command relied on never received the fields
they checked.

## What to do

Tell the user, in one line, that `/team-orchestrate` is deprecated and the
task is being run through `/orchestrate` instead. Then follow
`${CLAUDE_PLUGIN_ROOT}/commands/orchestrate.md` exactly, with these argument
mappings:

- `--use-deep-dive` → pass through unchanged (`/orchestrate` supports it).
- `--force-sequential` → drop it; `/orchestrate` decides parallelism itself.
- Everything else → the task description.

Do not call `TeamCreate`, `TeamDelete`, `TaskCreate`, or `TaskUpdate`, and do
not initialize `.claude/team-orchestration.local.md`.

## Task

$ARGUMENTS
