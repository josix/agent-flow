#!/bin/bash
# Detect JEV (System One) availability and emit a jev: YAML block.
# Usage: detect-jev-context.sh
# Output: prints YAML key-value lines suitable for embedding in frontmatter.
#
# JEV is opt-in (unlike Codex, which is on whenever installed and logged in):
# a stray API key set for another tool should not start sending diffs to a
# new early-access vendor. See AGENT_FLOW_JEV below.
set -euo pipefail

JEV_DEFAULT_MODEL="jev-1.13.0"

JEV_AVAILABLE=false
API_KEY_PRESENT=false
KEY_ENV="TYPESAFE_API_KEY"
MODEL="$JEV_DEFAULT_MODEL"
REASON=""

# Model: AGENT_FLOW_JEV_MODEL overrides, validated ^[A-Za-z0-9._-]+$; else default.
if [[ -n "${AGENT_FLOW_JEV_MODEL:-}" ]]; then
  if [[ "${AGENT_FLOW_JEV_MODEL}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    MODEL="$AGENT_FLOW_JEV_MODEL"
  else
    echo "warn: AGENT_FLOW_JEV_MODEL is invalid — using $JEV_DEFAULT_MODEL" >&2
    MODEL="$JEV_DEFAULT_MODEL"
  fi
fi

emit_block() {
  cat << EOF
jev:
  available: $JEV_AVAILABLE
  api_key_present: $API_KEY_PRESENT
  key_env: "$KEY_ENV"
  model: "$MODEL"
EOF
  if [[ -n "$REASON" ]]; then
    printf '  reason: "%s"\n' "$REASON"
  fi
}

# 1. Per-run kill switch. Wins over the opt-in.
if [[ "${AGENT_FLOW_NO_JEV:-}" == "1" ]]; then
  echo "info: AGENT_FLOW_NO_JEV=1 set — JEV signal disabled for this run" >&2
  REASON="opt-out via AGENT_FLOW_NO_JEV"
  emit_block
  exit 0
fi

# 2. Opt-in is required.
if [[ "${AGENT_FLOW_JEV:-}" != "1" ]]; then
  REASON="not enabled (set AGENT_FLOW_JEV=1)"
  emit_block
  exit 0
fi

# 3. Key env var name must be a valid shell identifier.
KEY_ENV="${AGENT_FLOW_JEV_API_KEY_ENV:-TYPESAFE_API_KEY}"
if ! [[ "$KEY_ENV" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  REASON="invalid AGENT_FLOW_JEV_API_KEY_ENV"
  KEY_ENV=""
  emit_block
  exit 0
fi

# 4. Required binaries.
if ! command -v curl >/dev/null 2>&1; then
  REASON="curl not found"
  emit_block
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  REASON="jq not found"
  emit_block
  exit 0
fi

# 5. API key value (never printed).
KEY_VALUE="${!KEY_ENV:-}"
if [[ -z "$KEY_VALUE" ]]; then
  API_KEY_PRESENT=false
  REASON="api key not set ($KEY_ENV)"
  emit_block
  exit 0
fi

# 6. Everything checked out.
API_KEY_PRESENT=true
JEV_AVAILABLE=true
emit_block
