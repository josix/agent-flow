#!/bin/bash
set -uo pipefail
# Note: -e removed to allow proper error handling

# Read input from stdin
input=$(cat)

# Check for jq availability - fail open if not available
if ! command -v jq &> /dev/null; then
  echo '{"decision": "approve", "reason": "jq not available, skipping teammate idle check", "systemMessage": "Teammate idle check skipped (jq unavailable)"}'
  exit 0
fi

# Extract teammate info
teammate_role=$(echo "$input" | jq -r '.teammate_role // ""' 2>/dev/null || echo "")
teammate_output=$(echo "$input" | jq -r '.teammate_output // ""' 2>/dev/null || echo "")

# Fail open if input is malformed
if [ -z "$teammate_role" ] || [ -z "$teammate_output" ]; then
  echo '{"decision": "approve", "reason": "Malformed input, skipping teammate idle check", "systemMessage": "Teammate idle check skipped (malformed input)"}'
  exit 0
fi

# Check quality based on teammate role
case "$teammate_role" in
  "reviewer"|"Lawliet")
    # For reviewer: verify output contains verdict and static analysis evidence.
    # The "reviewer" teammate role is always Lawliet (see commands/team-orchestrate.md),
    # which only ever emits APPROVED/NEEDS_CHANGES — BLOCKED is a Codex-only verdict
    # (Codex is an orchestrator-only Bash dispatch, not a teammate) and is not accepted here.
    has_verdict=$(echo "$teammate_output" | grep -iE "(APPROVED|NEEDS_CHANGES)" || echo "")
    has_evidence=$(echo "$teammate_output" | grep -iE "(static analysis|type check|lint|code quality|security|pattern)" || echo "")

    if [ -z "$has_verdict" ]; then
      echo '{"decision": "block", "reason": "Reviewer output must contain verdict (APPROVED/NEEDS_CHANGES)", "systemMessage": "Reviewer idle check failed: missing verdict"}'
      exit 0
    fi

    if [ -z "$has_evidence" ]; then
      echo '{"decision": "block", "reason": "Reviewer output must contain static analysis evidence", "systemMessage": "Reviewer idle check failed: missing evidence"}'
      exit 0
    fi
    ;;

  "verifier"|"Alphonse")
    # For verifier: verify output contains all four gate results
    has_tests=$(echo "$teammate_output" | grep -iE "(test|pytest|npm test)" || echo "")
    has_types=$(echo "$teammate_output" | grep -iE "(type|tsc|mypy)" || echo "")
    has_lint=$(echo "$teammate_output" | grep -iE "(lint|eslint|ruff)" || echo "")
    has_build=$(echo "$teammate_output" | grep -iE "(build|compilation)" || echo "")

    # Count how many gates were checked
    gate_count=0
    [ -n "$has_tests" ] && gate_count=$((gate_count + 1))
    [ -n "$has_types" ] && gate_count=$((gate_count + 1))
    [ -n "$has_lint" ] && gate_count=$((gate_count + 1))
    [ -n "$has_build" ] && gate_count=$((gate_count + 1))

    if [ $gate_count -lt 2 ]; then
      echo '{"decision": "block", "reason": "Verifier output must contain at least 2 verification gate results (tests, types, lint, build)", "systemMessage": "Verifier idle check failed: insufficient gate results"}'
      exit 0
    fi

    # Check for command output (not just status)
    has_output=$(echo "$teammate_output" | grep -iE "(PASS|FAIL|error|warning|✓|✗|0 errors)" || echo "")
    if [ -z "$has_output" ]; then
      echo '{"decision": "block", "reason": "Verifier output must contain command output, not just status", "systemMessage": "Verifier idle check failed: missing command output"}'
      exit 0
    fi
    ;;

  *)
    # For other teammates, approve without specific checks
    echo '{"decision": "approve", "reason": "Teammate idle check passed (no specific requirements)", "systemMessage": "Teammate idle check passed"}'
    exit 0
    ;;
esac

# All checks passed
echo '{"decision": "approve", "reason": "Teammate idle check passed", "systemMessage": "Teammate quality requirements met"}'
exit 0
