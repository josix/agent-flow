#!/bin/bash
# Wrapper to locate a working Python with graphify installed and serve the graph.
# Resolves paths portably so .mcp.json stays user-agnostic.
set -euo pipefail

# Resolve the graph path relative to the project directory
GRAPH_PATH="${CLAUDE_PROJECT_DIR:-$(pwd)}/graphify-out/graph.json"

# Locate a Python interpreter with graphify (base) importable.
# Order: system python3/python, then pipx-installed graphify (shebang of its shim
# points at the venv's python — works for any pipx install, not just this user's).
# Note: graphifyy ships `mcp` as an OPTIONAL extra. We detect base graphify first,
# then check for `graphify.serve` (which requires `mcp`) separately so we can give
# a targeted install hint for each failure mode.
PYTHON=""
BASE_ONLY_METHOD=""  # remembers a python that has graphify but not graphify.serve

try_candidate() {
  # $1 = python path, $2 = install method label ("pip" or "pipx")
  local py="$1" method="$2"
  "$py" -c "import graphify" 2>/dev/null || return 1
  if "$py" -c "import graphify.serve" 2>/dev/null; then
    PYTHON="$py"
    return 0
  fi
  [[ -z "$BASE_ONLY_METHOD" ]] && BASE_ONLY_METHOD="$method"
  return 1
}

for candidate in python3 python; do
  command -v "$candidate" &>/dev/null && try_candidate "$candidate" "pip" && break
done

if [[ -z "$PYTHON" ]] && command -v graphify &>/dev/null; then
  PIPX_PYTHON=$(head -1 "$(command -v graphify)" | sed 's|^#!||')
  [[ -x "$PIPX_PYTHON" ]] && try_candidate "$PIPX_PYTHON" "pipx"
fi

if [[ -z "$PYTHON" ]]; then
  if [[ -n "$BASE_ONLY_METHOD" ]]; then
    echo "ERROR: graphify is installed but the 'mcp' extra is missing." >&2
    if [[ "$BASE_ONLY_METHOD" == "pipx" ]]; then
      echo "       Fix: pipx inject graphifyy mcp" >&2
    else
      echo "       Fix: pip install 'graphifyy[mcp]'" >&2
    fi
  else
    echo "ERROR: graphify is not installed." >&2
    echo "       Install one of:" >&2
    echo "         pip install 'graphifyy[mcp]'" >&2
    echo "         pipx install graphifyy && pipx inject graphifyy mcp" >&2
  fi
  # Graceful degrade — MCP server simply unavailable, not 'failed'; stderr messages remain for diagnostics.
  exit 0
fi

if [[ ! -f "$GRAPH_PATH" ]]; then
  echo "ERROR: Graph file not found: $GRAPH_PATH" >&2
  echo "       Run /graphify to build the knowledge graph first." >&2
  # Graceful degrade — MCP server simply unavailable, not 'failed'; stderr messages remain for diagnostics.
  exit 0
fi

exec "$PYTHON" -m graphify.serve "$GRAPH_PATH"
