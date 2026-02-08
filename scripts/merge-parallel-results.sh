#!/bin/bash

# Agent Flow Parallel Results Merger
# Reads team orchestration state and checks if all sub-phases in a parallel group passed
# Outputs JSON with merge results

set -euo pipefail

# State file location
STATE_FILE=".claude/team-orchestration.local.md"

# Parse arguments
PARALLEL_GROUP=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Agent Flow - Merge Parallel Results

USAGE:
  merge-parallel-results.sh [OPTIONS]

OPTIONS:
  --parallel-group <name>    Name of parallel group to check (default: review_verification)
  -h, --help                 Show this help message

DESCRIPTION:
  Reads .claude/team-orchestration.local.md and extracts the status of all
  sub-phases within the specified parallel group. Determines if all sub-phases
  have passed.

OUTPUT:
  JSON object with:
  - group: Name of the parallel group
  - all_passed: true if all sub-phases passed, false otherwise
  - failed_phases: Array of sub-phase names that failed or are not passed
  - summary: Human-readable summary

EXAMPLES:
  merge-parallel-results.sh
  merge-parallel-results.sh --parallel-group review_verification

  # Example output:
  # {"group": "review_verification", "all_passed": true, "failed_phases": [], "summary": "All sub-phases passed"}
  # {"group": "review_verification", "all_passed": false, "failed_phases": ["verification"], "summary": "1 sub-phase(s) failed: verification"}

STATE FILE:
  .claude/team-orchestration.local.md

EXIT CODES:
  0: Success (regardless of pass/fail status)
  1: Error (state file not found, invalid format, etc.)
HELP_EOF
      exit 0
      ;;
    --parallel-group)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --parallel-group requires an argument" >&2
        exit 1
      fi
      PARALLEL_GROUP="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Default to review_verification
PARALLEL_GROUP="${PARALLEL_GROUP:-review_verification}"

# Check if state file exists
if [[ ! -f "$STATE_FILE" ]]; then
  echo "{\"error\": \"State file not found: $STATE_FILE\"}" >&2
  exit 1
fi

# Extract parallel group section from YAML frontmatter
# This is a simplified parser - looks for the parallel_groups section
PARALLEL_SECTION=$(sed -n "/^parallel_groups:/,/^gates:/p" "$STATE_FILE" 2>/dev/null || echo "")

if [[ -z "$PARALLEL_SECTION" ]]; then
  echo "{\"error\": \"No parallel_groups section found in state file\"}" >&2
  exit 1
fi

# Extract review and verification statuses
# We need to find the status fields under review and verification
REVIEW_STATUS=""
VERIFICATION_STATUS=""

# Simple state machine to parse YAML (limited to our specific structure)
IN_GROUP=false
IN_REVIEW=false
IN_VERIFICATION=false

while IFS= read -r line; do
  # Remove leading spaces for easier matching
  trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')

  case "$trimmed" in
    "${PARALLEL_GROUP}:")
      IN_GROUP=true
      ;;
    "review:")
      if [[ "$IN_GROUP" == true ]]; then
        IN_REVIEW=true
        IN_VERIFICATION=false
      fi
      ;;
    "verification:")
      if [[ "$IN_GROUP" == true ]]; then
        IN_VERIFICATION=true
        IN_REVIEW=false
      fi
      ;;
    "status:"*)
      if [[ "$IN_REVIEW" == true ]]; then
        REVIEW_STATUS=$(echo "$trimmed" | sed 's/status:[[:space:]]*//' | tr -d '"')
      elif [[ "$IN_VERIFICATION" == true ]]; then
        VERIFICATION_STATUS=$(echo "$trimmed" | sed 's/status:[[:space:]]*//' | tr -d '"')
      fi
      ;;
    "gates:")
      # End of parallel_groups section
      break
      ;;
  esac
done <<< "$PARALLEL_SECTION"

# Check if we found both statuses
if [[ -z "$REVIEW_STATUS" || -z "$VERIFICATION_STATUS" ]]; then
  echo "{\"error\": \"Could not extract status for review and/or verification\"}" >&2
  exit 1
fi

# Determine if all passed
FAILED_PHASES=()
ALL_PASSED=true

if [[ "$REVIEW_STATUS" != "passed" ]]; then
  FAILED_PHASES+=("review")
  ALL_PASSED=false
fi

if [[ "$VERIFICATION_STATUS" != "passed" ]]; then
  FAILED_PHASES+=("verification")
  ALL_PASSED=false
fi

# Build summary
if [[ "$ALL_PASSED" == true ]]; then
  SUMMARY="All sub-phases passed"
else
  FAILED_COUNT=${#FAILED_PHASES[@]}
  FAILED_LIST=$(IFS=,; echo "${FAILED_PHASES[*]}")
  SUMMARY="${FAILED_COUNT} sub-phase(s) failed: ${FAILED_LIST}"
fi

# Build JSON output
if [[ "$ALL_PASSED" == true ]]; then
  echo "{\"group\": \"$PARALLEL_GROUP\", \"all_passed\": true, \"failed_phases\": [], \"summary\": \"$SUMMARY\"}"
else
  # Build failed_phases array for JSON
  FAILED_JSON=""
  for phase in "${FAILED_PHASES[@]}"; do
    if [[ -n "$FAILED_JSON" ]]; then
      FAILED_JSON="${FAILED_JSON}, "
    fi
    FAILED_JSON="${FAILED_JSON}\"${phase}\""
  done
  echo "{\"group\": \"$PARALLEL_GROUP\", \"all_passed\": false, \"failed_phases\": [$FAILED_JSON], \"summary\": \"$SUMMARY\"}"
fi

exit 0
