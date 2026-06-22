#!/bin/bash

# Agent Flow - Research Report Compilation Script
# Rewrites section content into an existing research report artifact
# Following compile-deep-dive.sh patterns for atomic file operations

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
  s="${s//$'\n'/ }"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  echo "\"$s\""
}

# Check whether a section value is empty or still a stub placeholder.
# Matches only when the trimmed content is exactly the stub string
# "_pending..._", the exploratory N/A string "_N/A — exploratory_",
# or empty/whitespace-only — not merely contains those substrings.
is_stub_or_empty() {
  local val
  # Trim leading and trailing whitespace
  val="${1#"${1%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  [[ -z "$val" || "$val" == "_pending..._" || "$val" == "_N/A — exploratory_" ]]
}

# Default values
REPORT_PATH=""
SUMMARY=""
FINDINGS=""
PLAN=""
OPEN_QUESTIONS=""
SOURCES=""
MARK_COMPLETE=false

# Print usage
print_usage() {
  cat << 'HELP_EOF'
Agent Flow - Research Report Compilation

USAGE:
  compile-research-report.sh --report-path <file> [OPTIONS]

OPTIONS:
  --report-path <file>    Path to research report file (required)
  --summary <text>        Summary section content
  --findings <text>       Findings section content
  --plan <text>           Plan / Recommendations section content
  --open-questions <text> Open Questions section content
  --sources <text>        Sources & Evidence section content
  --mark-complete         Mark report as complete (validates required sections)
  -h, --help              Show this help message

DESCRIPTION:
  Compiles findings into an existing research report artifact.
  Preserves goal/scope/generated from existing frontmatter.
  With --mark-complete, validates that required sections are filled.

EXAMPLES:
  # Update findings
  compile-research-report.sh --report-path .claude/research-foo-20260612T093000Z.local.md \
    --findings "Found that tokens expire due to clock skew"

  # Mark complete (validates sections first)
  compile-research-report.sh --report-path .claude/research-foo-20260612T093000Z.local.md \
    --summary "Root cause identified" \
    --findings "..." \
    --plan "..." \
    --mark-complete
HELP_EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_usage
      exit 0
      ;;
    --report-path)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --report-path requires a file argument" >&2
        exit 1
      fi
      REPORT_PATH="$2"
      shift 2
      ;;
    --summary)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --summary requires an argument" >&2
        exit 1
      fi
      SUMMARY="$2"
      shift 2
      ;;
    --findings)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --findings requires an argument" >&2
        exit 1
      fi
      FINDINGS="$2"
      shift 2
      ;;
    --plan)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --plan requires an argument" >&2
        exit 1
      fi
      PLAN="$2"
      shift 2
      ;;
    --open-questions)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --open-questions requires an argument" >&2
        exit 1
      fi
      OPEN_QUESTIONS="$2"
      shift 2
      ;;
    --sources)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --sources requires an argument" >&2
        exit 1
      fi
      SOURCES="$2"
      shift 2
      ;;
    --mark-complete)
      MARK_COMPLETE=true
      shift
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# Validate required args
if [[ -z "$REPORT_PATH" ]]; then
  echo "Error: --report-path is required" >&2
  exit 1
fi

