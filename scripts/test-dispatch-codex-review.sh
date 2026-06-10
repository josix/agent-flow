#!/bin/bash
# test-dispatch-codex-review.sh — plain-bash tests for dispatch-codex-review.sh
# Style: test-ensure-gitignore.sh (FAILED counter, ✓/✗ echo, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/dispatch-codex-review.sh"

FAILED=0

# Build a git sandbox the dispatcher can run in (it needs origin/HEAD under set -e)
setup_sandbox() {
  local sb="$1"
  git init -q -b main "$sb"
  git -C "$sb" -c user.email=t@t -c user.name=t commit --allow-empty -m init -q
  git -C "$sb" update-ref refs/remotes/origin/main refs/heads/main
  git -C "$sb" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  mkdir -p "$sb/stubbin"
  printf 'task: test task\ncodex:\n  available: true\n' > "$sb/state.md"
  printf 'Lawliet findings: none\n' > "$sb/findings.md"
}

run_dispatch() {
  # $1 = sandbox dir; runs dispatcher from inside it with stubbin on PATH
  (
    cd "$1" || exit 1
    PATH="$1/stubbin:$PATH" bash "$DISPATCH" \
      --state-file state.md --lawliet-findings findings.md 2>/dev/null
  ) || true
}

# ---------------------------------------------------------------------------
# Test 1: Success — codex writes APPROVED, exit 0
# ---------------------------------------------------------------------------
echo "Test 1: Success path (codex exits 0, verdict APPROVED)"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/timeout" << 'EOF'
#!/bin/bash
shift
exec "$@"
EOF
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift 2; else shift; fi
done
cat > /dev/null
printf 'APPROVED\n' > "$out"
exit 0
EOF
chmod +x "$SANDBOX/stubbin/timeout" "$SANDBOX/stubbin/codex"
OUTPUT=$(run_dispatch "$SANDBOX")
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
if echo "$OUTPUT" | grep -q '^codex_ran: true$' \
  && echo "$OUTPUT" | grep -q '^codex_exit: 0$' \
  && echo "$OUTPUT" | grep -q '^codex_verdict: APPROVED$' \
  && [[ -n "$RAW_PATH" ]] \
  && ! echo "$OUTPUT" | grep -q '^codex_skip_reason:'; then
  echo "  ✓ codex_ran/exit/verdict correct, raw path set, no skip_reason"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 2: Timeout — timeout binary exits 124 → skip_reason: timeout
# ---------------------------------------------------------------------------
echo "Test 2: Timeout (exit 124 under timeout binary)"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/timeout" << 'EOF'
#!/bin/bash
cat > /dev/null
exit 124
EOF
chmod +x "$SANDBOX/stubbin/timeout"
OUTPUT=$(run_dispatch "$SANDBOX")
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
if echo "$OUTPUT" | grep -q '^codex_ran: true$' \
  && echo "$OUTPUT" | grep -q '^codex_exit: 124$' \
  && echo "$OUTPUT" | grep -q '^codex_verdict: ADVISORY$' \
  && echo "$OUTPUT" | grep -q '^codex_skip_reason: timeout$'; then
  echo "  ✓ exit 124 reported as ADVISORY with skip_reason=timeout"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 3: Other failure — codex exits 1 → skip_reason: error
# ---------------------------------------------------------------------------
echo "Test 3: Non-timeout failure (codex exits 1)"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/timeout" << 'EOF'
#!/bin/bash
shift
exec "$@"
EOF
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
cat > /dev/null
exit 1
EOF
chmod +x "$SANDBOX/stubbin/timeout" "$SANDBOX/stubbin/codex"
OUTPUT=$(run_dispatch "$SANDBOX")
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
if echo "$OUTPUT" | grep -q '^codex_ran: true$' \
  && echo "$OUTPUT" | grep -q '^codex_exit: 1$' \
  && echo "$OUTPUT" | grep -q '^codex_verdict: ADVISORY$' \
  && echo "$OUTPUT" | grep -q '^codex_skip_reason: error$'; then
  echo "  ✓ exit 1 reported as ADVISORY with skip_reason=error"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 4: Unavailable — codex.available: false → codex_ran: false
# ---------------------------------------------------------------------------
echo "Test 4: Codex unavailable in state file"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
printf 'task: test task\ncodex:\n  available: false\n' > "$SANDBOX/state.md"
OUTPUT=$(run_dispatch "$SANDBOX")
if echo "$OUTPUT" | grep -q '^codex_ran: false$' \
  && echo "$OUTPUT" | grep -q '^codex_skip_reason: unavailable$'; then
  echo "  ✓ codex_ran=false with skip_reason=unavailable"
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
