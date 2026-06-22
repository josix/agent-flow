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
# Test 4: fresh init-orchestration.sh produces report_requested: false
# ---------------------------------------------------------------------------
echo "Test 4: fresh init produces report_requested: false"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX" && bash "$SCRIPT_DIR/init-orchestration.sh" "some task" >/dev/null 2>&1)
STATE="$SANDBOX/.claude/orchestration.local.md"
if grep -q '^report_requested: false' "$STATE"; then
  echo "  ✓ report_requested: false present in fresh state file"
else
  echo "  ✗ report_requested: false not found in fresh state file"
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 5: --set-report-requested true flips the flag to true
# ---------------------------------------------------------------------------
echo "Test 5: --set-report-requested true flips flag to true"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX" && bash "$SCRIPT_DIR/init-orchestration.sh" "some task" >/dev/null 2>&1)
STATE="$SANDBOX/.claude/orchestration.local.md"
(cd "$SANDBOX" && bash "$SCRIPT_DIR/update-orchestration-state.sh" --set-report-requested true >/dev/null 2>&1)
if grep -q '^report_requested: true' "$STATE"; then
  echo "  ✓ report_requested flipped to true"
else
  echo "  ✗ report_requested was not flipped to true"
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 6: invalid value (e.g. "yes") exits non-zero and leaves file unchanged
# ---------------------------------------------------------------------------
echo "Test 6: invalid --set-report-requested value exits non-zero, file unchanged"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX" && bash "$SCRIPT_DIR/init-orchestration.sh" "some task" >/dev/null 2>&1)
STATE="$SANDBOX/.claude/orchestration.local.md"
BEFORE=$(cat "$STATE")
set +e
(cd "$SANDBOX" && bash "$SCRIPT_DIR/update-orchestration-state.sh" --set-report-requested yes >/dev/null 2>&1)
EXIT_CODE=$?
set -e
AFTER=$(cat "$STATE")
if [[ "$EXIT_CODE" -ne 0 ]]; then
  echo "  ✓ exited non-zero (exit $EXIT_CODE)"
else
  echo "  ✗ expected non-zero exit but got 0"
  FAILED=$((FAILED+1))
fi
if [[ "$BEFORE" == "$AFTER" ]]; then
  echo "  ✓ file unchanged after invalid argument"
else
  echo "  ✗ file was modified despite invalid argument"
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 7: migration — legacy state file lacking report_requested gains it
#          when any --set-* flag is used
# ---------------------------------------------------------------------------
echo "Test 7: migration adds report_requested to legacy state file"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX" && bash "$SCRIPT_DIR/init-orchestration.sh" "legacy task" >/dev/null 2>&1)
STATE="$SANDBOX/.claude/orchestration.local.md"
# Simulate a legacy file by stripping the report_requested line
sed -i.bak '/^report_requested:/d' "$STATE"
if grep -q '^report_requested:' "$STATE"; then
  echo "  ✗ setup: report_requested still present after simulated strip"
  FAILED=$((FAILED+1))
else
  # Trigger migration with any --set-* flag
  (cd "$SANDBOX" && bash "$SCRIPT_DIR/update-orchestration-state.sh" --set-task-complexity "research" >/dev/null 2>&1)
  if grep -q '^report_requested:' "$STATE"; then
    echo "  ✓ report_requested was added by migration"
  else
    echo "  ✗ report_requested was not added by migration"
    FAILED=$((FAILED+1))
  fi
fi
rm -rf "$SANDBOX"
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
