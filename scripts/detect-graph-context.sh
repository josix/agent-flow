#!/bin/bash
# Detect graphify-out/graph.json and emit a graph: YAML block.
# Usage: detect-graph-context.sh [--project-dir <dir>]
# Output: prints YAML key-value lines suitable for embedding in frontmatter.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Parse optional --project-dir flag
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

GRAPH_JSON="$PROJECT_DIR/graphify-out/graph.json"
MANIFEST_JSON="$PROJECT_DIR/graphify-out/manifest.json"

GRAPH_AVAILABLE=false
GRAPH_PATH=""
GRAPH_GENERATED=""
GRAPH_NODES=0
GRAPH_EDGES=0
GRAPH_COMMUNITIES=0

if [[ -f "$GRAPH_JSON" ]]; then
  GRAPH_AVAILABLE=true
  GRAPH_PATH="graphify-out/graph.json"

  # Read generated timestamp from manifest if available
  if [[ -f "$MANIFEST_JSON" ]]; then
    if command -v jq &>/dev/null; then
      GRAPH_GENERATED=$(jq -r '.generated // .timestamp // ""' "$MANIFEST_JSON" 2>/dev/null || echo "")
    else
      GRAPH_GENERATED=$(grep '"generated"\|"timestamp"' "$MANIFEST_JSON" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    fi
  fi

  # Parse node/edge/community counts from graph.json
  if command -v jq &>/dev/null; then
    GRAPH_NODES=$(jq '.nodes | length' "$GRAPH_JSON" 2>/dev/null || echo 0)
    GRAPH_EDGES=$(jq '.links | length' "$GRAPH_JSON" 2>/dev/null || echo 0)
    # Communities: count distinct community values on nodes
    GRAPH_COMMUNITIES=$(jq '[.nodes[].community // empty] | unique | length' "$GRAPH_JSON" 2>/dev/null || echo 0)
  fi
fi

# Emit YAML block
cat << EOF
graph:
  available: $GRAPH_AVAILABLE
  path: "$GRAPH_PATH"
  generated: "$GRAPH_GENERATED"
  nodes: $GRAPH_NODES
  edges: $GRAPH_EDGES
  communities: $GRAPH_COMMUNITIES
EOF
