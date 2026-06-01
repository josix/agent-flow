#!/bin/bash

# Agent Flow Team State Update Script
# Updates state file for tracking team orchestration progress
# Following ralph-loop patterns for atomic file operations

set -euo pipefail

# Temp file cleanup trap
TEMP_FILE=""
cleanup() {
  [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
  return 0
}
trap cleanup EXIT

# YAML escaping: collapse newlines, escape backslashes and double-quotes, wrap in quotes.
# All intent values must be stored as single-line escaped scalars.
escape_yaml() {
  local s="$1"
  s="${s//$'\n'/ }"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  echo "\"$s\""
}

# State file location
STATE_FILE=".claude/team-orchestration.local.md"

# Parse arguments
PHASE=""
ITERATION=""
GATE_RESULT=""
COMPLETE=false
AGENT=""
MESSAGE=""
PARALLEL_GROUP=""
TEAMMATE=""
MERGE_PARALLEL=false
# task_complexity = task-classification tier (NOT complexipy code/cognitive complexity)
TASK_COMPLEXITY=""
INTENT_GOAL=""
INTENT_DESCRIPTION=""
INTENT_ACTIONS=""
INTENT_CONSTRAINTS=""
INTENT_ASSUMPTIONS=""

print_usage() {
  cat << 'HELP_EOF'
Agent Flow - Team State Update

USAGE:
  update-team-state.sh [OPTIONS]

OPTIONS:
  --phase <phase>                  Update current phase (exploration, planning, implementation, review_verification, complete)
  --iteration <n>                  Update iteration count
  --gate-result <result>           Log gate result (passed, failed, skipped)
  --agent <name>                   Agent that performed the action (Riko, Senku, Loid, Lawliet, Alphonse)
  --message <text>                 Log message for the action
  --parallel-group <name>          Update parallel group status (e.g., review_verification)
  --teammate <name>                Update specific teammate status within parallel group (review, verification)
  --merge-parallel                 Check if all sub-phases in parallel group passed and update overall gate
  --complete                       Mark orchestration as complete
  --set-task-complexity <value>    Set task_complexity tier (task-classification tier, NOT complexipy code complexity)
  --set-intent-goal <value>        Set intent.goal (single-line; newlines collapsed)
  --set-intent-description <value> Set intent.description (single-line; newlines collapsed)
  --set-intent-actions <value>     Set intent.actions (single-line; newlines collapsed)
  --set-intent-constraints <value> Set intent.constraints (single-line; newlines collapsed)
  --set-intent-assumptions <value> Set intent.assumptions (single-line; newlines collapsed)
  -h, --help                       Show this help message

EXAMPLES:
  # Standard phase update
  update-team-state.sh --phase planning --gate-result passed --agent Riko --message "Found 5 relevant files"

  # Update parallel group start
  update-team-state.sh --parallel-group review_verification --gate-result in_progress --message "Starting parallel review and verification"

  # Update specific teammate status
  update-team-state.sh --parallel-group review_verification --teammate review --gate-result passed --agent Lawliet --message "Code review passed"

  # Merge parallel results
  update-team-state.sh --merge-parallel --parallel-group review_verification

  # Mark as complete
  update-team-state.sh --complete --agent Alphonse --message "All tests passing"

STATE FILE:
  .claude/team-orchestration.local.md
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
        echo "Error: --gate-result requires an argument (passed, failed, skipped, in_progress)" >&2
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
    --parallel-group)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --parallel-group requires a name argument" >&2
        exit 1
      fi
      PARALLEL_GROUP="$2"
      shift 2
      ;;
    --teammate)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --teammate requires a name argument (review, verification)" >&2
        exit 1
      fi
      TEAMMATE="$2"
      shift 2
      ;;
    --merge-parallel)
      MERGE_PARALLEL=true
      shift
      ;;
    --complete)
      COMPLETE=true
      shift
      ;;
    --set-task-complexity)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --set-task-complexity requires a value" >&2
        exit 1
      fi
      TASK_COMPLEXITY="$2"
      shift 2
      ;;
    --set-intent-goal)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --set-intent-goal requires a value" >&2
        exit 1
      fi
      INTENT_GOAL="$2"
      shift 2
      ;;
    --set-intent-description)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --set-intent-description requires a value" >&2
        exit 1
      fi
      INTENT_DESCRIPTION="$2"
      shift 2
      ;;
    --set-intent-actions)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --set-intent-actions requires a value" >&2
        exit 1
      fi
      INTENT_ACTIONS="$2"
      shift 2
      ;;
    --set-intent-constraints)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --set-intent-constraints requires a value" >&2
        exit 1
      fi
      INTENT_CONSTRAINTS="$2"
      shift 2
      ;;
    --set-intent-assumptions)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --set-intent-assumptions requires a value" >&2
        exit 1
      fi
      INTENT_ASSUMPTIONS="$2"
      shift 2
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
  echo "Run init-team-orchestration.sh first to initialize orchestration" >&2
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

