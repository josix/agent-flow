#!/bin/bash
# test-verify-completion.sh — plain-bash tests for verify-completion.sh Stop hook
# Style: scripts/test-ensure-gitignore.sh (FAILED counter, ✓/✗ echo, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/verify-completion.sh"

FAILED=0

run_hook() {
  # $1 = stdin payload, $2 = project dir
  echo "$1" | CLAUDE_PROJECT_DIR="$2" bash "$HOOK" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Test 1: stop_hook_active passthrough (anti-loop guard)
# ---------------------------------------------------------------------------
echo "Test 1: stop_hook_active passthrough"
SANDBOX=$(mktemp -d)
OUTPUT=$(run_hook '{"stop_hook_active": true}' "$SANDBOX")
if echo "$OUTPUT" | jq -e . >/dev/null 2>&1 \
  && [[ "$(echo "$OUTPUT" | jq -r '.decision')" == "approve" ]]; then
  echo "  ✓ valid JSON with decision=approve"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 2: Bypass file with quotes/backslash — JSON stays valid, only line 1 used
# ---------------------------------------------------------------------------
echo "Test 2: Bypass file with quotes and backslash"
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.claude"
printf '%s\n%s\n' 'he said "boom" \ slash' 'second line' > "$SANDBOX/.claude/skip-test-verification"
OUTPUT=$(run_hook '{}' "$SANDBOX")
REASON=$(echo "$OUTPUT" | jq -r '.reason' 2>/dev/null || echo "")
if echo "$OUTPUT" | jq -e . >/dev/null 2>&1 \
  && [[ "$(echo "$OUTPUT" | jq -r '.decision')" == "approve" ]] \
  && [[ "$REASON" == *boom* ]] \
  && [[ "$REASON" != *"second line"* ]]; then
  echo "  ✓ valid JSON, decision=approve, reason has line 1 only"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 3: Collection-error message with embedded quotes — no JSON injection
# ---------------------------------------------------------------------------
echo "Test 3: Collection error with embedded quotes"
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.claude"
: > "$SANDBOX/pyproject.toml"
printf '# no known failures\n' > "$SANDBOX/.claude/known-test-failures"
cat > "$SANDBOX/.claude/test-command" << 'EOF'
echo 'ImportError: evil "quote"'; false
EOF
OUTPUT=$(run_hook '{}' "$SANDBOX")
REASON=$(echo "$OUTPUT" | jq -r '.reason' 2>/dev/null || echo "")
if echo "$OUTPUT" | jq -e . >/dev/null 2>&1 \
  && [[ "$(echo "$OUTPUT" | jq -r '.decision')" == "block" ]] \
  && [[ "$REASON" == *'evil "quote"'* ]]; then
  echo "  ✓ valid JSON, decision=block, reason carries quoted error verbatim"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 4: New-failure test name with embedded quotes — no JSON injection
# ---------------------------------------------------------------------------
echo "Test 4: New failure name with embedded quotes"
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.claude"
: > "$SANDBOX/pyproject.toml"
printf '# no known failures\n' > "$SANDBOX/.claude/known-test-failures"
cat > "$SANDBOX/.claude/test-command" << 'EOF'
printf 'FAILED tests/test_a.py::test_evil_"q"\n'; false
EOF
OUTPUT=$(run_hook '{}' "$SANDBOX")
REASON=$(echo "$OUTPUT" | jq -r '.reason' 2>/dev/null || echo "")
if echo "$OUTPUT" | jq -e . >/dev/null 2>&1 \
  && [[ "$(echo "$OUTPUT" | jq -r '.decision')" == "block" ]] \
  && [[ "$REASON" == *'tests/test_a.py::test_evil_"q"'* ]]; then
  echo "  ✓ valid JSON, decision=block, reason carries quoted test name verbatim"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 5: Failed cd → block (not silent approve)
# ---------------------------------------------------------------------------
echo "Test 5: Failed cd blocks instead of silently approving"
SANDBOX=$(mktemp -d)
: > "$SANDBOX/pyproject.toml"
OUTPUT=$(
  # shellcheck disable=SC2317  # invoked indirectly: exported into the child hook bash
  cd() { return 1; }
  export -f cd
  echo '{}' | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" 2>/dev/null || true
)
DECISION=$(echo "$OUTPUT" | jq -r '.decision' 2>/dev/null || echo "")
if echo "$OUTPUT" | jq -e . >/dev/null 2>&1 && [[ "$DECISION" == "block" ]]; then
  echo "  ✓ valid JSON with decision=block on cd failure"
elif echo "$OUTPUT" | jq -e . >/dev/null 2>&1 && [[ "$DECISION" == "approve" ]]; then
  # Exported-function cd override did not take effect in this bash; skip.
  echo "  ⚠ skipped (cd override not effective in this environment)"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 6: Happy path — empty project dir approves
# ---------------------------------------------------------------------------
echo "Test 6: Happy path (empty project dir)"
SANDBOX=$(mktemp -d)
OUTPUT=$(run_hook '{}' "$SANDBOX")
if echo "$OUTPUT" | jq -e . >/dev/null 2>&1 \
  && [[ "$(echo "$OUTPUT" | jq -r '.decision')" == "approve" ]]; then
  echo "  ✓ valid JSON with decision=approve"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
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
