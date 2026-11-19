#!/bin/bash
# Detect Codex CLI availability and emit a codex: YAML block.
# Usage: detect-codex-context.sh
# Output: prints YAML key-value lines suitable for embedding in frontmatter.
#
# Auth model: ChatGPT subscription (not API key).
# Codex authenticates via "codex login"; the canonical artifact is auth.json (or session.json).
# Auth directory defaults to ~/.codex but can be overridden via $CODEX_HOME.
set -euo pipefail

CODEX_AVAILABLE=false
CODEX_BINARY=""
CODEX_AUTH_PRESENT=false

emit_block() {
  cat << EOF
codex:
  available: $CODEX_AVAILABLE
  binary: "$CODEX_BINARY"
  auth_present: $CODEX_AUTH_PRESENT
EOF
}

emit_disabled() {
  local reason="$1"
  BINARY=$(command -v codex 2>/dev/null || true)
  cat << EOF
codex:
  available: false
  binary: "$BINARY"
  auth_present: false
  reason: $reason
EOF
  exit 0
}

# Per-run opt-out when AGENT_FLOW_NO_CODEX is set to any non-empty value
# (same rule as AGENT_FLOW_NO_GITIGNORE). It wins over AGENT_FLOW_CODEX.
if [[ -n "${AGENT_FLOW_NO_CODEX:-}" ]]; then
  echo "info: AGENT_FLOW_NO_CODEX set — Codex co-review disabled for this run" >&2
  emit_disabled "opt-out via AGENT_FLOW_NO_CODEX"
fi

# Codex is off by default: the multi-lens review panel is the second opinion.
# Opt in per run with AGENT_FLOW_CODEX=1 (or init-orchestration.sh --codex).
case "$(printf '%s' "${AGENT_FLOW_CODEX:-}" | tr '[:upper:]' '[:lower:]')" in
  1|true|on|yes) ;;
  *)
    echo "info: Codex co-review is off by default — set AGENT_FLOW_CODEX=1 or pass --codex to enable" >&2
    emit_disabled "off by default (enable with AGENT_FLOW_CODEX=1 or --codex)"
    ;;
esac

# Check 1: binary must be on PATH
if ! CODEX_BIN=$(command -v codex 2>/dev/null); then
  echo "info: codex CLI not found on PATH — Codex co-review disabled" >&2
  emit_block
  exit 0
fi

CODEX_BINARY="$CODEX_BIN"

# Check 2: auth artifact must exist (auth.json or session.json under CODEX_DIR)
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
if [[ -s "$CODEX_DIR/auth.json" || -s "$CODEX_DIR/session.json" ]]; then
  CODEX_AUTH_PRESENT=true
else
  echo "info: codex binary found but no auth artifact in $CODEX_DIR — run 'codex login' to enable co-review" >&2
  emit_block
  exit 0
fi

# Both checks passed
CODEX_AVAILABLE=true

emit_block
