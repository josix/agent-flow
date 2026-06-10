#!/bin/bash
# test-init-state-escaping.sh — multi-line task input must not corrupt YAML frontmatter
# Style: test-ensure-gitignore.sh (FAILED counter, ✓/✗ echo, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAILED=0
TASK=$(printf 'line one\nline two')
# Literal collapse line expected inside escape_yaml(): s="${s//$'\n'/ }"
COLLAPSE_NEEDLE="s=\"\${s//\$'\\n'/ }\""

# Shared assertions for an init-generated state file
check_state_file() {
  # $1 = state file path, $2 = label
  local state="$1" label="$2"
  if [[ ! -f "$state" ]]; then
    echo "  ✗ $label: state file not created: $state"
    return 1
  fi
  local task_line fences
  task_line=$(grep '^task:' "$state" | head -1 || true)
  fences=$(grep -c '^---$' "$state" || true)
  if [[ "$task_line" != *"line one"* || "$task_line" != *"line two"* ]]; then
    echo "  ✗ $label: task line missing fragments: $task_line"
    return 1
  fi
  if grep -q '^line two' "$state"; then
    echo "  ✗ $label: raw newline leaked — a line starts with 'line two'"
    return 1
  fi
  if [[ "$fences" -lt 2 ]]; then
    echo "  ✗ $label: frontmatter fences broken (found $fences '---' lines)"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Test 1: init-orchestration.sh with multi-line task
# ---------------------------------------------------------------------------
echo "Test 1: init-orchestration.sh multi-line task"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX" && bash "$SCRIPT_DIR/init-orchestration.sh" "$TASK" >/dev/null 2>&1)
if check_state_file "$SANDBOX/.claude/orchestration.local.md" "init-orchestration"; then
  echo "  ✓ task collapsed onto one line, frontmatter intact"
else
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 2: init-team-orchestration.sh with multi-line task
# ---------------------------------------------------------------------------
echo "Test 2: init-team-orchestration.sh multi-line task"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX" && bash "$SCRIPT_DIR/init-team-orchestration.sh" "$TASK" >/dev/null 2>&1)
if check_state_file "$SANDBOX/.claude/team-orchestration.local.md" "init-team-orchestration"; then
  echo "  ✓ task collapsed onto one line, frontmatter intact"
else
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 3: init-deep-dive.sh structural parity (escape_yaml collapses newlines)
# ---------------------------------------------------------------------------
echo "Test 3: init-deep-dive.sh escape_yaml has newline collapse"
if grep -qF "$COLLAPSE_NEEDLE" "$SCRIPT_DIR/init-deep-dive.sh"; then
  echo "  ✓ collapse line present in init-deep-dive.sh escape_yaml()"
else
  echo "  ✗ collapse line missing from init-deep-dive.sh escape_yaml()"
  FAILED=$((FAILED+1))
fi
echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "============================================"
if [[ "$FAILED" -eq 0 ]]; then
  echo "✓ All tests passed"
  exit 0
else
  echo "✗ Failed tests: $FAILED"
  exit 1
fi
