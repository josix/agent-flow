#!/bin/bash

# Agent Flow - Deep Dive Compilation Script
# Compiles parallel agent findings into structured deep-dive output
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
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  echo "\"$s\""
}

# State file location
STATE_FILE=".claude/deep-dive.local.md"

# Default values
OVERVIEW=""
ARCHITECTURE=""
CONVENTIONS=""
ANTIPATTERNS=""
QUICK_REFERENCE=""
AGENT_NOTES=""
TECH_STACK=""
ENTRY_POINTS=""
KEY_PATTERNS=""

# Print usage
print_usage() {
  cat << 'HELP_EOF'
Agent Flow - Deep Dive Compilation

USAGE:
  compile-deep-dive.sh [OPTIONS]

OPTIONS:
  --overview <text>         Repository overview section
  --tech-stack <text>       Technology stack description
  --entry-points <text>     Main entry points
  --key-patterns <text>     Key code patterns
  --architecture <text>     Architecture map (markdown table)
  --conventions <text>      Coding conventions
  --antipatterns <text>     Anti-patterns (DO NOT list)
  --quick-reference <text>  Quick reference table
  --agent-notes <text>      Additional agent findings
  --mark-complete           Mark deep-dive as complete
  -h, --help                Show this help message

DESCRIPTION:
  Compiles findings from parallel exploration agents into the
  structured deep-dive.local.md output format.

  Call this script after synthesis to update the deep-dive context
  with merged findings.

EXAMPLES:
  # Update overview section
  compile-deep-dive.sh --overview "Node.js TypeScript monorepo with 5 packages"

  # Update multiple sections
  compile-deep-dive.sh \
    --tech-stack "TypeScript, React, Node.js" \
    --entry-points "src/index.ts, src/cli.ts" \
    --conventions "Use strict TypeScript, prefer const"

  # Mark as complete
  compile-deep-dive.sh --mark-complete

STATE FILE:
  .claude/deep-dive.local.md
HELP_EOF
}

MARK_COMPLETE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_usage
      exit 0
      ;;
    --overview)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --overview requires an argument" >&2
        exit 1
      fi
      OVERVIEW="$2"
      shift 2
      ;;
    --tech-stack)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --tech-stack requires an argument" >&2
        exit 1
      fi
      TECH_STACK="$2"
      shift 2
      ;;
    --entry-points)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --entry-points requires an argument" >&2
        exit 1
      fi
      ENTRY_POINTS="$2"
      shift 2
      ;;
    --key-patterns)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --key-patterns requires an argument" >&2
        exit 1
      fi
      KEY_PATTERNS="$2"
      shift 2
      ;;
    --architecture)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --architecture requires an argument" >&2
        exit 1
      fi
      ARCHITECTURE="$2"
      shift 2
      ;;
    --conventions)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --conventions requires an argument" >&2
        exit 1
      fi
      CONVENTIONS="$2"
      shift 2
      ;;
    --antipatterns)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --antipatterns requires an argument" >&2
        exit 1
      fi
      ANTIPATTERNS="$2"
      shift 2
      ;;
    --quick-reference)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --quick-reference requires an argument" >&2
        exit 1
      fi
      QUICK_REFERENCE="$2"
      shift 2
      ;;
    --agent-notes)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --agent-notes requires an argument" >&2
        exit 1
      fi
      AGENT_NOTES="$2"
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

# Check if state file exists
if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: State file not found: $STATE_FILE" >&2
  echo "Run init-deep-dive.sh first to initialize deep-dive" >&2
  exit 1
fi

# Get current timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read current frontmatter values
CURRENT_SCOPE=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^scope:' | sed 's/scope: *//' | tr -d '"' || echo "full")
CURRENT_FOCUS=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^focus_path:' | sed 's/focus_path: *//' | tr -d '"' || echo "null")
CURRENT_AGENT_COUNT=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^agent_count:' | sed 's/agent_count: *//' || echo "5")

# Create temp file for atomic update
TEMP_FILE="${STATE_FILE}.tmp.$$"

# Determine phase status
if [[ "$MARK_COMPLETE" == true ]]; then
  PHASE="complete"
  EXPLORATION_STATUS="complete"
  SYNTHESIS_STATUS="complete"
  COMPILATION_STATUS="complete"
else
  PHASE="compilation"
  EXPLORATION_STATUS="complete"
  SYNTHESIS_STATUS="complete"
  COMPILATION_STATUS="in_progress"
fi