# Detect whether a migration is needed (legacy file missing task_complexity/intent block).
# Check each field independently to avoid injecting duplicates in partially-migrated files.
NEEDS_MIGRATION=false
MIGRATE_TASK_COMPLEXITY=false
MIGRATE_INTENT=false
if [[ -n "$TASK_COMPLEXITY" || -n "$INTENT_GOAL" || -n "$INTENT_DESCRIPTION" || -n "$INTENT_ACTIONS" || -n "$INTENT_CONSTRAINTS" || -n "$INTENT_ASSUMPTIONS" ]]; then
  if ! grep -q '^task_complexity:' "$STATE_FILE"; then
    MIGRATE_TASK_COMPLEXITY=true
    NEEDS_MIGRATION=true
  fi
  if ! grep -q '^intent:' "$STATE_FILE"; then
    MIGRATE_INTENT=true
    NEEDS_MIGRATION=true
  fi
  if [[ "$NEEDS_MIGRATION" == true ]]; then
    echo "Note: migrated legacy state file — added task_complexity/intent schema block" >&2
  fi
fi

# Handle merge-parallel logic
if [[ "$MERGE_PARALLEL" == true && -n "$PARALLEL_GROUP" ]]; then
  # Extract parallel group status
  REVIEW_STATUS=$(sed -n "/parallel_groups:/,/^gates:/{ /review:/,/verification:/{/status:/p; }; }" "$STATE_FILE" | head -1 | sed 's/.*status: *//' | tr -d '"' 2>/dev/null || echo "pending")
  VERIFICATION_STATUS=$(sed -n "/parallel_groups:/,/^gates:/{ /verification:/,/^gates:/{/status:/p; }; }" "$STATE_FILE" | tail -1 | sed 's/.*status: *//' | tr -d '"' 2>/dev/null || echo "pending")

  # Check if both passed
  if [[ "$REVIEW_STATUS" == "passed" && "$VERIFICATION_STATUS" == "passed" ]]; then
    GATE_RESULT="passed"
    MESSAGE="${MESSAGE:-Both review and verification passed}"
  else
    GATE_RESULT="failed"
    FAILED_PHASES=""
    [[ "$REVIEW_STATUS" != "passed" ]] && FAILED_PHASES="review"
    [[ "$VERIFICATION_STATUS" != "passed" ]] && FAILED_PHASES="${FAILED_PHASES:+$FAILED_PHASES, }verification"
    MESSAGE="${MESSAGE:-Parallel group failed: $FAILED_PHASES}"
  fi
fi

# Export already-escaped values (full escape_yaml output, including surrounding quotes)
# via ENVIRON so awk does not reprocess backslash escapes (unlike -v assignment).
export INTENT_TASK_COMPLEXITY_ESC
export INTENT_GOAL_ESC
export INTENT_DESCRIPTION_ESC
export INTENT_ACTIONS_ESC
export INTENT_CONSTRAINTS_ESC
export INTENT_ASSUMPTIONS_ESC
INTENT_TASK_COMPLEXITY_ESC=$(escape_yaml "$TASK_COMPLEXITY")
INTENT_GOAL_ESC=$(escape_yaml "$INTENT_GOAL")
INTENT_DESCRIPTION_ESC=$(escape_yaml "$INTENT_DESCRIPTION")
INTENT_ACTIONS_ESC=$(escape_yaml "$INTENT_ACTIONS")
INTENT_CONSTRAINTS_ESC=$(escape_yaml "$INTENT_CONSTRAINTS")
INTENT_ASSUMPTIONS_ESC=$(escape_yaml "$INTENT_ASSUMPTIONS")

