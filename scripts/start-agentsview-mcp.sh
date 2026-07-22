#!/bin/bash
# Guard wrapper for the AgentsView MCP server.
# Resolves paths portably so .mcp.json stays user-agnostic and degrades
# gracefully when the agentsview CLI is not installed or opted out.
set -euo pipefail

if [[ "${AGENT_FLOW_NO_AGENTSVIEW:-}" == "1" ]]; then
  echo "info: AGENT_FLOW_NO_AGENTSVIEW=1 set — AgentsView MCP server disabled" >&2
  exit 0
fi

if ! command -v agentsview &>/dev/null; then
  echo "ERROR: agentsview is not installed." >&2
  echo "       See docs/guides/using-agentsview.md for install instructions." >&2
  # Graceful degrade — MCP server simply unavailable, not 'failed'.
  exit 0
fi

exec agentsview mcp
