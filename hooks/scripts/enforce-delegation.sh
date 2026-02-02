#!/bin/bash
set -euo pipefail

# Delegation Enforcement Hook (Fixed for Claude Code v2.x)
# Since Claude Code doesn't provide agent_name in hook inputs,
# we use file path restrictions to enforce delegation boundaries

# Input: Claude Code PreToolUse format
# {
#   "session_id": "...",
#   "hook_event_name": "PreToolUse",
#   "tool_name": "Write|Edit",
#   "tool_input": {
#     "file_path": "...",
#     "content": "..."
#   }
# }

# Check if jq is available
if ! command -v jq &> /dev/null; then
    # Fail open if jq not available (don't break sessions)
    echo '{"continue": true}'
    exit 0
fi

# Parse input (stdin)
INPUT=$(cat)

# Extract fields using actual Claude Code format
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# If no file path, allow (might be a different tool use)
if [[ -z "$FILE_PATH" ]]; then
  echo '{"continue": true}'
  exit 0
fi

# Directory structure for multi-agent orchestration:
# .senku/   - Planning files (Senku can write here)
# src/      - Source code (only Loid can write here)

# Allow writes to .senku/ directory (planning files)
if [[ "$FILE_PATH" == .senku/* ]] || [[ "$FILE_PATH" == */.senku/* ]]; then
  echo '{"continue": true}'
  exit 0
fi

# For source code and other files, provide informational guidance
# Agent tool restrictions already enforce delegation - Riko, Senku, Lawliet don't have Write/Edit tools
# This hook provides helpful context, not blocking

cat <<'EOF'
{
  "continue": true,
  "message": "Delegation Reminder: Writing to source code.\n\nIf you are Loid (Executor): Proceed with implementation.\nIf you are another agent without Write/Edit tools: Delegate to Loid via Task tool.\n\nAllowed planning directory: .senku/"
}
EOF
exit 0