# Use awk for more reliable YAML editing.
# Intent values are read via ENVIRON[] to avoid awk -v backslash reprocessing.
# Boolean has_* flags indicate which intent fields were actually provided by the caller.
awk -v phase="$NEW_PHASE" \
    -v iteration="$NEW_ITERATION" \
    -v complete="$COMPLETE" \
    -v gate_result="$GATE_RESULT" \
    -v parallel_group="$PARALLEL_GROUP" \
    -v teammate="$TEAMMATE" \
    -v timestamp="$TIMESTAMP" \
    -v message="$MESSAGE" \
    -v agent="$AGENT" \
    -v current_phase="$CURRENT_PHASE" \
    -v needs_migration="$NEEDS_MIGRATION" \
    -v migrate_task_complexity="$MIGRATE_TASK_COMPLEXITY" \
    -v migrate_intent="$MIGRATE_INTENT" \
    -v has_task_complexity="$([[ -n "$TASK_COMPLEXITY" ]] && echo 1 || echo 0)" \
    -v has_intent_goal="$([[ -n "$INTENT_GOAL" ]] && echo 1 || echo 0)" \
    -v has_intent_description="$([[ -n "$INTENT_DESCRIPTION" ]] && echo 1 || echo 0)" \
    -v has_intent_actions="$([[ -n "$INTENT_ACTIONS" ]] && echo 1 || echo 0)" \
    -v has_intent_constraints="$([[ -n "$INTENT_CONSTRAINTS" ]] && echo 1 || echo 0)" \
    -v has_intent_assumptions="$([[ -n "$INTENT_ASSUMPTIONS" ]] && echo 1 || echo 0)" \
'
BEGIN {
  in_frontmatter = 0
  in_parallel_groups = 0
  in_target_group = 0
  in_teammate_section = 0
  skip_teammate_fields = 0
  frontmatter_done = 0
  migration_done = 0
  # Read intent values from ENVIRON (avoids awk -v backslash reprocessing).
  # escape_yaml already wrapped each value in double-quotes with inner \" escaping.
  # Emit them verbatim via the esc_* vars; do NOT re-add quotes in print statements.
  esc_task_complexity = ENVIRON["INTENT_TASK_COMPLEXITY_ESC"]
  esc_intent_goal     = ENVIRON["INTENT_GOAL_ESC"]
  esc_intent_description = ENVIRON["INTENT_DESCRIPTION_ESC"]
  esc_intent_actions  = ENVIRON["INTENT_ACTIONS_ESC"]
  esc_intent_constraints = ENVIRON["INTENT_CONSTRAINTS_ESC"]
  esc_intent_assumptions = ENVIRON["INTENT_ASSUMPTIONS_ESC"]
}

# Track frontmatter boundaries
/^---$/ {
  if (in_frontmatter == 0) {
    in_frontmatter = 1
    print
    next
  } else if (in_frontmatter == 1) {
    in_frontmatter = 0
    frontmatter_done = 1
    print
    next
  }
}

