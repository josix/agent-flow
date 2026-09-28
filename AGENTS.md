# Codex co-review — agent-flow repo checklist

This file is for **Codex** reviewing changes to the agent-flow plugin itself.
Claude Code sessions in this repo use `.claude/CLAUDE.md` instead.

The general co-review rubric — your role next to Lawliet, the output
contract (one verdict line + `SEVERITY: file:line: issue` findings), the
severity scale, what to defer to Lawliet, and the tie-breaker — ships with
the plugin at `templates/codex/review-rubric.md` and is inlined into every
review prompt by `scripts/dispatch-codex-review.sh`. Follow it. The checklist
below adds the blocker classes specific to this repository.

## Project context

Agent Flow is a multi-agent orchestrator plugin for Claude Code. Agents are
markdown files under `agents/`; orchestration commands live in `commands/`;
skills under `skills/`; the Phases 3–5 loop is the plugin workflow
`workflows/implement-review-verify.js`. `/orchestrate` delegates each phase
to a specialist agent (Riko, Senku, Loid, Lawliet, Alphonse).

## Repo-specific blocker classes

1. **Shell safety**: standalone `.sh` files must use `set -euo pipefail` at the top (hook scripts that intentionally fail open may use `set -uo pipefail` with a comment). Flag a new `.sh` file missing it. ERROR. Embedded Bash inside `commands/*.md` is out of scope.

2. **Heredoc variable expansion**: `commands/*.md` Bash blocks must not use `$VAR` inside `<<'PROMPT'` heredocs — single-quoted delimiters suppress expansion, so the variable is emitted literally. ERROR.

3. **YAML validity**: YAML emitted to `.claude/orchestration.local.md` must be syntactically valid; unclosed keys, bad indentation, or stray characters break the grep-based parsers. ERROR.

4. **No hardcoded paths**: scripts must not contain `/Users/...` or other machine-specific absolute paths — use `${HOME}`, `$(git rev-parse --show-toplevel)`, or `${CLAUDE_PLUGIN_ROOT}`. WARNING.

5. **No secrets**: no API keys, tokens, passwords, or credentials in committed files. ERROR.

6. **Hook output contracts**: PreToolUse denials use `hookSpecificOutput.permissionDecision: "deny"`, never top-level `continue: false` (which halts the whole session); Stop hooks emit `{"decision": "block", ...}` only when blocking and stay silent otherwise; a hook's stdout must be exactly one JSON object (tool output goes to stderr). ERROR.

7. **Workflow script rules**: `workflows/*.js` must keep `export const meta` a pure literal as the first statement, must not use `Date.now()`, `Math.random()`, argless `new Date()`, or `import()`, and behavior changes need a matching scenario in `scripts/test-implement-review-verify.js`. ERROR for the forbidden APIs, WARNING for a missing test.