# Generate the new state file
cat > "$TEMP_FILE" << EOF
---
generated: "$TIMESTAMP"
scope: $CURRENT_SCOPE
focus_path: $CURRENT_FOCUS
expires_hint: "refresh when codebase significantly changes"
phase: "$PHASE"
agent_count: $CURRENT_AGENT_COUNT
phases:
  parallel_exploration:
    status: "$EXPLORATION_STATUS"
  synthesis:
    status: "$SYNTHESIS_STATUS"
  compilation:
    status: "$COMPILATION_STATUS"
---

# Deep-Dive Context

> Generated: $TIMESTAMP
> Scope: $CURRENT_SCOPE
$(if [[ "$CURRENT_FOCUS" != "null" ]]; then echo "> Focus: $CURRENT_FOCUS"; fi)

## Repository Overview
EOF

# Add overview content
if [[ -n "$OVERVIEW" || -n "$TECH_STACK" || -n "$ENTRY_POINTS" || -n "$KEY_PATTERNS" ]]; then
  if [[ -n "$TECH_STACK" ]]; then
    echo "- **Tech Stack**: $TECH_STACK" >> "$TEMP_FILE"
  fi
  if [[ -n "$ENTRY_POINTS" ]]; then
    echo "- **Entry Points**: $ENTRY_POINTS" >> "$TEMP_FILE"
  fi
  if [[ -n "$KEY_PATTERNS" ]]; then
    echo "- **Key Patterns**: $KEY_PATTERNS" >> "$TEMP_FILE"
  fi
  if [[ -n "$OVERVIEW" ]]; then
    echo "" >> "$TEMP_FILE"
    echo "$OVERVIEW" >> "$TEMP_FILE"
  fi
else
  echo "_No overview provided yet_" >> "$TEMP_FILE"
fi

# Add architecture map
cat >> "$TEMP_FILE" << 'EOF'

## Architecture Map
EOF

if [[ -n "$ARCHITECTURE" ]]; then
  echo "$ARCHITECTURE" >> "$TEMP_FILE"
else
  cat >> "$TEMP_FILE" << 'EOF'
| Component | Location | Purpose |
|-----------|----------|---------|
| _pending_ | _pending_ | _pending_ |
EOF
fi

# Add conventions
cat >> "$TEMP_FILE" << 'EOF'

## Conventions
EOF

if [[ -n "$CONVENTIONS" ]]; then
  echo "$CONVENTIONS" >> "$TEMP_FILE"
else
  echo "_No conventions documented yet_" >> "$TEMP_FILE"
fi

# Add anti-patterns
cat >> "$TEMP_FILE" << 'EOF'

## Anti-Patterns (DO NOT)
EOF

if [[ -n "$ANTIPATTERNS" ]]; then
  echo "$ANTIPATTERNS" >> "$TEMP_FILE"
else
  echo "_No anti-patterns documented yet_" >> "$TEMP_FILE"
fi

# Add quick reference
cat >> "$TEMP_FILE" << 'EOF'

## Key Files Quick Reference
EOF

if [[ -n "$QUICK_REFERENCE" ]]; then
  echo "$QUICK_REFERENCE" >> "$TEMP_FILE"
else
  cat >> "$TEMP_FILE" << 'EOF'
| Task | Look Here |
|------|-----------|
| _pending_ | _pending_ |
EOF
fi

# Add agent notes
cat >> "$TEMP_FILE" << 'EOF'

## Agent Notes
EOF

if [[ -n "$AGENT_NOTES" ]]; then
  echo "$AGENT_NOTES" >> "$TEMP_FILE"
else
  echo "_No additional agent notes_" >> "$TEMP_FILE"
fi

# Add compilation log entry
cat >> "$TEMP_FILE" << EOF

---

## Compilation Log

### Compiled
- Timestamp: $TIMESTAMP
- Phase: $PHASE
EOF

if [[ "$MARK_COMPLETE" == true ]]; then
  echo "- Status: **COMPLETE** - Ready for use with /orchestrate --use-deep-dive" >> "$TEMP_FILE"
fi

# Atomically move temp file to final location
mv "$TEMP_FILE" "$STATE_FILE"

# Output status
echo "Deep-Dive context compiled."
echo "  State File: $STATE_FILE"
echo "  Phase: $PHASE"
echo "  Timestamp: $TIMESTAMP"

if [[ "$MARK_COMPLETE" == true ]]; then
  echo ""
  echo "Deep-Dive is COMPLETE and ready for use."
  echo "Use: /orchestrate --use-deep-dive <task>"
fi

exit 0