# Within frontmatter
in_frontmatter == 1 {
  # Update top-level fields
  if ($0 ~ /^current_phase:/) {
    print "current_phase: \"" phase "\""
    next
  }
  if ($0 ~ /^iteration:/) {
    print "iteration: " iteration
    next
  }
  if ($0 ~ /^active:/ && complete == "true") {
    print "active: false"
    next
  }

  # Migration-on-write: inject only missing schema fields after task: line.
  # Uses per-field flags (migrate_task_complexity / migrate_intent) so a
  # partially-migrated file never gets duplicate keys.
  if ($0 ~ /^task:/ && needs_migration == "true" && migration_done == 0) {
    print
    if (migrate_task_complexity == "true") {
      print "# task_complexity = task-classification tier (NOT complexipy code/cognitive complexity)"
      if (has_task_complexity) {
        print "task_complexity: " esc_task_complexity
      } else {
        print "task_complexity: \"unclassified\""
      }
    }
    if (migrate_intent == "true") {
      print "intent:"
      if (has_intent_goal) {
        print "  goal: " esc_intent_goal
      } else {
        print "  goal: \"\""
      }
      if (has_intent_description) {
        print "  description: " esc_intent_description
      } else {
        print "  description: \"\""
      }
      if (has_intent_actions) {
        print "  actions: " esc_intent_actions
      } else {
        print "  actions: \"\""
      }
      if (has_intent_constraints) {
        print "  constraints: " esc_intent_constraints
      } else {
        print "  constraints: \"\""
      }
      if (has_intent_assumptions) {
        print "  assumptions: " esc_intent_assumptions
      } else {
        print "  assumptions: \"\""
      }
    }
    migration_done = 1
    next
  }

  # task_complexity = task-classification tier (NOT complexipy code/cognitive complexity)
  if ($0 ~ /^task_complexity:/ && has_task_complexity) {
    print "task_complexity: " esc_task_complexity
    next
  }

  # Intent sub-key updates (indented under intent:)
  if ($0 ~ /^  goal:/ && has_intent_goal) {
    print "  goal: " esc_intent_goal
    next
  }
  if ($0 ~ /^  description:/ && has_intent_description) {
    print "  description: " esc_intent_description
    next
  }
  if ($0 ~ /^  actions:/ && has_intent_actions) {
    print "  actions: " esc_intent_actions
    next
  }
  if ($0 ~ /^  constraints:/ && has_intent_constraints) {
    print "  constraints: " esc_intent_constraints
    next
  }
  if ($0 ~ /^  assumptions:/ && has_intent_assumptions) {
    print "  assumptions: " esc_intent_assumptions
    next
  }

  # Track parallel_groups section
  if ($0 ~ /^parallel_groups:/) {
    in_parallel_groups = 1
    print
    next
  }
  if ($0 ~ /^gates:/) {
    in_parallel_groups = 0
    in_target_group = 0
    print
    next
  }

  # Within parallel_groups
  if (in_parallel_groups && parallel_group != "") {
    # Match the target parallel group (e.g., "  review_verification:")
    if ($0 ~ "^  " parallel_group ":") {
      in_target_group = 1
      print
      next
    }

    # Within target parallel group
    if (in_target_group) {
      # Check for teammate section
      if (teammate != "" && $0 ~ "^    " teammate ":") {
        in_teammate_section = 1
        skip_teammate_fields = 3  # status, timestamp, result
        print
        next
      }

      # Update teammate fields
      if (in_teammate_section && skip_teammate_fields > 0) {
        if ($0 ~ /^      status:/ && gate_result != "") {
          print "      status: \"" gate_result "\""
          skip_teammate_fields--
          next
        }
        if ($0 ~ /^      timestamp:/) {
          print "      timestamp: \"" timestamp "\""
          skip_teammate_fields--
          next
        }
        if ($0 ~ /^      result:/ && message != "") {
          print "      result: \"" message "\""
          skip_teammate_fields--
          next
        }
      }

      # Check if we left teammate section
      if (in_teammate_section && $0 ~ /^    [a-z]/) {
        in_teammate_section = 0
      }
    }
  }

  # Update current phase gate status
  if ($0 ~ "^  " current_phase ":" && gate_result != "" && parallel_group == "" && teammate == "") {
    print
    getline
    if ($0 ~ /^    status:/) {
      print "    status: \"" gate_result "\""
      next
    }
  }

  print
  next
}

# After frontmatter, just print everything
frontmatter_done == 1 {
  print
}
' "$STATE_FILE" > "$TEMP_FILE"

# Add log entry if we have agent/message info
if [[ -n "$AGENT" ]] || [[ -n "$MESSAGE" ]]; then
  # Capitalize first letter of phase (portable across shells)
  PHASE_CAPITALIZED=$(echo "$NEW_PHASE" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
  cat >> "$TEMP_FILE" << EOF

EOF
  if [[ -n "$PARALLEL_GROUP" && -n "$TEAMMATE" ]]; then
    echo "### Parallel Group: $PARALLEL_GROUP / Teammate: $TEAMMATE" >> "$TEMP_FILE"
  elif [[ -n "$PARALLEL_GROUP" ]]; then
    echo "### Parallel Group: $PARALLEL_GROUP" >> "$TEMP_FILE"
  else
    echo "### Phase: $PHASE_CAPITALIZED" >> "$TEMP_FILE"
  fi
  if [[ -n "$AGENT" ]]; then
    echo "- Agent: $AGENT" >> "$TEMP_FILE"
  fi
  if [[ -n "$MESSAGE" ]]; then
    echo "- Result: $MESSAGE" >> "$TEMP_FILE"
  fi
  if [[ -n "$GATE_RESULT" ]]; then
    echo "- Gate: $GATE_RESULT" >> "$TEMP_FILE"
  fi
  echo "- Timestamp: $TIMESTAMP" >> "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"
fi

# Atomically move temp file to final location
mv "$TEMP_FILE" "$STATE_FILE"

# Output status
echo "Team orchestration state updated."
if [[ -n "$PARALLEL_GROUP" && -n "$TEAMMATE" ]]; then
  echo "  Parallel Group: $PARALLEL_GROUP / Teammate: $TEAMMATE"
elif [[ -n "$PARALLEL_GROUP" ]]; then
  echo "  Parallel Group: $PARALLEL_GROUP"
else
  echo "  Phase: $CURRENT_PHASE -> $NEW_PHASE"
fi
echo "  Iteration: $NEW_ITERATION"
if [[ -n "$GATE_RESULT" ]]; then
  echo "  Gate Result: $GATE_RESULT"
fi
if [[ "$COMPLETE" == true ]]; then
  echo ""
  echo "Team orchestration marked as COMPLETE."
fi

exit 0
