#!/bin/bash
set -euo pipefail
# Fail-open hook: every fallible command below is guarded so no branch can
# exit non-zero unhandled under -e. Belt-and-braces ERR trap forces exit 0
# even if some future edit reintroduces an unguarded fallible command.
trap 'exit 0' ERR

# Read input from stdin
input=$(cat) || input=""

# Fail open if jq unavailable
if ! command -v jq &> /dev/null; then
  exit 0
fi

prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null || echo "")

if [ -z "$prompt" ]; then
  exit 0
fi

# Notification skip: system-generated notifications or automated event payloads
if echo "$prompt" | grep -qE '<task-notification'; then
  exit 0
fi
if echo "$prompt" | grep -qE '^[[:space:]]*<[A-Za-z]'; then
  exit 0
fi

# Mid-orchestration skip: don't nudge if an orchestration is actively running.
STATE_FILE=".claude/orchestration.local.md"
if [ -f "$STATE_FILE" ]; then
  active=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null | grep '^active:' | sed 's/active: *//' | tr -d '"' || echo "")
  current_phase=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null | grep '^current_phase:' | sed 's/current_phase: *//' | tr -d '"' || echo "")
  fresh=$(find "$STATE_FILE" -mmin -1440 2>/dev/null || echo "")
  if [ "$active" = "true" ] && [ "$current_phase" != "complete" ] && [ -n "$fresh" ]; then
    exit 0
  fi
fi

# Short pronoun follow-up: never nudge these, even if they contain a task verb.
if echo "$prompt" | grep -qiE '^(please )?(fix|update|change|do) (it|that|them|this|these|those)\b'; then
  exit 0
fi
word_count=$(echo "$prompt" | wc -w | tr -d ' ')
if [ "$word_count" -le 4 ] && (echo "$prompt" | grep -qiE '\b(it|that|them|this|again)\b'); then
  exit 0
fi

# Only consider prompts with a concrete task verb.
if ! (echo "$prompt" | grep -qiE '\b(fix|implement|add|refactor|debug|build|create|update|change|modify)\b'); then
  exit 0
fi

# Skip if a concrete target token is present: filename-with-extension, path, CamelCase/snake_case identifier, or quoted string.
if echo "$prompt" | grep -qE '[A-Za-z0-9_-]+\.[a-z]+'; then
  exit 0
fi
if echo "$prompt" | grep -qE '/'; then
  exit 0
fi
if echo "$prompt" | grep -qE '[A-Za-z][a-z0-9]+[A-Z][A-Za-z0-9]*'; then
  exit 0
fi
if echo "$prompt" | grep -qE '[A-Za-z][A-Za-z0-9]*_[A-Za-z0-9_]+'; then
  exit 0
fi
if echo "$prompt" | grep -qE '"[^"]+"|'"'"'[^'"'"']+'"'"''; then
  exit 0
fi

echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"This looks like a new, unscoped orchestration request and no active orchestration is in progress. Apply the prompt-refinement skill: if scope is genuinely ambiguous, ask ONE clarifying question; otherwise state a reasonable assumption and proceed. Do NOT block short follow-ups."}}'
exit 0
