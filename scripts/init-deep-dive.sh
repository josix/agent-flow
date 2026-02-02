#!/bin/bash

# Agent Flow - Deep Dive State Initialization Script
# Creates state file for tracking deep-dive exploration progress
# Following ralph-loop patterns for atomic file operations

set -euo pipefail

# Temp file cleanup trap
TEMP_FILE=""
cleanup() {
  [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
  return 0
}
trap cleanup EXIT

# YAML escaping function to prevent injection
escape_yaml() {
  local s="$1"
  # Replace backslashes first, then quotes
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  # Wrap in quotes for safety with special chars
  echo "\"$s\""
}

# Default values
SCOPE="full"
FOCUS_PATH=""
REFRESH=false
AGENT_COUNT=5

# Print usage
print_usage() {
  cat << 'HELP_EOF'
Agent Flow - Deep Dive Initialization

USAGE:
  init-deep-dive.sh [OPTIONS]

OPTIONS:
  --scope <scope>       Scope of exploration: full (default) or focused
  --focus-path <path>   Path to focus exploration on (requires --scope=focused)
  --refresh             Refresh existing deep-dive context
  --agent-count <n>     Number of parallel agents to spawn (default: 5)
  -h, --help            Show this help message

DESCRIPTION:
  Initializes state tracking for a deep-dive exploration session.
  Creates .claude/deep-dive.local.md with YAML frontmatter to track:
  - Scope (full or focused)
  - Focus path (if focused)
  - Phase progress
  - Agent findings

EXAMPLES:
  # Full codebase exploration
  init-deep-dive.sh

  # Focused exploration on a specific path
  init-deep-dive.sh --scope focused --focus-path src/auth

  # Refresh existing context
  init-deep-dive.sh --refresh

  # Custom agent count for large codebases
  init-deep-dive.sh --agent-count 8

STATE FILE:
  .claude/deep-dive.local.md

MONITORING:
  # View current state:
  head -50 .claude/deep-dive.local.md

  # Check scope:
  grep '^scope:' .claude/deep-dive.local.md
HELP_EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_usage
      exit 0
      ;;
    --scope)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --scope requires an argument (full or focused)" >&2
        exit 1
      fi
      if [[ "$2" != "full" && "$2" != "focused" ]]; then
        echo "Error: --scope must be 'full' or 'focused', got: $2" >&2
        exit 1
      fi
      SCOPE="$2"
      shift 2
      ;;
    --focus-path)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --focus-path requires a path argument" >&2
        exit 1
      fi
      FOCUS_PATH="$2"
      shift 2
      ;;
    --refresh)
      REFRESH=true
      shift
      ;;
    --agent-count)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --agent-count requires a number argument" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --agent-count must be a positive integer, got: $2" >&2
        exit 1
      fi
      AGENT_COUNT="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# Validate focus-path is provided if scope is focused
if [[ "$SCOPE" == "focused" && -z "$FOCUS_PATH" ]]; then
  echo "Error: --focus-path is required when --scope=focused" >&2
  exit 1
fi

# Create .claude directory if it doesn't exist
mkdir -p .claude

# Get current timestamp in ISO 8601 format
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# State file location
STATE_FILE=".claude/deep-dive.local.md"
TEMP_FILE="${STATE_FILE}.tmp.$$"

# Check if refreshing and file exists
if [[ "$REFRESH" == true && -f "$STATE_FILE" ]]; then
  echo "Refreshing deep-dive context..."
  # Archive old file with timestamp
  ARCHIVE_FILE=".claude/deep-dive.local.md.bak.$(date +%Y%m%d%H%M%S)"
  cp "$STATE_FILE" "$ARCHIVE_FILE"
  echo "Previous context archived to: $ARCHIVE_FILE"
fi

# Format focus path for YAML
if [[ -n "$FOCUS_PATH" ]]; then
  FOCUS_PATH_YAML=$(escape_yaml "$FOCUS_PATH")
else
  FOCUS_PATH_YAML="null"
fi

# Create state file with YAML frontmatter
cat > "$TEMP_FILE" << EOF
---
generated: "$TIMESTAMP"
scope: $SCOPE
focus_path: $FOCUS_PATH_YAML
expires_hint: "refresh when codebase significantly changes"
phase: "initializing"
agent_count: $AGENT_COUNT
phases:
  parallel_exploration:
    status: "pending"
    agents_spawned: 0
    agents_completed: 0
  synthesis:
    status: "pending"
  compilation:
    status: "pending"
---

# Deep-Dive Context

> Generated: $TIMESTAMP
> Scope: $SCOPE
$(if [[ -n "$FOCUS_PATH" ]]; then echo "> Focus: $FOCUS_PATH"; fi)

## Repository Overview
_Pending parallel exploration..._

## Architecture Map
| Component | Location | Purpose |
|-----------|----------|---------|
| _pending_ | _pending_ | _pending_ |

## Conventions
_Pending exploration..._

## Anti-Patterns (DO NOT)
_Pending exploration..._

## Key Files Quick Reference
| Task | Look Here |
|------|-----------|
| _pending_ | _pending_ |

## Agent Notes
_Findings from parallel exploration agents will be merged here..._

---

## Exploration Log

### Initialization
- Timestamp: $TIMESTAMP
- Scope: $SCOPE
$(if [[ -n "$FOCUS_PATH" ]]; then echo "- Focus Path: $FOCUS_PATH"; fi)
- Parallel Agents: $AGENT_COUNT
$(if [[ "$REFRESH" == true ]]; then echo "- Mode: Refresh (previous context archived)"; fi)

EOF

# Atomically move temp file to final location
mv "$TEMP_FILE" "$STATE_FILE"

# Output initialization message
cat << EOF
Deep-Dive initialized.

Scope: $SCOPE
$(if [[ -n "$FOCUS_PATH" ]]; then echo "Focus Path: $FOCUS_PATH"; fi)
Agent Count: $AGENT_COUNT
State File: $STATE_FILE

Phases:
  1. parallel_exploration (pending) - Fire $AGENT_COUNT Riko agents
  2. synthesis (pending) - Senku merges findings
  3. compilation (pending) - Generate final output

Next Step: Run deep-dive command to begin parallel exploration.
EOF

exit 0
