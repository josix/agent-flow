#!/bin/bash
# test-ensure-gitignore.sh — plain-bash tests for ensure-gitignore.sh
# Style: validate-plugin.sh (FAILED counter, ✓/✗ echo, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/ensure-gitignore.sh"

FAILED=0
START_MARKER="# >>> agent-flow managed (do not edit) >>>"
END_MARKER="# <<< agent-flow managed <<<"

run_helper() {
  bash "$HELPER" "$@"
}

# ---------------------------------------------------------------------------
# Test 1: Fresh-create — empty dir, .gitignore created with all markers/patterns
# ---------------------------------------------------------------------------
echo "Test 1: Fresh-create (empty dir)"
SANDBOX=$(mktemp -d)
run_helper --project-dir "$SANDBOX"
if [[ ! -f "$SANDBOX/.gitignore" ]]; then
  echo "  ✗ .gitignore not created"
  ((FAILED++))
else
  START_C=$(grep -cF "$START_MARKER" "$SANDBOX/.gitignore" || true)
  END_C=$(grep -cF "$END_MARKER" "$SANDBOX/.gitignore" || true)
  HAS_PATTERNS=true
  for pat in '.claude/*.local.*' '.claude/codex/' '.claude/explain-briefs/' '.claude/observability/' 'graphify-out/' 'explain-out/'; do
    grep -qF "$pat" "$SANDBOX/.gitignore" 2>/dev/null || { HAS_PATTERNS=false; break; }
  done
  if [[ "$START_C" -eq 1 && "$END_C" -eq 1 && "$HAS_PATTERNS" == true ]]; then
    echo "  ✓ .gitignore created with both markers and all 6 patterns"
  else
    echo "  ✗ .gitignore missing markers or patterns (start_count=$START_C end_count=$END_C patterns=$HAS_PATTERNS)"
    ((FAILED++))
  fi
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 2: Idempotency — run twice, file byte-identical, exactly one block
# ---------------------------------------------------------------------------
echo "Test 2: Idempotency (run twice)"
SANDBOX=$(mktemp -d)
run_helper --project-dir "$SANDBOX"
cp "$SANDBOX/.gitignore" "$SANDBOX/.gitignore.first"
run_helper --project-dir "$SANDBOX"
if cmp -s "$SANDBOX/.gitignore.first" "$SANDBOX/.gitignore"; then
  START_C=$(grep -cF "$START_MARKER" "$SANDBOX/.gitignore" || true)
  if [[ "$START_C" -eq 1 ]]; then
    echo "  ✓ File byte-identical after second run, exactly one START_MARKER"
  else
    echo "  ✗ START_MARKER count != 1 after second run (got $START_C)"
    ((FAILED++))
  fi
else
  echo "  ✗ File changed on second run (not idempotent)"
  ((FAILED++))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 3: Existing block update — old block missing explain-out/ + user lines
