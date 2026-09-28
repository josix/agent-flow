#!/bin/bash
# test-compile-deep-dive.sh — plain-bash tests for compile-deep-dive.sh
# Style: test-research-report.sh (FAILED counter, ✓/✗ echo, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="$SCRIPT_DIR/init-deep-dive.sh"
COMPILE_SCRIPT="$SCRIPT_DIR/compile-deep-dive.sh"

FAILED=0

run_init() {
  bash "$INIT_SCRIPT" "$@"
}

run_compile() {
  bash "$COMPILE_SCRIPT" "$@"
}

# ---------------------------------------------------------------------------
# Test 1: legacy call — only legacy flags produces no new headings
# ---------------------------------------------------------------------------
echo "Test 1: legacy call produces the 6 legacy headings, no new ones"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  run_init --scope full >/dev/null
  run_compile \
    --overview "A test repo" \
    --tech-stack "Bash" \
    --entry-points "main.sh" \
    --key-patterns "none" \
    --architecture "| A | B | C |" \
    --conventions "none" \
    --antipatterns "none" \
    --quick-reference "| A | B |" \
    --agent-notes "none" \
    --mark-complete >/dev/null

  STATE=".claude/deep-dive.local.md"
  PASS=true
  for heading in "## Repository Overview" "## Architecture Map" "## Conventions" \
                 "## Anti-Patterns (DO NOT)" "## Key Files Quick Reference" "## Agent Notes"; do
    grep -qF "$heading" "$STATE" || { echo "  ✗ Missing legacy heading: $heading"; PASS=false; }
  done
  for heading in "## Purpose & Use Cases" "## Key Flows" "## Gotchas & Failure Modes"; do
    if grep -qF "$heading" "$STATE"; then
      echo "  ✗ Unexpected new heading present in legacy-only call: $heading"
      PASS=false
    fi
  done
  if grep -q 'phase: "complete"' "$STATE" && [[ "$PASS" == true ]]; then
    echo "  ✓ Legacy call produces exactly the 6 legacy headings and phase=complete"
  else
    [[ "$PASS" == true ]] && echo "  ✗ phase is not complete"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 2: new flags produce all 9 headings in documented order
# ---------------------------------------------------------------------------
echo "Test 2: new flags produce 9 headings in documented order"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  run_init --scope full >/dev/null
  run_compile \
    --overview "A test repo" \
    --architecture "| A | B | C |" \
    --conventions "none" \
    --antipatterns "TODO: fix this" \
    --quick-reference "| A | B |" \
    --agent-notes "none" \
    --purpose "This project does X for Y" \
    --key-flows "1. main.sh:1 -- entry point" \
    --gotchas "Global state in main.sh:1" \
    --mark-complete >/dev/null

  STATE=".claude/deep-dive.local.md"
  LN_OVERVIEW=$(grep -n "^## Repository Overview$" "$STATE" | head -1 | cut -d: -f1)
  LN_PURPOSE=$(grep -n "^## Purpose & Use Cases$" "$STATE" | head -1 | cut -d: -f1)
  LN_ARCH=$(grep -n "^## Architecture Map$" "$STATE" | head -1 | cut -d: -f1)
  LN_FLOWS=$(grep -n "^## Key Flows$" "$STATE" | head -1 | cut -d: -f1)
  LN_CONV=$(grep -n "^## Conventions$" "$STATE" | head -1 | cut -d: -f1)
  LN_ANTI=$(grep -n "^## Anti-Patterns (DO NOT)$" "$STATE" | head -1 | cut -d: -f1)
  LN_GOTCHAS=$(grep -n "^## Gotchas & Failure Modes$" "$STATE" | head -1 | cut -d: -f1)
  LN_QUICKREF=$(grep -n "^## Key Files Quick Reference$" "$STATE" | head -1 | cut -d: -f1)
  LN_NOTES=$(grep -n "^## Agent Notes$" "$STATE" | head -1 | cut -d: -f1)

  if [[ -n "$LN_OVERVIEW" && -n "$LN_PURPOSE" && -n "$LN_ARCH" && -n "$LN_FLOWS" && \
        -n "$LN_CONV" && -n "$LN_ANTI" && -n "$LN_GOTCHAS" && -n "$LN_QUICKREF" && -n "$LN_NOTES" && \
        "$LN_OVERVIEW" -lt "$LN_PURPOSE" && "$LN_PURPOSE" -lt "$LN_ARCH" && \
        "$LN_ARCH" -lt "$LN_FLOWS" && "$LN_FLOWS" -lt "$LN_CONV" && \
        "$LN_CONV" -lt "$LN_ANTI" && "$LN_ANTI" -lt "$LN_GOTCHAS" && \
        "$LN_GOTCHAS" -lt "$LN_QUICKREF" && "$LN_QUICKREF" -lt "$LN_NOTES" ]]; then
    echo "  ✓ All 9 headings present in documented order"
  else
    echo "  ✗ Headings missing or out of order"
    grep -n '^## ' "$STATE"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 3: --key-flows with no value exits 1
# ---------------------------------------------------------------------------
echo "Test 3: --key-flows with no value exits 1"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  run_init --scope full >/dev/null
  if run_compile --key-flows >/dev/null 2>&1; then
    echo "  ✗ compile-deep-dive.sh exited 0 with missing --key-flows argument"
    exit 1
  else
    echo "  ✓ compile-deep-dive.sh exits non-zero with missing --key-flows argument"
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 4: special characters ($HOME, backticks, quotes) written literally
# ---------------------------------------------------------------------------
echo "Test 4: content with \$HOME, backticks, and quotes is written literally"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  run_init --scope full >/dev/null
  TRICKY='Contains $HOME and `backticks` and "quotes"'
  run_compile --purpose "$TRICKY" --mark-complete >/dev/null

  STATE=".claude/deep-dive.local.md"
  if grep -qF '$HOME' "$STATE" && grep -qF '`backticks`' "$STATE" && grep -qF '"quotes"' "$STATE"; then
    echo "  ✓ Special characters preserved literally"
  else
    echo "  ✗ Special characters were mangled"
    exit 1
  fi
) || ((FAILED++))
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
