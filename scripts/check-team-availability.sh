#!/bin/bash

# Agent Flow Team Availability Check
# Checks if Claude Code Agent Teams feature is enabled
# Outputs JSON with availability status

set -euo pipefail

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Agent Flow - Check Team Availability

USAGE:
  check-team-availability.sh [OPTIONS]

OPTIONS:
  -h, --help    Show this help message

DESCRIPTION:
  Checks if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 is set in environment.
  Outputs JSON with availability status and informational message.

OUTPUT:
  JSON object with:
  - available: true/false
  - message: Informational message about status

EXAMPLES:
  check-team-availability.sh
  # Output: {"available": true, "message": "Agent Teams feature is enabled"}

EXIT CODES:
  0: Success (regardless of availability)
HELP_EOF
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Check for Agent Teams feature flag
TEAMS_ENABLED="${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}"

if [[ "$TEAMS_ENABLED" == "1" ]]; then
  echo '{"available": true, "message": "Agent Teams feature is enabled"}'
else
  echo '{"available": false, "message": "Agent Teams feature is not enabled. Set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to enable."}'
fi

exit 0