# ---------------------------------------------------------------------------
echo "Test 3: Existing-block update (old block missing explain-out/)"
SANDBOX=$(mktemp -d)
# Seed with old block (missing explain-out/) plus user lines
cat > "$SANDBOX/.gitignore" << 'EOF'
node_modules/
# my project stuff
# >>> agent-flow managed (do not edit) >>>
# Old generated block
.claude/*.local.*
.claude/codex/
graphify-out/
# <<< agent-flow managed <<<
dist/
EOF
run_helper --project-dir "$SANDBOX"
HAS_EXPLAIN=$(grep -c 'explain-out/' "$SANDBOX/.gitignore" || true)
START_C=$(grep -cF "$START_MARKER" "$SANDBOX/.gitignore" || true)
HAS_USER1=$(grep -cF 'node_modules/' "$SANDBOX/.gitignore" || true)
HAS_USER2=$(grep -cF 'dist/' "$SANDBOX/.gitignore" || true)
if [[ "$HAS_EXPLAIN" -ge 1 && "$START_C" -eq 1 && "$HAS_USER1" -ge 1 && "$HAS_USER2" -ge 1 ]]; then
  echo "  ✓ explain-out/ added, exactly one block, user lines preserved"
else
  echo "  ✗ explain-out=$HAS_EXPLAIN start_count=$START_C node_modules=$HAS_USER1 dist=$HAS_USER2"
  ((FAILED++))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 4: No-clobber — user content preserved in relative order
# ---------------------------------------------------------------------------
echo "Test 4: No-clobber (user content preserved)"
SANDBOX=$(mktemp -d)
printf 'node_modules/\n# my comment\n\nsrc/\n' > "$SANDBOX/.gitignore"
run_helper --project-dir "$SANDBOX"
LINES_OK=true
for line in 'node_modules/' '# my comment' 'src/'; do
  grep -qF "$line" "$SANDBOX/.gitignore" || { LINES_OK=false; break; }
done
# Also check relative order: node_modules before src
NM_LINE=$(grep -n 'node_modules/' "$SANDBOX/.gitignore" | head -1 | cut -d: -f1)
SRC_LINE=$(grep -n '^src/' "$SANDBOX/.gitignore" | head -1 | cut -d: -f1)
ORDER_OK=false
if [[ -n "$NM_LINE" && -n "$SRC_LINE" && "$NM_LINE" -lt "$SRC_LINE" ]]; then
  ORDER_OK=true
fi
if [[ "$LINES_OK" == true && "$ORDER_OK" == true ]]; then
  echo "  ✓ All seeded lines present in original relative order"
else
  echo "  ✗ User content clobbered or order wrong (lines_ok=$LINES_OK order_ok=$ORDER_OK)"
  ((FAILED++))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 5: Opt-out — AGENT_FLOW_NO_GITIGNORE=1, no .gitignore created
# ---------------------------------------------------------------------------
echo "Test 5: Opt-out (AGENT_FLOW_NO_GITIGNORE=1)"
SANDBOX=$(mktemp -d)
AGENT_FLOW_NO_GITIGNORE=1 run_helper --project-dir "$SANDBOX"
if [[ ! -f "$SANDBOX/.gitignore" ]]; then
  echo "  ✓ .gitignore not created when opt-out env var is set"
else
  echo "  ✗ .gitignore was created despite AGENT_FLOW_NO_GITIGNORE=1"
  ((FAILED++))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 6: Repo-guard — agent-flow plugin.json present, no .gitignore created
# ---------------------------------------------------------------------------
echo "Test 6: Repo-guard (agent-flow plugin.json)"
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.claude-plugin"
printf '{"name":"agent-flow","version":"1.0.0"}\n' > "$SANDBOX/.claude-plugin/plugin.json"
run_helper --project-dir "$SANDBOX"
if [[ ! -f "$SANDBOX/.gitignore" ]]; then
  echo "  ✓ .gitignore not created inside agent-flow repo"
else
  echo "  ✗ .gitignore was created despite repo guard"
  ((FAILED++))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 7: No-trailing-newline — seed file without final newline
# ---------------------------------------------------------------------------
echo "Test 7: No-trailing-newline (seed file lacks final newline)"
SANDBOX=$(mktemp -d)
printf 'my-custom-dir/' > "$SANDBOX/.gitignore"
run_helper --project-dir "$SANDBOX"
HAS_CUSTOM=$(grep -cF 'my-custom-dir/' "$SANDBOX/.gitignore" || true)
HAS_START=$(grep -cF "$START_MARKER" "$SANDBOX/.gitignore" || true)
HAS_END=$(grep -cF "$END_MARKER" "$SANDBOX/.gitignore" || true)
# File must end with a newline
LAST_BYTE=$(tail -c 1 "$SANDBOX/.gitignore" | od -An -tx1 | tr -d ' \n')
ENDS_NEWLINE=false
[[ "$LAST_BYTE" == "0a" || "$LAST_BYTE" == "0d" ]] && ENDS_NEWLINE=true
if [[ "$HAS_CUSTOM" -ge 1 && "$HAS_START" -eq 1 && "$HAS_END" -eq 1 && "$ENDS_NEWLINE" == true ]]; then
  echo "  ✓ Seeded line intact, block appended with markers, file ends with newline"
else
  echo "  ✗ custom=$HAS_CUSTOM start=$HAS_START end=$HAS_END ends_newline=$ENDS_NEWLINE"
  ((FAILED++))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 8: CRLF idempotency — managed block plus user lines, all CRLF
# ---------------------------------------------------------------------------
echo "Test 8: CRLF idempotency (managed block + user lines in CRLF file)"
SANDBOX=$(mktemp -d)
# Build a CRLF .gitignore that already contains a managed block
{
  printf 'node_modules/\r\n'
  printf '# my crlf project\r\n'
  printf '%s\r\n' "$START_MARKER"
  printf '# Generated by agent-flow commands (orchestrate / deep-dive / explain / graphify).\r\n'
  printf '.claude/*.local.*\r\n'
  printf '%s\r\n' "$END_MARKER"
  printf 'dist/\r\n'
} > "$SANDBOX/.gitignore"

run_helper --project-dir "$SANDBOX"
cp "$SANDBOX/.gitignore" "$SANDBOX/.gitignore.run1"
run_helper --project-dir "$SANDBOX"

PASS=true
FAIL_REASON=""

# Exactly one START_MARKER after run 1
START_C=$(grep -cF "$START_MARKER" "$SANDBOX/.gitignore.run1" || true)
if [[ "$START_C" -ne 1 ]]; then
  PASS=false; FAIL_REASON="start_count after run1=$START_C (expected 1)"
fi

# File byte-identical between run 1 and run 2
if ! cmp -s "$SANDBOX/.gitignore.run1" "$SANDBOX/.gitignore"; then
  PASS=false; FAIL_REASON="${FAIL_REASON:+$FAIL_REASON; }file changed on run2 (not idempotent)"
fi

# Verify no bare LF in the file: every \n must be preceded by \r.
# Count total \n and total \r via od; they must be equal on a pure-CRLF file.
TOTAL_LF=$(od -c "$SANDBOX/.gitignore.run1" | grep -o '\\n' | wc -l | tr -d ' ')
TOTAL_CR=$(od -c "$SANDBOX/.gitignore.run1" | grep -o '\\r' | wc -l | tr -d ' ')
if [[ "$TOTAL_LF" -ne "$TOTAL_CR" || "$TOTAL_LF" -eq 0 ]]; then
  PASS=false; FAIL_REASON="${FAIL_REASON:+$FAIL_REASON; }bare-LF found in block (lf=$TOTAL_LF cr=$TOTAL_CR)"
fi

if [[ "$PASS" == true ]]; then
  echo "  ✓ Exactly one block, byte-identical on run2, markers are CRLF"
else
  echo "  ✗ $FAIL_REASON"
  ((FAILED++))
fi
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 9: Orphaned single END_MARKER — user lines preserved, fresh block appended
# ---------------------------------------------------------------------------
echo "Test 9: Orphaned END_MARKER only (no START_MARKER)"
SANDBOX=$(mktemp -d)
printf 'node_modules/\n%s\ndist/\n' "$END_MARKER" > "$SANDBOX/.gitignore"

run_helper --project-dir "$SANDBOX"
cp "$SANDBOX/.gitignore" "$SANDBOX/.gitignore.run1"
run_helper --project-dir "$SANDBOX"

PASS=true
FAIL_REASON=""

# User lines preserved
for uline in 'node_modules/' 'dist/'; do
  grep -qF "$uline" "$SANDBOX/.gitignore" || { PASS=false; FAIL_REASON="${FAIL_REASON:+$FAIL_REASON; }missing user line $uline"; }
done

# Exactly one START_MARKER (fresh block was appended)
START_C=$(grep -cF "$START_MARKER" "$SANDBOX/.gitignore" || true)
if [[ "$START_C" -ne 1 ]]; then
  PASS=false; FAIL_REASON="${FAIL_REASON:+$FAIL_REASON; }start_count=$START_C (expected 1)"
fi

# Byte-identical on second run (idempotent)
if ! cmp -s "$SANDBOX/.gitignore.run1" "$SANDBOX/.gitignore"; then
  PASS=false; FAIL_REASON="${FAIL_REASON:+$FAIL_REASON; }file changed on run2 (not idempotent)"
fi

if [[ "$PASS" == true ]]; then
  echo "  ✓ User lines preserved, fresh block appended, idempotent on run2"
else
  echo "  ✗ $FAIL_REASON"
  ((FAILED++))
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
