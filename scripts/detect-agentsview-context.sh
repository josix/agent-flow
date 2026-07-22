#!/bin/bash
# Detect AgentsView CLI availability and emit an agentsview: YAML block.
# Usage: detect-agentsview-context.sh
# Output: prints YAML key-value lines suitable for embedding in frontmatter.
#
# AgentsView exposes prior session history (search_sessions, list_sessions,
# get_session_overview, get_messages, search_content) via `agentsview mcp`,
# letting read-only subagents (Riko/Senku/Lawliet) search prior related
# sessions to leverage proven approaches and cross-verify current handling.
set -euo pipefail

AGENTSVIEW_AVAILABLE=false
AGENTSVIEW_BINARY=""
AGENTSVIEW_ARCHIVE_REACHABLE=false

emit_block() {
  cat << EOF
agentsview:
  available: $AGENTSVIEW_AVAILABLE
  binary: "$AGENTSVIEW_BINARY"
  archive_reachable: $AGENTSVIEW_ARCHIVE_REACHABLE
EOF
}

# Early exit: per-run opt-out via AGENT_FLOW_NO_AGENTSVIEW=1
if [[ "${AGENT_FLOW_NO_AGENTSVIEW:-}" == "1" ]]; then
  echo "info: AGENT_FLOW_NO_AGENTSVIEW=1 set — AgentsView session-history search disabled for this run" >&2
  BINARY=$(command -v agentsview 2>/dev/null || true)
  cat << EOF
agentsview:
  available: false
  binary: "$BINARY"
  archive_reachable: false
  reason: opt-out via AGENT_FLOW_NO_AGENTSVIEW
EOF
  exit 0
fi

# Check 1: binary must be on PATH
if ! AGENTSVIEW_BIN=$(command -v agentsview 2>/dev/null); then
  echo "info: agentsview CLI not found on PATH — session-history search disabled" >&2
  emit_block
  exit 0
fi

AGENTSVIEW_BINARY="$AGENTSVIEW_BIN"
AGENTSVIEW_AVAILABLE=true

# Check 2: cheap liveness probe against the local archive.
# archive_reachable is informational only — the MCP server auto-starts the
# archive daemon on first use, so a cold/hung daemon at detect time does NOT
# disable the integration. `available` stays true whenever the binary is
# present (and no opt-out is set); only the reason/message differs.
# Wrap with `timeout`/`gtimeout` if available so a stalled daemon can never hang the caller.
# If neither is on PATH (vanilla macOS without coreutils), fall back to a
# portable background-process watchdog so a hung daemon still cannot stall init.
run_probe() {
  if command -v timeout &>/dev/null; then
    timeout 5 agentsview session list --limit 1 --json
  elif command -v gtimeout &>/dev/null; then
    gtimeout 5 agentsview session list --limit 1 --json
  else
    # No timeout/gtimeout: bound the probe ourselves. set -m gives the
    # backgrounded probe its own process group so the watchdog can kill the
    # whole group (catching daemonizing grandchildren), not just the pid.
    # Residual risk: a grandchild that itself calls setsid escapes any
    # group kill (also true for GNU timeout) — accepted.
    set -m
    agentsview session list --limit 1 --json &
    local pid=$!
    set +m
    (
      sleep 5
      kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    ) &
    local watchdog=$!
    local rc
    wait "$pid" 2>/dev/null && rc=0 || rc=$?
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
    return $rc
  fi
}

if run_probe >/dev/null 2>&1; then
  AGENTSVIEW_ARCHIVE_REACHABLE=true
else
  echo "info: agentsview archive probe did not respond within timeout — integration still enabled; the MCP server will start the daemon on demand" >&2
fi

emit_block
