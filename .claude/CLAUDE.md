# agent-flow — development guide

This repo is the source of the agent-flow Claude Code plugin. You are usually
working **on** the plugin here, not running it. (`AGENTS.md` at the repo root is Codex's review
checklist for this repo — not instructions for you.)

## Layout

- `agents/*.md` — the six personas (Riko, Senku, Loid, Lawliet, Alphonse, Speedwagon); frontmatter sets model, effort, tools, skills
- `commands/*.md` — `/orchestrate`, `/deep-dive`, `/explain`, `/analyze`, deprecated `/team-orchestrate`
- `workflows/implement-review-verify.js` — `/orchestrate` Phases 3–5 as a plugin workflow (deterministic round cap, parallel review, verdict reconciliation)
- `skills/*/SKILL.md` + `references/` — knowledge skills; branch-only detail moved out of `orchestrate.md` lives in these references
- `hooks/hooks.json` + `hooks/scripts/` — validate-changes (PreToolUse), verify-completion (Stop), log-event (observability, async), refine-prompt-gate
- `scripts/` — state init/update, Codex dispatch, gitignore management, analyze, tests
- `templates/codex/review-rubric.md` — the Codex co-review rubric inlined into every review prompt
- `.claude-plugin/plugin.json` (incl. `mcpServers`) and `marketplace.json`; `docs/` is the mkdocs site

## Checks to run before committing

```bash
bash scripts/validate-plugin.sh                 # runs all sub-suites below
bash hooks/scripts/test-verify-completion.sh
bash scripts/test-dispatch-codex-review.sh
node scripts/test-implement-review-verify.js    # workflow scenarios (mocked runtime)
(cd hooks/scripts && python3 -m unittest -q test_log_event)
claude plugin validate --strict .claude-plugin/plugin.json && claude plugin validate --strict .
uvx --with mkdocs-material mkdocs build --strict -q -d /tmp/agent-flow-site
```

Use `uvx` for Python CLI tools rather than `pip install`.

## Conventions

- **Keep contracts in sync.** A rule usually lives in several places: the agent file, `commands/orchestrate.md`, the workflow script, a skill reference, and `docs/`. When you change one (e.g. a verdict format, a phase rule, a hook's output), grep for the others and update them in the same change.
- **Workflow behavior changes need a scenario** in `scripts/test-implement-review-verify.js`. Workflow scripts can't use `Date.now()`, `Math.random()`, argless `new Date()`, or `import()`, and `export const meta` must stay a pure literal.
- **Hook output:** PreToolUse denies via `hookSpecificOutput.permissionDecision: "deny"` (never `continue: false`); Stop hooks stay silent unless blocking; stdout must be a single JSON object, so tool output goes to stderr.
- **Shell:** scripts must run on macOS `/bin/bash` 3.2 and BSD tools — guard empty arrays under `set -u`, avoid `mapfile`, GNU-only flags, and `sed -i` without `''`.
- **Prompts for agents:** state the rule and why it matters rather than using all-caps `NEVER`/`MUST`; keep self-checks to the few mistakes a role actually makes; keep parse-critical output formats (verdict lines, `<escalation>` blocks, `file:line` findings) unchanged unless every consumer is updated.
- **Versioning:** `scripts/bump-version.sh --minor|--patch` updates `plugin.json`, `marketplace.json`, `docs/index.md`, and `CHANGELOG.md`; curate the generated changelog section rather than keeping the raw commit dump.

## Working in auto mode

agent-flow is often installed as a plugin in the same session you're editing it from, so its own hooks and agents govern the session. Auto mode may block edits to `hooks/hooks.json`, `agents/`, or `commands/` as self-modification — ask the user to allow those paths instead of working around the block. The installed copy lives in `~/.claude/plugins/cache/`; changes here take effect only after a version bump and reinstall.
