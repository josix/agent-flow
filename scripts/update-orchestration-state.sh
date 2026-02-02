#!/bin/bash

# Agent Flow State Update Script
# Updates state file for tracking orchestration progress
# Following ralph-loop patterns for atomic file operations

set -euo pipefail

# Temp file cleanup trap
TEMP_FILE=""
cleanup() {
  [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
  return 0
}
trap cleanup EXIT

# State file location
STATE_FILE=".claude/orchestration.local.md"

# Parse arguments
PHASE=""
ITERATION=""
GATE_RESULT=""
COMPLETE=false
AGENT=""
MESSAGE=""

print_usage() {
  cat << 'HELP_EOF'
Agent Flow - State Update

USAGE:
  update-orchestration-state.sh [OPTIONS]

OPTIONS:
  --phase <phase>         Update current phase (exploration, planning, implementation, review, verification, complete)
  --iteration <n>         Update iteration count
  --gate-result <result>  Log gate result (passed, failed, skipped)
  --agent <name>          Agent that performed the action (Riko, Senku, Loid, Lawliet, Alphonse)
  --message <text>        Log message for the action
  --complete              Mark orchestration as complete
  -h, --help              Show this help message

EXAMPLES:
  # Move to planning phase
  update-orchestration-state.sh --phase planning --gate-result passed --agent Riko --message "Found 5 relevant files"

  # Log implementation progress
  update-orchestration-state.sh --phase implementation --agent Loid --message "Completed step 3 of 5"

  # Mark gate as failed
  update-orchestration-state.sh --gate-result failed --agent Alphonse --message "3 tests failing"

  # Increment iteration
  update-orchestration-state.sh --iteration 2

  # Mark as complete
  update-orchestration-state.sh --complete --agent Alphonse --message "All tests passing"

STATE FILE:
  .claude/orchestration.local.md
HELP_EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_usage
      exit 0
      ;;
    --phase)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --phase requires an argument" >&2
        exit 1
      fi
      PHASE="$2"
      shift 2
      ;;
    --iteration)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --iteration requires a number argument" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --iteration must be a positive integer, got: $2" >&2
        exit 1
      fi
      ITERATION="$2"
      shift 2
      ;;
    --gate-result)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --gate-result requires an argument (passed, failed, skipped)" >&2
        exit 1
      fi
      GATE_RESULT="$2"
      shift 2
      ;;
    --agent)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --agent requires a name argument" >&2
        exit 1
      fi
      AGENT="$2"
      shift 2
      ;;
    --message)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --message requires a text argument" >&2
        exit 1
      fi
      MESSAGE="$2"
      shift 2
      ;;
    --complete)
      COMPLETE=true
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
  echo "Run init-orchestration.sh first to initialize orchestration" >&2
  exit 1
fi

# Get current timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create temp file for atomic update
TEMP_FILE="${STATE_FILE}.tmp.$$"

# Read current state
CURRENT_PHASE=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^current_phase:' | sed 's/current_phase: *//' | tr -d '"')
CURRENT_ITERATION=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^iteration:' | sed 's/iteration: *//')

# Determine new phase and iteration
NEW_PHASE="${PHASE:-$CURRENT_PHASE}"
NEW_ITERATION="${ITERATION:-$CURRENT_ITERATION}"

if [[ "$COMPLETE" == true ]]; then
  NEW_PHASE="complete"
fi

# Update the frontmatter
{
  # Read frontmatter and update values
  sed -n '1,/^---$/p' "$STATE_FILE" | head -1

  # Process frontmatter content
  sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | while IFS= read -r line; do
    case "$line" in
      "current_phase:"*)
        echo "current_phase: \"$NEW_PHASE\""
        ;;
      "iteration:"*)
        echo "iteration: $NEW_ITERATION"
        ;;
      "active:"*)
        if [[ "$COMPLETE" == true ]]; then
          echo "active: false"
        else
          echo "$line"
        fi
        ;;
      "  ${CURRENT_PHASE}:")
        # Found the gate section for the current phase
        echo "$line"
        # Read the next line (status line) and update if gate-result provided
        if IFS= read -r status_line; then
          if [[ -n "$GATE_RESULT" ]] && [[ "$status_line" == *"status:"* ]]; then
            echo "    status: \"$GATE_RESULT\""
          else
            echo "$status_line"
          fi
        fi
        ;;
      *)
        echo "$line"
        ;;
    esac
  done

  echo "---"

  # Append everything after frontmatter
  awk '/^---$/{i++; next} i>=2' "$STATE_FILE"

  # Add log entry if we have agent/message info
  if [[ -n "$AGENT" ]] || [[ -n "$MESSAGE" ]]; then
    # Capitalize first letter of phase (portable across shells)
    PHASE_CAPITALIZED=$(echo "$NEW_PHASE" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
    echo ""
    echo "### Phase: $PHASE_CAPITALIZED"
    if [[ -n "$AGENT" ]]; then
      echo "- Agent: $AGENT"
    fi
    if [[ -n "$MESSAGE" ]]; then
      echo "- Result: $MESSAGE"
    fi
    if [[ -n "$GATE_RESULT" ]]; then
      echo "- Gate: $GATE_RESULT"
    fi
    echo "- Timestamp: $TIMESTAMP"
    echo ""
  fi

} > "$TEMP_FILE"

# Atomically move temp file to final location
mv "$TEMP_FILE" "$STATE_FILE"

# Output status
echo "Orchestration state updated."
echo "  Phase: $CURRENT_PHASE -> $NEW_PHASE"
echo "  Iteration: $NEW_ITERATION"
if [[ -n "$GATE_RESULT" ]]; then
  echo "  Gate Result: $GATE_RESULT"
fi
if [[ "$COMPLETE" == true ]]; then
  echo ""
  echo "Orchestration marked as COMPLETE."
fi

exit 0
