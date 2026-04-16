# Changelog

All notable changes to the Agent Flow plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- graphify knowledge-graph integration: MCP server auto-launches at session start, exposing 7 read-only graph query tools to Riko, Senku, and Lawliet
- `scripts/start-graphify-mcp.sh` portable wrapper detecting graphify via `python3`, `python`, or pipx venv (shebang-parsed — no hardcoded paths)
- `scripts/detect-graph-context.sh` helper emitting `graph:` YAML block, sourced by both `init-orchestration.sh` and `init-team-orchestration.sh`
- `graph:` block in orchestration and team-orchestration state files (available, path, generated, nodes, edges, communities)
- Graph-aware mode preamble in `orchestrate.md`, `team-orchestrate.md`, and `deep-dive.md` — orchestrator injects MCP query hints into subagent prompts when graph is available
- `SessionStart` hook exports `AGENT_FLOW_GRAPH_PATH` when `graphify-out/graph.json` exists
- `docs/guides/using-graphify.md` — practical how-to guide
- Targeted install-hint error messages in the wrapper (distinguishes "not installed" / "missing mcp extra" with pip vs pipx fix)
- `graphify-out/` added to `.gitignore`

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
