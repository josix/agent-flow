# Changelog

All notable changes to the Agent Flow plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.11.1] - 2026-09-30

### Fixed

- Codex co-review diffs no longer inline untracked files that already existed before the run: a real-world diff was 266-277k chars versus a ~32KB tracked diff, because `dispatch-codex-review.sh` inlined ~241KB of pre-existing clutter (aider chat/cache, `complexipy-results.json`, doc-site HTML exports, other tickets' `tmp/` drafts, a stray `.patch` file). `scripts/snapshot-untracked.sh` now records the untracked-file set before Phase 3 starts (`.claude/review-baseline-untracked.local.txt`, tied to the run's `started_at`), and the dispatcher skips any untracked file already in that baseline and unmodified since — counting it instead of listing it — falling back to the old behavior (with a `warn:` line) when no baseline exists or it's stale
- extended the untracked-file artifact exclusions (`tmp/`, `.aider*`, `*-results.json`, patch/diff leftovers, doc-site/coverage build output, `.senku/`, logs, DBs) and added a secret-basename guard (same set as `hooks/scripts/validate-changes.sh`) so secret-like filenames are never inlined into the Codex prompt

### Added

- `scripts/snapshot-untracked.sh`, wired into `commands/orchestrate.md` Phase 3 and `workflows/implement-review-verify.js` (before the first Loid dispatch, only when Codex co-review is enabled)
- a new informational `codex_untracked: inlined=<n> preexisting=<n> artifact=<n> secret=<n> oversize_or_binary=<n> baseline=<used|missing|stale>` line in `dispatch-codex-review.sh`'s stdout (no existing key changes)
- `AGENT_FLOW_CODEX_INLINE_UNTRACKED` (default `1`) — set to `0` to disable inlining untracked files entirely when the baseline is missing or stale

## [1.11.0] - 2026-09-28

### Added

- `/deep-dive` now explains what a project is and how it works, not just its layout: two new Riko lenses (PURPOSE & USE CASES, KEY FLOWS) and three optional sections in `.claude/deep-dive.local.md` — Purpose & Use Cases, Key Flows (numbered `file:line` hops per traced flow), and Gotchas & Failure Modes — written via `compile-deep-dive.sh --purpose / --key-flows / --gotchas`. Existing sections are unchanged, so `/orchestrate --use-deep-dive` keeps working and now seeds Riko with the flow closest to the task
- `/explain` writes modules in the topic's language (e.g. zh-TW): sets `<html lang>`, localizes translator labels, and derives non-empty slugs for CJK topics
- `/explain` readability: plain-language rules in the Senku and Speedwagon prompts, a TL;DR at the top and a glossary at the end (built from existing callout primitives), and three warning-only lint rules — screen without a visual, paragraph over 600 characters, unfilled placeholder
- `scripts/test-compile-explain.sh` and `scripts/test-compile-deep-dive.sh` (validate-plugin Tests 18 and 19)

### Fixed

