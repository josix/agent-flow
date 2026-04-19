#!/usr/bin/env bash
set -uo pipefail
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
if [[ -x "$PLUGIN_DIR/.venv/bin/python" ]]; then
  PY="$PLUGIN_DIR/.venv/bin/python"
else
  PY="$(command -v python3 || command -v python || true)"
fi
[[ -z "$PY" ]] && exit 0
exec "$PY" -S "$PLUGIN_DIR/hooks/scripts/log-event.py" "$@"
