#!/bin/bash

# Agent Flow State Initialization Script
# Creates state file for tracking orchestration progress
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

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Agent Flow - State Initialization

USAGE:
  init-orchestration.sh [TASK...] [OPTIONS]

ARGUMENTS:
  TASK...    Task description to orchestrate (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>    Maximum iterations before auto-stop (default: 10)
  --use-deep-dive         Use existing deep-dive context for accelerated exploration
  -h, --help              Show this help message

DESCRIPTION:
  Initializes state tracking for a multi-agent orchestration session.
  Creates .claude/orchestration.local.md with YAML frontmatter to track:
  - Current phase (exploration, planning, implementation, review, verification, complete)
  - Iteration count
  - Gate results for each phase
  - Deep-dive context availability
  - Timestamps and logs

EXAMPLES:
  init-orchestration.sh Add authentication feature
  init-orchestration.sh --max-iterations 20 Fix the login bug
  init-orchestration.sh Refactor the cache layer --max-iterations 5
  init-orchestration.sh --use-deep-dive Add user profile page

DEEP-DIVE INTEGRATION:
  If a complete deep-dive context exists (.claude/deep-dive.local.md with phase=complete),
  use --use-deep-dive to leverage it during exploration. This:
  - Injects existing codebase context into Phase 1
  - Allows Riko to perform targeted exploration instead of full discovery
  - Speeds up orchestration for subsequent tasks

  To generate deep-dive context, run: /deep-dive

STATE FILE:
  .claude/orchestration.local.md

MONITORING:
  # View current state:
  head -30 .claude/orchestration.local.md

  # Check current phase:
  grep '^current_phase:' .claude/orchestration.local.md

  # Check deep-dive status:
  grep 'deep_dive:' -A4 .claude/orchestration.local.md
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
  echo "   Usage: init-orchestration.sh <task description>" >&2
  echo "   Example: init-orchestration.sh Add user authentication" >&2
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

# Check for graphify knowledge graph via shared helper
SCRIPT_DIR_ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAPH_YAML=$("$SCRIPT_DIR_ORCH/detect-graph-context.sh" 2>/dev/null || echo "graph:
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

# Check for personal knowledge base via shared helper
PERSONAL_KB_YAML=$("$SCRIPT_DIR_ORCH/detect-personal-kb.sh" 2>/dev/null || echo "personal_kb:
  available: false
  path: \"\"
  graph_path: \"\"
  generated: \"\"
  nodes: 0
  edges: 0
  communities: 0")

# Parse personal KB values for use in log messages
PERSONAL_KB_AVAILABLE=$(echo "$PERSONAL_KB_YAML" | grep '  available:' | sed 's/.*available: *//')
PERSONAL_KB_PATH_VAL=$(echo "$PERSONAL_KB_YAML" | grep '  path:' | sed 's/.*path: *//' | tr -d '"')
PERSONAL_KB_NODES=$(echo "$PERSONAL_KB_YAML" | grep '  nodes:' | sed 's/.*nodes: *//')
PERSONAL_KB_EDGES=$(echo "$PERSONAL_KB_YAML" | grep '  edges:' | sed 's/.*edges: *//')
PERSONAL_KB_COMMUNITIES=$(echo "$PERSONAL_KB_YAML" | grep '  communities:' | sed 's/.*communities: *//')

# Create state file with YAML frontmatter (using atomic temp file + mv pattern)
STATE_FILE=".claude/orchestration.local.md"
TEMP_FILE="${STATE_FILE}.tmp.$$"  # Set before use so trap can clean up

cat > "$TEMP_FILE" << EOF
---
active: true
current_phase: "exploration"
iteration: 1
max_iterations: $MAX_ITERATIONS
started_at: "$TIMESTAMP"
task: $(escape_yaml "$TASK")
deep_dive:
  available: $DEEP_DIVE_AVAILABLE
  using: $USING_DEEP_DIVE
  scope: "$DEEP_DIVE_SCOPE"
  generated: "$DEEP_DIVE_GENERATED"
$GRAPH_YAML
$PERSONAL_KB_YAML
gates:
  exploration:
    status: "in_progress"
    timestamp: "$TIMESTAMP"
  planning:
    status: "pending"
  implementation:
    status: "pending"
  review:
    status: "pending"
  verification:
    status: "pending"
---

## Orchestration Log

### Session Started
- Task: $(escape_yaml "$TASK")
- Max Iterations: $MAX_ITERATIONS
- Started: $TIMESTAMP
$(if [[ "$USING_DEEP_DIVE" == true ]]; then echo "- Deep-Dive Context: Using (scope: $DEEP_DIVE_SCOPE, generated: $DEEP_DIVE_GENERATED)"; elif [[ "$DEEP_DIVE_AVAILABLE" == true ]]; then echo "- Deep-Dive Context: Available but not requested (use --use-deep-dive)"; else echo "- Deep-Dive Context: Not available"; fi)
$(if [[ "$GRAPH_AVAILABLE" == true ]]; then echo "- Graph: Available at graphify-out/ ($GRAPH_NODES nodes, $GRAPH_EDGES edges, $GRAPH_COMMUNITIES communities)"; else echo "- Graph: Not available (run /graphify to build)"; fi)
$(if [[ "$PERSONAL_KB_AVAILABLE" == true ]]; then echo "- Personal KB: Available at $PERSONAL_KB_PATH_VAL ($PERSONAL_KB_NODES nodes, $PERSONAL_KB_EDGES edges, $PERSONAL_KB_COMMUNITIES communities)"; else echo "- Personal KB: Not configured (set AGENT_FLOW_PERSONAL_KB_PATH to enable)"; fi)

---

EOF

# Atomically move temp file to final location
mv "$TEMP_FILE" "$STATE_FILE"

# Output initialization message
cat << EOF
Agent Flow initialized.

Task: $TASK
Max Iterations: $MAX_ITERATIONS
State File: $STATE_FILE
EOF

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

if [[ "$PERSONAL_KB_AVAILABLE" == true ]]; then
  cat << EOF
Personal KB: Available at $PERSONAL_KB_PATH_VAL ($PERSONAL_KB_NODES nodes, $PERSONAL_KB_EDGES edges, $PERSONAL_KB_COMMUNITIES communities)
  - Riko/Senku/Lawliet can query via mcp__personal-kb__* tools
  - See the personal-kb-usage skill for cross-project recall query patterns
EOF
else
  cat << EOF
Personal KB: Not configured
  - Set AGENT_FLOW_PERSONAL_KB_PATH in your shell profile to enable
  - See docs/guides/using-personal-kb.md for setup instructions
EOF
fi

cat << EOF

Current Phase: exploration
Iteration: 1/$MAX_ITERATIONS

Phases: exploration -> planning -> implementation -> review -> verification -> complete

IMPORTANT: The orchestrator must output:
  <orchestration-complete>TASK VERIFIED</orchestration-complete>
when all verification gates pass. Do NOT output this until verification succeeds.
EOF

exit 0
