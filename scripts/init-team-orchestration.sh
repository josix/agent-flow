#!/bin/bash

# Agent Flow Team Orchestration State Initialization Script
# Creates state file for tracking team orchestration progress
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

# Parse arguments
TASK_PARTS=()
MAX_ITERATIONS=10
USE_DEEP_DIVE=false
FORCE_SEQUENTIAL=false

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Agent Flow - Team Orchestration State Initialization

USAGE:
  init-team-orchestration.sh [TASK...] [OPTIONS]

ARGUMENTS:
  TASK...    Task description to orchestrate (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>    Maximum iterations before auto-stop (default: 10)
  --use-deep-dive         Use existing deep-dive context for accelerated exploration
  --force-sequential      Force sequential mode even if Agent Teams is available
  -h, --help              Show this help message

DESCRIPTION:
  Initializes state tracking for a team orchestration session.
  Creates .claude/team-orchestration.local.md with YAML frontmatter to track:
  - Current phase (exploration, planning, implementation, review_verification, complete)
  - Orchestration mode (team vs sequential)
  - Parallel group status (review_verification with sub-phases)
  - Iteration count
  - Gate results for each phase
  - Deep-dive context availability
  - Timestamps and logs

  Automatically detects if Agent Teams feature is available via
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.

EXAMPLES:
  init-team-orchestration.sh Add authentication feature
  init-team-orchestration.sh --max-iterations 20 Fix the login bug
  init-team-orchestration.sh --use-deep-dive Add user profile page
  init-team-orchestration.sh --force-sequential Refactor cache layer

MODES:
  - team: Uses Agent Teams to parallelize review + verification phases
  - sequential: Falls back to sequential execution

STATE FILE:
  .claude/team-orchestration.local.md

MONITORING:
  # View current state:
  head -40 .claude/team-orchestration.local.md

  # Check current mode:
  grep '^mode:' .claude/team-orchestration.local.md

  # Check parallel group status:
  grep 'parallel_groups:' -A10 .claude/team-orchestration.local.md
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --max-iterations requires a number argument" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations must be a positive integer, got: $2" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --use-deep-dive)
      USE_DEEP_DIVE=true
      shift
      ;;
    --force-sequential)
      FORCE_SEQUENTIAL=true
      shift
      ;;
    *)
      # Non-option argument - collect all as task parts
      TASK_PARTS+=("$1")
      shift
      ;;
  esac
done

# Join all task parts with spaces
TASK="${TASK_PARTS[*]:-}"

# Validate task is non-empty
if [[ -z "$TASK" ]]; then
  echo "Error: No task description provided" >&2
  echo "" >&2
  echo "   Usage: init-team-orchestration.sh <task description>" >&2
  echo "   Example: init-team-orchestration.sh Add user authentication" >&2
  exit 1
fi

# Create .claude directory if it doesn't exist
mkdir -p .claude

# Get current timestamp in ISO 8601 format
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Check for existing deep-dive context
DEEP_DIVE_AVAILABLE=false
DEEP_DIVE_SCOPE=""
DEEP_DIVE_GENERATED=""

if [[ -f ".claude/deep-dive.local.md" ]]; then
  DEEP_DIVE_PHASE=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' ".claude/deep-dive.local.md" | grep '^phase:' | sed 's/phase: *//' | tr -d '"' 2>/dev/null || echo "")
  if [[ "$DEEP_DIVE_PHASE" == "complete" ]]; then
    DEEP_DIVE_AVAILABLE=true
    DEEP_DIVE_SCOPE=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' ".claude/deep-dive.local.md" | grep '^scope:' | sed 's/scope: *//' | tr -d '"' 2>/dev/null || echo "unknown")
    DEEP_DIVE_GENERATED=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' ".claude/deep-dive.local.md" | grep '^generated:' | sed 's/generated: *//' | tr -d '"' 2>/dev/null || echo "unknown")
  fi
fi

# Determine if we should use deep-dive context
USING_DEEP_DIVE=false
if [[ "$USE_DEEP_DIVE" == true && "$DEEP_DIVE_AVAILABLE" == true ]]; then
  USING_DEEP_DIVE=true
elif [[ "$USE_DEEP_DIVE" == true && "$DEEP_DIVE_AVAILABLE" == false ]]; then
  echo "Warning: --use-deep-dive specified but no complete deep-dive context found" >&2
  echo "         Run /deep-dive first to generate context" >&2
fi

