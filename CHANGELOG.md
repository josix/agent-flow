# Changelog

All notable changes to the Agent Flow plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
