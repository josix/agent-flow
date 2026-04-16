#!/bin/bash
set -uo pipefail
# Note: -e removed to allow proper error handling

# Read input from stdin
input=$(cat)

# Check for jq availability - fail open if not available
if ! command -v jq &> /dev/null; then
  echo '{"decision": "approve", "reason": "jq not available, skipping task completion check", "systemMessage": "Task completion check skipped (jq unavailable)"}'
  exit 0
fi

# Extract task completion info
task_status=$(echo "$input" | jq -r '.task_status // ""' 2>/dev/null || echo "")
completion_message=$(echo "$input" | jq -r '.completion_message // ""' 2>/dev/null || echo "")

# Fail open if input is malformed
if [ -z "$task_status" ] || [ -z "$completion_message" ]; then
  echo '{"decision": "approve", "reason": "Malformed input, skipping task completion check", "systemMessage": "Task completion check skipped (malformed input)"}'
  exit 0
fi

# Only check tasks marked as "complete" or "done"
if ! echo "$task_status" | grep -qiE "(complete|done|finished)"; then
  echo '{"decision": "approve", "reason": "Task not marked complete, no validation needed", "systemMessage": "Task completion check skipped (not complete)"}'
  exit 0
fi

# Verify completion message contains concrete results (not just status change)
message_length=${#completion_message}
if [ "$message_length" -lt 20 ]; then
  echo '{"decision": "block", "reason": "Completion message too short - must provide concrete evidence of completion", "systemMessage": "Task completion check failed: insufficient completion message"}'
  exit 0
fi

# Check for evidence indicators in completion message
has_evidence=0

# Check for file mentions
if echo "$completion_message" | grep -qE "([a-zA-Z0-9_-]+\.(ts|js|py|go|java|rs|md|json|yaml|sh)|src/|tests/|\./)"; then
  has_evidence=1
fi

# Check for verification indicators
if echo "$completion_message" | grep -qiE "(test|verified|checked|passed|validated|built|compiled)"; then
  has_evidence=1
fi

# Check for concrete actions
if echo "$completion_message" | grep -qiE "(created|updated|modified|fixed|added|removed|refactored|implemented)"; then
  has_evidence=1
fi

# Check for results/metrics
if echo "$completion_message" | grep -qE "([0-9]+\s+(file|test|error|warning|change))"; then
  has_evidence=1
fi

if [ $has_evidence -eq 0 ]; then
  echo '{"decision": "block", "reason": "Completion message must contain concrete evidence (files changed, tests run, actions taken)", "systemMessage": "Task completion check failed: no concrete evidence"}'
  exit 0
fi

# All checks passed
echo '{"decision": "approve", "reason": "Task completion check passed", "systemMessage": "Task completion has adequate evidence"}'
exit 0