# Guard against path traversal: report must reside under .claude/
if [[ "$REPORT_PATH" != .claude/* ]]; then
  echo "Error: --report-path must be under .claude/ (got: $REPORT_PATH)" >&2
  exit 1
fi
if [[ "$REPORT_PATH" == *..* ]]; then
  echo "Error: --report-path must not contain path traversal components (got: $REPORT_PATH)" >&2
  exit 1
fi

# Check if report file exists
if [[ ! -f "$REPORT_PATH" ]]; then
  echo "Error: Report file not found: $REPORT_PATH" >&2
  echo "Run init-research-report.sh first to initialize the report" >&2
  exit 1
fi

# Get current timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read current frontmatter values (preserve goal/scope/generated)
CURRENT_GOAL=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$REPORT_PATH" | grep '^goal:' | sed 's/^goal: *//' | sed 's/^"//; s/"$//' || echo "")
CURRENT_SCOPE=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$REPORT_PATH" | grep '^scope:' | sed 's/^scope: *//' | tr -d '"' || echo "research")
CURRENT_GENERATED=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$REPORT_PATH" | grep '^generated:' | sed 's/^generated: *//' | tr -d '"' || echo "")

# If new section content not provided, read existing section content from file
read_section() {
  local header="$1"
  # Extract content between this header and the next ## header (or end of file)
  # Strip leading/trailing blank lines via awk
  awk -v h="## ${header}" '
    $0==h{found=1; next}
    found && /^## /{exit}
    found{lines[++n]=$0}
    END{
      # trim leading blank lines
      start=1
      while(start<=n && lines[start]~/^[[:space:]]*$/) start++
      # trim trailing blank lines
      end=n
      while(end>=start && lines[end]~/^[[:space:]]*$/) end--
      for(i=start;i<=end;i++) print lines[i]
    }
  ' "$REPORT_PATH"
}

EFFECTIVE_SUMMARY="${SUMMARY}"
EFFECTIVE_FINDINGS="${FINDINGS}"
EFFECTIVE_PLAN="${PLAN}"
EFFECTIVE_OPEN_QUESTIONS="${OPEN_QUESTIONS}"
EFFECTIVE_SOURCES="${SOURCES}"

# If not provided, pull existing content from file
if [[ -z "$EFFECTIVE_SUMMARY" ]]; then
  EFFECTIVE_SUMMARY=$(read_section "Summary")
fi
if [[ -z "$EFFECTIVE_FINDINGS" ]]; then
  EFFECTIVE_FINDINGS=$(read_section "Findings")
fi
if [[ -z "$EFFECTIVE_PLAN" ]]; then
  EFFECTIVE_PLAN=$(read_section "Plan / Recommendations")
fi
if [[ -z "$EFFECTIVE_OPEN_QUESTIONS" ]]; then
  EFFECTIVE_OPEN_QUESTIONS=$(read_section "Open Questions")
fi
if [[ -z "$EFFECTIVE_SOURCES" ]]; then
  EFFECTIVE_SOURCES=$(read_section "Sources & Evidence")
fi

# Structural completeness gate for --mark-complete
if [[ "$MARK_COMPLETE" == true ]]; then
  if is_stub_or_empty "$EFFECTIVE_SUMMARY"; then
    echo "Error: --mark-complete requires a non-empty Summary section" >&2
    exit 1
  fi
  if is_stub_or_empty "$EFFECTIVE_FINDINGS"; then
    echo "Error: --mark-complete requires a non-empty Findings section" >&2
    exit 1
  fi
  # Plan required only for scope=research; exploratory renders N/A
  if [[ "$CURRENT_SCOPE" == "research" ]]; then
    if is_stub_or_empty "$EFFECTIVE_PLAN"; then
      echo "Error: --mark-complete requires a non-empty Plan / Recommendations section for scope=research" >&2
      exit 1
    fi
  else
    # exploratory: if Plan is empty/stub, render as N/A
    if is_stub_or_empty "$EFFECTIVE_PLAN"; then
      EFFECTIVE_PLAN="_N/A — exploratory_"
    fi
  fi
fi

# Determine status
if [[ "$MARK_COMPLETE" == true ]]; then
  STATUS="complete"
  EXPLORATION_STATUS="complete"
  SYNTHESIS_STATUS="complete"
else
  STATUS="synthesis"
  EXPLORATION_STATUS="complete"
  SYNTHESIS_STATUS="in_progress"
fi

# Escape goal for YAML
GOAL_YAML=$(escape_yaml "$CURRENT_GOAL")

TEMP_FILE="${REPORT_PATH}.tmp.$$"

cat > "$TEMP_FILE" << EOF
---
generated: "$CURRENT_GENERATED"
goal: $GOAL_YAML
scope: "$CURRENT_SCOPE"
report_path: "$REPORT_PATH"
status: "$STATUS"
phases:
  exploration: $EXPLORATION_STATUS
  synthesis: $SYNTHESIS_STATUS
---

# Research Report

> Generated: $CURRENT_GENERATED
> Updated: $TIMESTAMP
> Goal: $CURRENT_GOAL
> Scope: $CURRENT_SCOPE

## Summary
EOF

if [[ -n "$EFFECTIVE_SUMMARY" ]]; then
  echo "$EFFECTIVE_SUMMARY" >> "$TEMP_FILE"
else
  echo "_pending..._" >> "$TEMP_FILE"
fi

cat >> "$TEMP_FILE" << 'EOF'

## Findings
EOF

if [[ -n "$EFFECTIVE_FINDINGS" ]]; then
  echo "$EFFECTIVE_FINDINGS" >> "$TEMP_FILE"
else
  echo "_pending..._" >> "$TEMP_FILE"
fi

cat >> "$TEMP_FILE" << 'EOF'

## Plan / Recommendations
EOF

if [[ -n "$EFFECTIVE_PLAN" ]]; then
  echo "$EFFECTIVE_PLAN" >> "$TEMP_FILE"
else
  echo "_pending..._" >> "$TEMP_FILE"
fi

cat >> "$TEMP_FILE" << 'EOF'

## Open Questions
EOF

if [[ -n "$EFFECTIVE_OPEN_QUESTIONS" ]]; then
  echo "$EFFECTIVE_OPEN_QUESTIONS" >> "$TEMP_FILE"
else
  echo "_pending..._" >> "$TEMP_FILE"
fi

cat >> "$TEMP_FILE" << 'EOF'

## Sources & Evidence
EOF

if [[ -n "$EFFECTIVE_SOURCES" ]]; then
  echo "$EFFECTIVE_SOURCES" >> "$TEMP_FILE"
else
  echo "_pending..._" >> "$TEMP_FILE"
fi

# Atomically move temp file to final location
mv "$TEMP_FILE" "$REPORT_PATH"

echo "Research report compiled."
echo "  Report Path: $REPORT_PATH"
echo "  Status: $STATUS"
echo "  Timestamp: $TIMESTAMP"

if [[ "$MARK_COMPLETE" == true ]]; then
  echo ""
  echo "Research report is COMPLETE and ready for review."
fi

exit 0