# Get script directory to locate sibling scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for graphify knowledge graph via shared helper
GRAPH_YAML=$("$SCRIPT_DIR/detect-graph-context.sh" 2>/dev/null || echo "graph:
  available: false
  path: \"\"
  generated: \"\"
  nodes: 0
  edges: 0
  communities: 0")

# Parse values from YAML output for use in log messages
GRAPH_AVAILABLE=$(echo "$GRAPH_YAML" | grep '  available:' | sed 's/.*available: *//')
GRAPH_NODES=$(echo "$GRAPH_YAML" | grep '  nodes:' | sed 's/.*nodes: *//')
GRAPH_EDGES=$(echo "$GRAPH_YAML" | grep '  edges:' | sed 's/.*edges: *//')
GRAPH_COMMUNITIES=$(echo "$GRAPH_YAML" | grep '  communities:' | sed 's/.*communities: *//')

# Check team availability
TEAM_AVAILABLE=false
MODE="sequential"

if [[ "$FORCE_SEQUENTIAL" == false ]]; then
  TEAM_CHECK_OUTPUT=$(bash "$SCRIPT_DIR/check-team-availability.sh" 2>/dev/null || echo '{"available": false, "message": "Check failed"}')
  TEAM_AVAILABLE=$(echo "$TEAM_CHECK_OUTPUT" | grep -o '"available": *[^,}]*' | sed 's/"available": *//' 2>/dev/null || echo "false")

  if [[ "$TEAM_AVAILABLE" == "true" ]]; then
    MODE="team"
  fi
fi

# Create state file with YAML frontmatter (using atomic temp file + mv pattern)
STATE_FILE=".claude/team-orchestration.local.md"
TEMP_FILE="${STATE_FILE}.tmp.$$"  # Set before use so trap can clean up

cat > "$TEMP_FILE" << EOF
---
active: true
current_phase: "exploration"
iteration: 1
max_iterations: $MAX_ITERATIONS
started_at: "$TIMESTAMP"
task: $(escape_yaml "$TASK")
mode: "$MODE"
team_available: $TEAM_AVAILABLE
deep_dive:
  available: $DEEP_DIVE_AVAILABLE
  using: $USING_DEEP_DIVE
  scope: "$DEEP_DIVE_SCOPE"
  generated: "$DEEP_DIVE_GENERATED"
$GRAPH_YAML
parallel_groups:
  review_verification:
    status: "pending"
    started_at: ""
    completed_at: ""
    review:
      status: "pending"
      agent: "Lawliet"
      timestamp: ""
      result: ""
    verification:
      status: "pending"
      agent: "Alphonse"
      timestamp: ""
      result: ""
gates:
  exploration:
    status: "in_progress"
    timestamp: "$TIMESTAMP"
  planning:
    status: "pending"
  implementation:
    status: "pending"
  review_verification:
    status: "pending"
  review:
    status: "pending"
  verification:
    status: "pending"
---

## Team Orchestration Log

### Session Started
- Task: $(escape_yaml "$TASK")
- Max Iterations: $MAX_ITERATIONS
- Mode: $MODE
- Team Available: $TEAM_AVAILABLE
- Started: $TIMESTAMP
$(if [[ "$USING_DEEP_DIVE" == true ]]; then echo "- Deep-Dive Context: Using (scope: $DEEP_DIVE_SCOPE, generated: $DEEP_DIVE_GENERATED)"; elif [[ "$DEEP_DIVE_AVAILABLE" == true ]]; then echo "- Deep-Dive Context: Available but not requested (use --use-deep-dive)"; else echo "- Deep-Dive Context: Not available"; fi)
$(if [[ "$GRAPH_AVAILABLE" == true ]]; then echo "- Graph: Available at graphify-out/ ($GRAPH_NODES nodes, $GRAPH_EDGES edges, $GRAPH_COMMUNITIES communities)"; else echo "- Graph: Not available (run /graphify to build)"; fi)

---

EOF

# Atomically move temp file to final location
mv "$TEMP_FILE" "$STATE_FILE"

# Output initialization message
cat << EOF
Agent Flow Team Orchestration initialized.

Task: $TASK
Max Iterations: $MAX_ITERATIONS
Mode: $MODE (team_available=$TEAM_AVAILABLE, force_sequential=$FORCE_SEQUENTIAL)
State File: $STATE_FILE
EOF

if [[ "$MODE" == "team" ]]; then
  cat << EOF

TEAM MODE ENABLED:
  - Phases 1-3: Sequential (Exploration -> Planning -> Implementation)
  - Phase 4+5: Parallel (Review + Verification using Agent Teams)
  - Phase 6: Report & Completion
EOF
else
  cat << EOF

SEQUENTIAL MODE (Fallback):
  - Agent Teams not available or disabled
  - All phases run sequentially
EOF
fi

if [[ "$USING_DEEP_DIVE" == true ]]; then
  cat << EOF

Deep-Dive: ENABLED (scope: $DEEP_DIVE_SCOPE, generated: $DEEP_DIVE_GENERATED)
  - Phase 1 (Exploration) will use existing deep-dive context
  - Riko will perform targeted exploration only
EOF
elif [[ "$DEEP_DIVE_AVAILABLE" == true ]]; then
  cat << EOF

Deep-Dive: Available but not requested
  - Use --use-deep-dive to leverage existing context
  - Context scope: $DEEP_DIVE_SCOPE, generated: $DEEP_DIVE_GENERATED
EOF
else
  cat << EOF

Deep-Dive: Not available
  - Run /deep-dive first to generate comprehensive context
EOF
fi

if [[ "$GRAPH_AVAILABLE" == true ]]; then
  cat << EOF

Graph: Available at graphify-out/ ($GRAPH_NODES nodes, $GRAPH_EDGES edges, $GRAPH_COMMUNITIES communities)
  - Riko/Senku/Lawliet can query via MCP graphify tools
  - See the graphify-usage skill for query patterns and tool selection
EOF
else
  cat << EOF

Graph: Not available
  - Run /graphify to build knowledge graph from codebase
EOF
fi

cat << EOF

Current Phase: exploration
Iteration: 1/$MAX_ITERATIONS

Phases: exploration -> planning -> implementation -> review+verification (parallel) -> complete

IMPORTANT: The orchestrator must output:
  <orchestration-complete>TASK VERIFIED</orchestration-complete>
when all verification gates pass. Do NOT output this until verification succeeds.
EOF

exit 0
