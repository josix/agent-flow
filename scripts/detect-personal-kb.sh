#!/bin/bash
# Detect personal knowledge base graph and emit a personal_kb: YAML block.
# Usage: detect-personal-kb.sh
# Input:  AGENT_FLOW_PERSONAL_KB_PATH env var (absolute path to personal KB root)
# Output: prints YAML key-value lines suitable for embedding in frontmatter.
#
# Unlike detect-graph-context.sh (which emits a RELATIVE graph_path),
# this script emits ABSOLUTE paths because the personal KB lives outside
# CLAUDE_PROJECT_DIR.
set -euo pipefail

PERSONAL_KB_AVAILABLE=false
PERSONAL_KB_PATH=""
PERSONAL_KB_GRAPH_PATH=""
PERSONAL_KB_GENERATED=""
PERSONAL_KB_NODES=0
PERSONAL_KB_EDGES=0
PERSONAL_KB_COMMUNITIES=0

emit_block() {
  cat << EOF
personal_kb:
  available: $PERSONAL_KB_AVAILABLE
  path: "$PERSONAL_KB_PATH"
  graph_path: "$PERSONAL_KB_GRAPH_PATH"
  generated: "$PERSONAL_KB_GENERATED"
  nodes: $PERSONAL_KB_NODES
  edges: $PERSONAL_KB_EDGES
  communities: $PERSONAL_KB_COMMUNITIES
EOF
}

# Check 1: env var must be set
if [[ -z "${AGENT_FLOW_PERSONAL_KB_PATH:-}" ]]; then
  emit_block
  exit 0
fi

# Expand the path (handles ~ and variables)
EXPANDED_PATH="${AGENT_FLOW_PERSONAL_KB_PATH/#\~/$HOME}"

# Check 2: path must exist
if [[ ! -d "$EXPANDED_PATH" ]]; then
  emit_block
  exit 0
fi

# Check 3: graph.json must exist
GRAPH_JSON="$EXPANDED_PATH/graphify-out/graph.json"
if [[ ! -f "$GRAPH_JSON" ]]; then
  emit_block
  exit 0
fi

# All checks passed — populate values
PERSONAL_KB_AVAILABLE=true
PERSONAL_KB_PATH="$EXPANDED_PATH"
PERSONAL_KB_GRAPH_PATH="$GRAPH_JSON"

MANIFEST_JSON="$EXPANDED_PATH/graphify-out/manifest.json"

# Read generated timestamp from manifest if available
if [[ -f "$MANIFEST_JSON" ]]; then
  if command -v jq &>/dev/null; then
    PERSONAL_KB_GENERATED=$(jq -r '.generated // .timestamp // ""' "$MANIFEST_JSON" 2>/dev/null || echo "")
  else
    PERSONAL_KB_GENERATED=$(grep '"generated"\|"timestamp"' "$MANIFEST_JSON" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
  fi
fi

# Parse node/edge/community counts from graph.json
if command -v jq &>/dev/null; then
  PERSONAL_KB_NODES=$(jq '.nodes | length' "$GRAPH_JSON" 2>/dev/null || echo 0)
  PERSONAL_KB_EDGES=$(jq '.links | length' "$GRAPH_JSON" 2>/dev/null || echo 0)
  # Communities: count distinct community values on nodes
  PERSONAL_KB_COMMUNITIES=$(jq '[.nodes[].community // empty] | unique | length' "$GRAPH_JSON" 2>/dev/null || echo 0)
fi

emit_block
