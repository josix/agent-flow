#!/usr/bin/env bash
# analyze.sh — launcher for agent-flow transcript analyzer
# Usage: bash scripts/analyze.sh <subcommand> [options]
# See: python3 scripts/analyze/analyze.py --help

set -euo pipefail

# Resolve repo root (directory containing this script's parent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ANALYZE_PY="$REPO_ROOT/scripts/analyze/analyze.py"

# Prefer .venv Python if available
if [[ -x "$REPO_ROOT/.venv/bin/python" ]]; then
  PYTHON="$REPO_ROOT/.venv/bin/python"
elif command -v python3 &>/dev/null; then
  PYTHON="python3"
else
  echo "Error: python3 not found. Install Python 3.10+ or create a .venv at repo root." >&2
  exit 1
fi

exec "$PYTHON" "$ANALYZE_PY" "$@"