- `/explain` failed with `_base.html not found` in every project except this repo: templates, the lint script, and prompt paths now resolve from `${CLAUDE_PLUGIN_ROOT}`, and the module-brief example ships at `templates/explain/module-brief-example.md`
- Codex co-review in any project: the review rubric (role, output contract, severity scale, what to defer to Lawliet, re-review scope, tie-breaker) now ships at `templates/codex/review-rubric.md` and is inlined into every prompt by `dispatch-codex-review.sh`. Previously the prompt pointed Codex at an `AGENTS.md` that only the agent-flow repo itself had, so reviews in other projects got no output contract and risked `UNPARSEABLE` verdicts. Re-review prompts now say when the diff is scoped to a fix
- Claude sessions in this repo no longer load the Codex reviewer rubric as their project instructions: added a development guide at `.claude/CLAUDE.md` (Claude Code loads `AGENTS.md` only when a project has no `CLAUDE.md` or `.claude/CLAUDE.md`; it lives under `.claude/` because a root `CLAUDE.md` in a plugin fails `claude plugin validate --strict`), and `AGENTS.md` is now just the agent-flow-specific Codex checklist, with hook-output and workflow-script blocker classes added
- `implement-review-verify` refuses to run without an intent (see PR #11)

### Changed

- `/explain` no longer requires `.claude/deep-dive.local.md`; it uses it when present and otherwise scopes from the README and entry points
- `/deep-dive` synthesis line cap relaxed so the new narrative sections fit
- `scripts/lib/explain-lint.py` split into per-rule helpers (every function under cognitive complexity 15; output unchanged)

## [1.10.0] - 2026-09-28

### Added

- `workflows/implement-review-verify.js` (`/agent-flow:implement-review-verify`): Phases 3–5 as a deterministic plugin workflow — Loid implements, Lawliet + Codex + Alphonse run in parallel, the Phase 4 truth table, Divergence Cap, and capped/batched/diff-scoped fix rounds are code instead of prompt, and the run returns early (`escalation`, `divergence`, `capped`, `blocked`) for decisions that need the user. `/orchestrate` launches it when the Workflow tool is available and falls back to turn-by-turn dispatch otherwise. Covered by `scripts/test-implement-review-verify.js` (11 scenario tests, wired into `validate-plugin.sh`)

### Fixed

- `dispatch-codex-review.sh` exited 128 (no output) in repos without `origin/HEAD` — a pre-existing `set -e` + `pipefail` failure on `git symbolic-ref`; untracked paths are now read NUL-delimited so names with spaces/non-ASCII are reviewed
- Stop hook no longer blocks when a project has `tsconfig.json` but no local TypeScript install
- Workflow: a Lawliet `NEEDS_CHANGES` with no cited finding (e.g. intent mismatch) no longer passes silently; a divergence stop no longer hides a concurrent Alphonse failure; Codex findings are deduplicated only against Lawliet's blocking findings; an escalation relaunch keeps the used round budget (`start_round`) and open findings; Lawliet dispatches carry the context preambles
- Cross-file consistency pass: `capped` runs close state without the completion promise; the completion rule accepts type/lint `COVERED (Lawliet)`; Riko's User Clarification question is asked before Phase 2; Lawliet uses the shared ERROR/WARNING/INFO scale; skills and docs updated for the parallel review flow, Execution Profile, and report-writing exceptions

### Changed

- `/orchestrate` speed: the orchestrator now picks a fast / standard / thorough execution profile itself from the task tier and risk signals (no user flags), skipping Riko/Senku and Codex where the tier allows. Lawliet, Codex, and Alphonse run in parallel; review-fix rounds are capped (1/2/3), batch all findings, re-review only the fix diff, and ignore INFO nits; Loid runs targeted tests only; state writes are one call per phase transition. Motivated by recorded runs where Loid/Lawliet were dispatched 9–10 times each (avg ~5 min per dispatch)
- Agent prompts tuned for current models: emphatic `ABSOLUTE PROHIBITION` / all-caps `NEVER`/`MUST` blocks replaced by stated evidence standards with their reason, and each 12–16-question Self-Reflection checklist cut to the 2–3 mistakes that role most often makes. Loid's verification is now scoped to targeted checks (it previously mandated the full suite, contradicting the Phase 5 split) and its prompt shrank from ~1,380 to ~650 words
- `commands/orchestrate.md` shrank from ~5,100 to ~3,250 words (it is loaded into the main context on every run): branch-only detail moved to on-demand references — Codex co-review + truth table + Divergence Cap (`skills/verification-gates/references/codex-co-review.md`), Research Short-Circuit (`skills/task-classification/references/research-short-circuit.md`), graph/personal-KB/AgentsView preambles (`skills/exploration-strategy/references/context-preambles.md`), deep-dive reuse (`skills/exploration-strategy/references/deep-dive-reuse.md`), and the Intent Ledger template (`skills/verification-gates/references/intent-ledger.md`)
- `dispatch-codex-review.sh` size guards: untracked artifacts (`.playwright-mcp/`, venvs, build output, …), binaries, and files over `AGENT_FLOW_CODEX_MAX_FILE_BYTES` are listed instead of inlined, and diffs over `AGENT_FLOW_CODEX_MAX_DIFF_CHARS` fall back to `--stat` — recorded sessions sent Codex 6M–180M-char prompts and hit its input cap. New `--diff-base <rev>` scopes review-fix rounds to the fix
- `/orchestrate` ticket intake: an issue key or Jira/GitHub-issue URL in the task is fetched first and seeds the intent's Goal/Constraints/acceptance criteria (a manual first step in ~10 recorded sessions)
- Alphonse skips type/lint when Lawliet runs them in the same parallel round (reported as `COVERED (Lawliet)`); Senku builds on Riko's report instead of re-exploring; `/orchestrate` Critical Rules condensed 10 → 3 and Prompt Refinement defers to the `prompt-refinement` skill; log-event hooks run `async`
- `dispatch-codex-review.sh`: `--lawliet-findings` is now optional so Codex can run in parallel with Lawliet
- Senku no longer uses `TodoWrite` (the tool does not exist on current models — Opus 5.5, Sonnet 5, Fable 5.1). Its tools are now Read, Grep, Glob, and Write, with Write restricted to plan/report files under `.claude/agent-reports/` or `.senku/`; plans are numbered markdown checklists. Senku gains `effort: high`
- Riko moved from Opus to Sonnet with `effort: medium`. Tier 3 now escalates clarifying questions to the orchestrator via a **User Clarification** report section (subagents cannot call `AskUserQuestion`); Riko's Bash may also write its own report to `.claude/agent-reports/`
- Report delivery rule for all agents: reports over ~3000 characters are written to `.claude/agent-reports/<agent>-<slug>.md` and the final message is a ≤1500-character summary + verdict + path, fixing observed truncation of relayed reports. Loid must finish every plan item and emit per-item `[done|skipped]` lines
- Commands dispatch via `Agent(subagent_type="agent-flow:<Name>", ...)` instead of `Task(agent=...)` pseudo-calls; the orchestrator waits for each agent's completion notification (never advances on the launch acknowledgement); an approved research/plan-only run re-enters the pipeline at Phase 3; `/deep-dive` re-dispatches an explorer that went idle without a report once. The Senku thinking-budget hint was removed
- `scripts/dispatch-codex-review.sh`: the Codex timeout is now `AGENT_FLOW_CODEX_TIMEOUT` (default 480s, previously a hard-coded 120s) — Codex timed out in ~10 recorded sessions under the old cap
- `verify-completion.sh` (Stop): skips instantly in a git repo with no uncommitted non-doc changes (`*.md`, `*.rst`, `*.txt`, `docs/`, `.claude/` excluded) and caches the passing change fingerprint in `.claude/.verify-completion-pass`, so Q&A and docs-only turns no longer run the test suite; silent on success (no `decision: approve`); tool output goes to stderr; block reasons include the last 15 lines of output; npm's `"no test specified"` placeholder is ignored. Stop hook timeout raised 60s → 300s
- `validate-changes.sh` now runs on PreToolUse only, denies via `hookSpecificOutput.permissionDecision: "deny"` and is silent on allow; `..` is checked as a path segment; sensitive-file patterns narrowed to `.env`, `.env.*`, `*.env`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `credentials`, `credentials.*`, `*.credentials`, `secrets.*`, `*.secret`, `*.secrets`; `/var/folders` and `/var/tmp` are allowed
- `log-event.py`: `tool_response` truncated to 4000 characters; schema DDL only runs when `PRAGMA user_version` < 2
- MCP servers moved from the root `.mcp.json` into `mcpServers` in `.claude-plugin/plugin.json` — the root file doubled as project-scope config when developing in this repo, where `${CLAUDE_PLUGIN_ROOT}` is unset, causing ENOENT on server launch
- Hook commands are quoted (`bash "${CLAUDE_PLUGIN_ROOT}/..."`)
- Background skills (agent-behavior-constraints, exploration-strategy, graphify-usage, personal-kb-usage, prompt-refinement, skill-agent-mapping, task-classification, team-decision, verification-gates) are marked `user-invocable: false`
- `marketplace.json` version synced to 1.9.0 with an updated description; `bump-version.sh` now bumps `marketplace.json` too
- The managed `.gitignore` block (and the repo `.gitignore`) now includes `.claude/agent-reports/` and `.claude/.verify-completion-pass`

### Fixed

- `validate-changes.sh` denials no longer halt the whole session (the old `continue: false` stopped Claude entirely rather than rejecting one tool call)
- Speedwagon's `color` changed from the invalid `magenta` to `pink`

### Removed

- `enforce-delegation.sh` PreToolUse hook — a no-op that only emitted an invalid `message` field
- PostToolUse `prompt` hook on `Agent|Task` — cost a Haiku call per subagent and falsely blocked background/fork agents
- Duplicate PostToolUse `validate-changes.sh` entry
- `TeammateIdle` and `TaskCompleted` hooks (`teammate-idle-check.sh`, `task-completed-check.sh`) — they read `teammate_role` / `task_status` fields that do not exist in current hook input, so they never did anything
- Root `.mcp.json` (superseded by `plugin.json` `mcpServers`)

### Deprecated

- `/team-orchestrate` — `TeamCreate` / `TeamDelete` / `TaskCreate` / `TaskUpdate` were removed from Claude Code (every session now has one implicit team) and `/orchestrate` already runs agents in the background. The command now points users to `/orchestrate`; team-orchestration docs carry a deprecation notice

## [1.9.0] - 2026-07-23

### Added

- AgentsView session-history integration: the `agentsview` stdio MCP server is now registered plugin-side in `.mcp.json` through a `start-agentsview-mcp.sh` guard wrapper (exits 0 when the CLI is absent, so Claude Code startup is never broken). Read-only personas Riko/Senku/Lawliet gain five namespaced tools (`mcp__plugin_agent-flow_agentsview__search_sessions/list_sessions/get_session_overview/get_messages/search_content`) to search prior session history — leveraging proven past approaches during exploration/planning and cross-verifying current handling against precedent during review. `get_usage_summary` is deliberately not granted; Loid and Alphonse are excluded (write/verify separation)
- `detect-agentsview-context.sh`: availability detector emitting an `agentsview:` state block (`available`, `binary`, `archive_reachable`, optional `reason`), wired into both `init-orchestration.sh` and `init-team-orchestration.sh`. `available` keys off binary presence; `archive_reachable` is informational only since the MCP server auto-starts the daemon on demand. Opt-out via `AGENT_FLOW_NO_AGENTSVIEW=1`. The archive probe is bounded by a portable 5-second watchdog (`timeout` → `gtimeout` → `set -m` process-group kill fallback chain) so a hung daemon cannot stall orchestration init or leak daemonizing grandchild processes
- AgentsView-aware mode preamble sections in `/orchestrate` and `/team-orchestrate`, injected into Riko/Senku/Lawliet dispatches when `agentsview: available: true`
- `agentsview-usage` skill (owner Riko, consumers Senku/Lawliet) with tool decision table, token-hygiene guidance, precedent-interpretation rules, reference files, and worked examples; registered in `skill-agent-mapping`
- `docs/guides/using-agentsview.md` plus doc-site coverage across index, reference (agents/skills/commands/state-files), architecture, and installation pages

## [1.8.0] - 2026-07-15

### Added

- Phase-4 divergence cap: a `codex_divergence_rounds` state field (plus `--set-codex-divergence-rounds` flag, integer-validated, with legacy-file migration) tracks consecutive Phase-4 rounds where Lawliet approves but Codex keeps citing the same `file:line`. After 2 consecutive same-citation rounds, the orchestrator stops re-dispatching Loid and escalates to the user via `AskUserQuestion` (Accept Codex / Accept Lawliet / provide guidance — defaults to Lawliet if unanswered) instead of looping indefinitely
- Dispatch Recovery: the orchestrator now auto-retries a dispatched agent once, silently, on a transport/API error or a completely empty reply. Idempotent read-only agents (Riko, Lawliet, Alphonse) are always safe to retry; Loid (mutating) is retried only after confirming no partial write landed, otherwise the failure surfaces to the user
- `ENVIRONMENT_BLOCKED` verification verdict: Alphonse's `Overall` line is now a three-way enum (`VERIFIED | FAILED | ENVIRONMENT_BLOCKED`). Gate failures caused solely by an interpreter/dependency-version/environment mismatch the change did not introduce are reported as environment-blocked (exact error signature cited) and warn-and-proceed instead of routing back to Loid; the caveat is recorded in the Phase 6 Intent Ledger. A repo-internal missing module is still `FAILED`, not environment-blocked
- Concrete-target clarification discount in `prompt-refinement`: a prompt containing a task verb plus a concrete target (file path, filename, identifier, or quoted string) now drops one ambiguity-score severity level, preferring "state assumption and proceed" over asking a clarifying question
- `validate-plugin.sh` Test 16: Lawliet verdict-enum regression guard — asserts `agents/Lawliet.md` still declares `[APPROVED | NEEDS_CHANGES]` and never emits `BLOCKED`

### Changed

- `UserPromptSubmit` hook replaced: the LLM-based prompt hook that judged task clarity is now `hooks/scripts/refine-prompt-gate.sh`, a deterministic command hook. It never blocks; it skips silently on system-generated `<task-notification>`/tag payloads, on follow-ups while an orchestration is actively running (state `active: true`, non-terminal `current_phase`, modified within the last 24h), and on short pronoun follow-ups ("fix it", "try again"); it emits a refinement-nudge `additionalContext` only for new, unscoped task-verb prompts lacking a concrete target
- Iteration Handling: the orchestrator now MUST run `update-orchestration-state.sh --complete --agent Orchestrator --message "Aborted: <reason>"` when `max_iterations` is reached or a run is abandoned/errored, so state reaches a terminal value and the refine-prompt-gate hook does not mistake a stalled run for an active orchestration on the next genuinely-new task

### Fixed

- `teammate-idle-check.sh` no longer accepts `BLOCKED` as a valid reviewer verdict — the "reviewer" teammate role is always Lawliet, which only emits `APPROVED`/`NEEDS_CHANGES`; `BLOCKED` is a Codex-only verdict from the orchestrator's separate Bash dispatch, not a teammate role

## [1.7.1] - 2026-07-14

### Fixed

- `UserPromptSubmit` prompt hook no longer blocks on background
  `<task-notification>` payloads (newer Claude Code routes them through the
  same event as user prompts): added a first-priority pass-through branch for
  system-generated messages, a single-message preamble so pronoun/reference
  follow-ups ("fix it", "did that work?") don't trigger false clarification,
  and a when-in-doubt bias toward the `No refinement needed.` sentinel


## [1.7.0] - 2026-06-22

### Added

- research short-circuit: `/orchestrate` produces a durable gitignored markdown report (`.claude/research-<slug>-<stamp>.local.md`) for research/exploratory tasks via `init-research-report.sh` and `compile-research-report.sh`, skipping implementation/review/verification phases for info-only deliverables


## [1.6.2] - 2026-06-11

### Fixed

- pass explicit model to `codex exec` so the Phase 4 co-review no longer
  fails with "model not supported on this account": `--ignore-user-config`
  dropped the user's model preference, leaving an unsupported CLI default.
  The model is now resolved from `AGENT_FLOW_CODEX_MODEL`, falling back to
  the top-level `model` key in `~/.codex/config.toml`, and passed via `-m`;
  dispatch failures also surface a snippet of the codex error output in the
  warn line

## [1.6.1] - 2026-06-10

### Fixed

- harden verification gates against silent failures: Stop-gate hook builds
  decision JSON via `jq` (closes injection that could flip block to approve)
  and blocks on inaccessible project dir; `escape_yaml` in init scripts
  collapses newlines so multi-line tasks no longer corrupt state frontmatter;
  Codex dispatch distinguishes `codex_skip_reason: timeout` from `error`;
  13 regression test cases added as validate-plugin Tests 12-14

## [1.6.0] - 2026-06-02

### Added

- auto-manage working-project .gitignore for agent-flow artifacts


## [1.5.0] - 2026-06-01

### Added

- add intent-clarification gates and intent ledger to orchestration

### Changed

- adopt complexipy cognitive-complexity check (mirror isort precedent)
- tighten Loid comment guidance to avoid verbose/redundant comments
- bump version to 1.4.1
- add import ordering requirements for Lawliet and Loid agents


## [1.4.2] - 2026-06-01

### Changed

- Lawliet now runs `uvx complexipy --failed` cognitive-complexity checks during Phase 4 review (linter list, allowed Bash commands, new Review Process step at threshold 15); Loid gains design-pattern remediation guidance for over-threshold functions

## [1.4.1] - 2026-05-27

### Changed

- Lawliet now enforces isort import-ordering during Phase 4 review (linter list, allowed Bash commands, new Review Process step), closing the gap delegated by `AGENTS.md`
- Loid now forbidden from writing inline imports — added to Critical Rules and Quality Standards (exception: `if TYPE_CHECKING:` blocks)

### Fixed

- Codex co-review documentation: corrected three accuracy bugs and state-file field descriptions across guides and reference
- Swept remaining stale state-file and wall-time claims from docs


## [1.4.0] - 2026-05-19

### Added

- extend Codex co-review to team-orchestrate via shared helper
- add optional Codex CLI co-reviewer for Phase 4


## [1.3.0] - 2026-05-07

### Added
- `/agent-flow:explain` slash command and `commands/explain.md` for agent-authored interactive site generation
- Speedwagon authoring agent (`agents/Speedwagon.md`) — Write scope limited to `explain-out/` and `.claude/explain-briefs/`
- `skills/explainer-design-system/` skill for primitive vocabulary reference
- `templates/explain/` assets: `styles.css`, `main.js`, `_base.html`, `module-fragment.html.tmpl`
- `scripts/compile-explain.sh` assembler with `--revise <slug>` and `--strict` / `--no-lint` flags
- `scripts/lib/explain-lint.py` 8-rule guardrail (forbidden classes, forbidden JS, undefined classes, undefined CSS vars, aria-describedby integrity, language-* allow-list, diagram-first, onclick)
- 12 shipping primitives: translator, quiz, tooltip, callouts, badges, step-cards, icon-rows, file-ref, mermaid, module shell, screen-toc, skip-link
- Prism 1.x + autoloader integration with synchronous `complete` hook registration and idempotent `wrapPreLines`
- Mermaid 11 ESM with locked theme variables on design tokens
- Canonical Diagram-first ordering and English-panel scaffolding rules (mirrored byte-identically across hosts)
- Site frame widened to `min(1600px, 85vw)`; prose constrained to `72ch`; mobile English-first stack via `@media (max-width:600px)`
- Accessibility: skip-link, role=button on translator bullets, `aria-pressed` on pin state, `prefers-reduced-motion` honored
- Agent-Flow Introduction slide deck

### Changed
- `explain-out/` and `.claude/explain-briefs/` added to `.gitignore`
- Site and slide deck synced for /explain pipeline

## [1.2.3] - 2026-04-20

### Added
- Delegation Decision Matrix in `/orchestrate` and `/team-orchestrate` (tool→persona table, cache-read heuristic, anti-pattern example)
- Senku "Deliverable Output Contract" requiring every plan to pin target format, acceptance criteria, and risks
- Senku thinking-budget dispatch hint in Phase 2 of `/orchestrate`
- Lawliet first-move graph orientation step (`graph_stats` + `god_nodes(top_n=5)`)
- Per-prompt `Graph hint:` lines on the 6 deep-dive fan-out prompts
- Four new heuristics in `analyze.py`: orchestrator IO volume, MCP-skipping per task type, fan-out whitelist, plus regression guards for decision-NULL and iterations-empty

### Fixed
- `hooks/scripts/log-event.py` now populates the `decision` column from hook payload (previously hardcoded NULL)
- `scripts/analyze/analyze.py` iteration parser now handles the multi-line `- Agent:` / `- Result:` / `- Message:` format emitted by `update-orchestration-state.sh` (previously only parsed the legacy single-line format, causing `iterations` table to stay empty)

## [1.2.2] - 2026-04-18

### Added

- `/agent-flow:analyze` slash command and `bash scripts/analyze.sh` CLI with eight subcommands: `load`, `report`, `sessions`, `sql`, `retention`, `label`, `label export`, `export`
- Four observability hooks: `PreToolUse:Agent|Task` (subagent dispatch capture), matcherless `PostToolUse` (all tool results), `SubagentStop` (subagent completion), `SessionEnd` (session closure and export trigger)
- SQLite observability store (`.claude/observability/events.db`, WAL mode) with tables: `events`, `sessions`, `subagents`, `iterations`, `labels`; plus eight pre-built views for tool usage, token spend, thinking effort, dispatch rates, and rejection rates
- Redaction patterns for AWS keys, Anthropic (`sk-ant-`), OpenAI, GitHub PAT (classic + fine-grained), Slack (`xoxb-`/`xoxp-`), and PEM private keys
- Retention management via `bash scripts/analyze.sh retention --days N` or `--all`
- Interactive recall labeling (`label` subcommand) with `correct`/`missed`/`extra`/`wrong` verdicts and CSV export with precision and recall_proxy metrics
- Pluggable exporters driven by `.claude/observability.json`: JSONL (default, stdlib) and MLflow (opt-in, guarded `ImportError`)
- JSONL fallback sink (`.claude/observability/events.jsonl`) when the database is locked; ~30 ms p95 hook latency

### Fixed

- `PostToolUse` hook matcher broadened from `Task` to `Agent|Task` so both tool names are captured for post-tool observability events

## [1.2.1] - 2026-04-17

### Fixed

- resolve Mermaid diagram parse error in data-flows.md
- resolve MkDocs strict build failures

## [1.2.0] - 2026-04-16

### Added

- personal-kb integration: user-scope MCP registration (`personal-kb` server key) lets Riko, Senku, and Lawliet query a cross-project personal knowledge graph via `mcp__personal-kb__*` tools
- `scripts/detect-personal-kb.sh` detector emitting `personal_kb:` YAML block; reads `AGENT_FLOW_PERSONAL_KB_PATH` env var and emits absolute paths (unlike the project-graph detector which uses relative paths)
- `personal_kb:` block in orchestration and team-orchestration state files (available, path, graph_path, generated, nodes, edges, communities) — written by both `init-orchestration.sh` and `init-team-orchestration.sh`
- Personal KB-aware mode preamble in `orchestrate.md`, `team-orchestrate.md`, and `deep-dive.md` — orchestrator injects `mcp__personal-kb__*` query hints into Riko/Senku/Lawliet prompts when personal KB is available
- `skills/personal-kb-usage/` skill with SKILL.md, tool-reference.md, query-patterns.md, and worked-queries.md covering cross-project recall patterns, token hygiene, and privacy constraints
- `mcp__personal-kb__*` tools (7 tools) added to Riko, Senku, and Lawliet agent frontmatter; `personal-kb-usage` skill added to all three
- `docs/guides/using-personal-kb.md` — setup guide covering MCP server registration, env var contract, verification, refresh, and troubleshooting
- `personal_kb:` object documented in `docs/reference/state-files.md` with field table
- `AGENT_FLOW_PERSONAL_KB_PATH` env var contract: set to absolute path of personal KB root; `detect-personal-kb.sh` expands `~` and validates path + graph existence
- graphify knowledge-graph integration: MCP server auto-launches at session start, exposing 7 read-only graph query tools to Riko, Senku, and Lawliet
- `scripts/start-graphify-mcp.sh` portable wrapper detecting graphify via `python3`, `python`, or pipx venv (shebang-parsed — no hardcoded paths)
- `scripts/detect-graph-context.sh` helper emitting `graph:` YAML block, sourced by both `init-orchestration.sh` and `init-team-orchestration.sh`
- `graph:` block in orchestration and team-orchestration state files (available, path, generated, nodes, edges, communities)
- Graph-aware mode preamble in `orchestrate.md`, `team-orchestrate.md`, and `deep-dive.md` — orchestrator injects MCP query hints into subagent prompts when graph is available
- `SessionStart` hook exports `AGENT_FLOW_GRAPH_PATH` when `graphify-out/graph.json` exists
- `docs/guides/using-graphify.md` — practical how-to guide
- Targeted install-hint error messages in the wrapper (distinguishes "not installed" / "missing mcp extra" with pip vs pipx fix)
- `graphify-out/` added to `.gitignore`

### Changed

- update reference docs to reflect graphify, personal-kb, and team orchestration features (skills registry, agents reference, architecture diagrams, README, quick-start, design decisions ADR-009/ADR-010)

## [1.1.1] - 2026-02-09

### Added

- integrate team orchestration into existing agents and skills
- add team orchestration core with parallel review and verification
- Add documentation files for Agent Flow project
- Add initial plugin structure for multi-agent orchestration system

### Fixed

- use exit 0 with JSON decision control instead of exit 2 in hook scripts
- address best practices issues across plugin
- conditionally run pytest only when tests directory exists

### Changed

- bump version to 1.1.0
- add changelog and version bump script
- add team orchestration documentation and update references
- align documentation with current implementation
- Enhance test verification script with advanced error handling and bypass options


## [1.1.0] - 2026-02-08

### Added

- integrate team orchestration into existing agents and skills
- add team orchestration core with parallel review and verification
- Add documentation files for Agent Flow project
- Add initial plugin structure for multi-agent orchestration system

### Fixed

- address best practices issues across plugin
- conditionally run pytest only when tests directory exists

### Changed

- add changelog and version bump script
- add team orchestration documentation and update references
- align documentation with current implementation
- Enhance test verification script with advanced error handling and bypass options


## [1.0.0] - 2026-02-08

### Added

- Add documentation files for Agent Flow project
- Add initial plugin structure for multi-agent orchestration system

### Fixed

- Address best practices issues across plugin
- Conditionally run pytest only when tests directory exists

### Changed

- Align documentation with current implementation
- Enhance test verification script with advanced error handling and bypass options
