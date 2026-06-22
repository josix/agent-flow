#!/bin/bash

# Agent Flow - Research Report Initialization Script
# Creates a durable markdown artifact for research/investigation tasks
# Following init-deep-dive.sh patterns for atomic file operations

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
  # Collapse newlines to spaces (YAML scalar must stay on one line)
  s="${s//$'\n'/ }"
  # Replace backslashes first, then quotes
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  # Wrap in quotes for safety with special chars
  echo "\"$s\""
}

# Default values
SCOPE="research"
GOAL=""

# Print usage
print_usage() {
  cat << 'HELP_EOF'
Agent Flow - Research Report Initialization

USAGE:
  init-research-report.sh --goal <text> [OPTIONS]

OPTIONS:
  --goal <text>         Goal of the research/investigation (required)
  --scope <scope>       Scope: research (default) or exploratory
  -h, --help            Show this help message

DESCRIPTION:
  Initializes a durable markdown research report artifact.
  Creates .claude/research-<slug>-<stamp>.local.md with YAML frontmatter.
  The report file is gitignored via the .claude/*.local.* pattern.

EXAMPLES:
  # Research task
  init-research-report.sh --goal "investigate why auth tokens expire early"

  # Exploratory investigation
  init-research-report.sh --goal "explore caching options" --scope exploratory

STATE FILE:
  .claude/research-<slug>-<stamp>.local.md

MONITORING:
  # View report:
  cat .claude/research-*.local.md
HELP_EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_usage
      exit 0
      ;;
    --goal)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --goal requires an argument" >&2
        exit 1
      fi
      GOAL="$2"
      shift 2
      ;;
    --scope)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --scope requires an argument (research or exploratory)" >&2
        exit 1
      fi
      if [[ "$2" != "research" && "$2" != "exploratory" ]]; then
        echo "Error: --scope must be 'research' or 'exploratory', got: $2" >&2
        exit 1
      fi
      SCOPE="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# Validate required args
if [[ -z "$GOAL" ]]; then
  echo "Error: --goal is required" >&2
  print_usage
  exit 1
fi

# Build slug from goal: lowercase, non-alnum → -, collapse repeats, trim, truncate ~40 chars
SLUG=$(echo "$GOAL" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -cs 'a-z0-9' '-' \
  | sed 's/^-*//; s/-*$//' \
  | cut -c1-40 \
  | sed 's/-*$//')

# Fallback slug if empty
if [[ -z "$SLUG" ]]; then
  SLUG="report"
fi

# Timestamp and report path (second-resolution to avoid minute-level collisions)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
REPORT_PATH=".claude/research-${SLUG}-${STAMP}.local.md"

# Create .claude directory if it doesn't exist
mkdir -p .claude

# Collision guard: if the path already exists, append a numeric suffix
if [[ -f "$REPORT_PATH" ]]; then
  SUFFIX=2
  while [[ -f ".claude/research-${SLUG}-${STAMP}-${SUFFIX}.local.md" ]]; do
    ((SUFFIX++))
  done
  REPORT_PATH=".claude/research-${SLUG}-${STAMP}-${SUFFIX}.local.md"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/ensure-gitignore.sh" >/dev/null 2>&1 || true

# Escape goal for YAML
GOAL_YAML=$(escape_yaml "$GOAL")

# Sanitize newlines/carriage returns for markdown body usage
GOAL_BODY="${GOAL//$'\r'/ }"
GOAL_BODY="${GOAL_BODY//$'\n'/ }"

TEMP_FILE="${REPORT_PATH}.tmp.$$"

cat > "$TEMP_FILE" << EOF
---
generated: "$STAMP"
goal: $GOAL_YAML
scope: "$SCOPE"
report_path: "$REPORT_PATH"
status: "initializing"
phases:
  exploration: pending
  synthesis: pending
---

# Research Report

> Generated: $STAMP
> Goal: $GOAL_BODY
> Scope: $SCOPE

## Summary
_pending..._

## Findings
_pending..._

## Plan / Recommendations
_pending..._

## Open Questions
_pending..._

## Sources & Evidence
_pending..._
EOF

# Atomically move temp file to final location
mv "$TEMP_FILE" "$REPORT_PATH"

echo "$REPORT_PATH"
