#!/bin/bash
# test-research-report.sh — plain-bash tests for init-research-report.sh and compile-research-report.sh
# Style: test-ensure-gitignore.sh (FAILED counter, ✓/✗ echo, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="$SCRIPT_DIR/init-research-report.sh"
COMPILE_SCRIPT="$SCRIPT_DIR/compile-research-report.sh"

FAILED=0

run_init() {
  bash "$INIT_SCRIPT" "$@"
}

run_compile() {
  bash "$COMPILE_SCRIPT" "$@"
}

# ---------------------------------------------------------------------------
# Test 1: init creates file with expected frontmatter keys
# ---------------------------------------------------------------------------
echo "Test 1: init creates file with expected frontmatter keys"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX" && REPORT=$(run_init --goal "investigate auth token expiry")
  if [[ -z "$REPORT" ]]; then
    echo "  ✗ No REPORT_PATH echoed"
    exit 1
  fi
  if [[ ! -f "$REPORT" ]]; then
    echo "  ✗ Report file not created at: $REPORT"
    exit 1
  fi
  PASS=true
  for key in 'generated:' 'goal:' 'scope:' 'report_path:' 'status:' 'exploration:' 'synthesis:'; do
    grep -q "$key" "$REPORT" || { echo "  ✗ Missing frontmatter key: $key"; PASS=false; }
  done
  if grep -q 'status: "initializing"' "$REPORT" && [[ "$PASS" == true ]]; then
    echo "  ✓ Report created with all expected frontmatter keys and status=initializing"
  else
    [[ "$PASS" == true ]] && echo "  ✗ status is not initializing"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 2: slug sanitization handles spaces/special chars and empty-slug fallback
# ---------------------------------------------------------------------------
echo "Test 2: slug sanitization"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  # Goal with spaces and special chars → slug should be alphanumeric+dash only
  REPORT=$(run_init --goal "Investigate: Why X?! Fails (always)")
  BASENAME=$(basename "$REPORT")
  # slug portion is between "research-" and the timestamp "-20..."
  SLUG_PART=$(echo "$BASENAME" | sed 's/^research-//' | sed 's/-[0-9]\{8\}T[0-9]\{6\}Z\.local\.md$//')
  if [[ "$SLUG_PART" =~ ^[a-z0-9-]+$ ]]; then
    echo "  ✓ Slug '$SLUG_PART' is lowercase alphanumeric+dash"
  else
    echo "  ✗ Slug '$SLUG_PART' contains invalid characters"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"

SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  # Empty slug fallback: goal is all special chars
  REPORT=$(run_init --goal "!!! ???")
  BASENAME=$(basename "$REPORT")
  if echo "$BASENAME" | grep -q '^research-report-'; then
    echo "  ✓ Empty-slug fallback produces 'report' slug"
  else
    echo "  ✗ Fallback slug not 'report', got: $BASENAME"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 3: compile rewrites sections and preserves goal
# ---------------------------------------------------------------------------
echo "Test 3: compile rewrites sections and preserves goal"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  REPORT=$(run_init --goal "research cache options")
  run_compile --report-path "$REPORT" \
    --summary "Cache options reviewed" \
    --findings "Redis is fastest" \
    --plan "Adopt Redis" >/dev/null

  GOAL_LINE=$(grep '^goal:' "$REPORT")
  SUMMARY_LINE=$(grep "Cache options reviewed" "$REPORT" || true)
  FINDINGS_LINE=$(grep "Redis is fastest" "$REPORT" || true)
  PLAN_LINE=$(grep "Adopt Redis" "$REPORT" || true)

  if [[ -n "$GOAL_LINE" && -n "$SUMMARY_LINE" && -n "$FINDINGS_LINE" && -n "$PLAN_LINE" ]]; then
    echo "  ✓ compile rewrote sections and preserved goal in frontmatter"
  else
    echo "  ✗ goal=$GOAL_LINE summary=${SUMMARY_LINE:-missing} findings=${FINDINGS_LINE:-missing} plan=${PLAN_LINE:-missing}"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 4: --mark-complete with all sections filled → status: complete
# ---------------------------------------------------------------------------
echo "Test 4: --mark-complete with all sections filled"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  REPORT=$(run_init --goal "investigate db latency")
  run_compile --report-path "$REPORT" \
    --summary "DB latency caused by missing index" \
    --findings "Query plans show full table scan on users table" \
    --plan "Add index on users.email" \
    --open-questions "None" \
    --sources "EXPLAIN ANALYZE output" \
    --mark-complete >/dev/null

  STATUS=$(grep '^status:' "$REPORT" | sed 's/status: *//' | tr -d '"')
  if [[ "$STATUS" == "complete" ]]; then
    echo "  ✓ status=complete after --mark-complete with all sections"
  else
    echo "  ✗ status='$STATUS' (expected complete)"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 5: --mark-complete with empty Findings → exit 1
# ---------------------------------------------------------------------------
echo "Test 5: --mark-complete with empty Findings should fail"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  REPORT=$(run_init --goal "investigate slow startup")
  # Only provide Summary, leave Findings as stub
  EXIT_CODE=0
  run_compile --report-path "$REPORT" \
    --summary "Slow startup analyzed" \
    --mark-complete >/dev/null 2>&1 || EXIT_CODE=$?
  if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo "  ✓ compile --mark-complete exited non-zero when Findings empty"
  else
    echo "  ✗ compile --mark-complete should have failed but exited 0"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 6: compile on missing file → exit 1
# ---------------------------------------------------------------------------
echo "Test 6: compile on missing file exits non-zero"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  EXIT_CODE=0
  run_compile --report-path ".claude/nonexistent-report.local.md" \
    --summary "test" >/dev/null 2>&1 || EXIT_CODE=$?
  if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo "  ✓ compile exited non-zero for missing report file"
  else
    echo "  ✗ compile should have failed but exited 0 for missing file"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 7: exploratory scope — Plan empty on --mark-complete renders N/A (not error)
# ---------------------------------------------------------------------------
echo "Test 7: exploratory scope — empty Plan renders as N/A on --mark-complete"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  REPORT=$(run_init --goal "explore microservice patterns" --scope exploratory)
  EXIT_CODE=0
  run_compile --report-path "$REPORT" \
    --summary "Microservice patterns surveyed" \
    --findings "Event sourcing is most common" \
    --mark-complete >/dev/null 2>&1 || EXIT_CODE=$?
  if [[ "$EXIT_CODE" -eq 0 ]]; then
    PLAN_CONTENT=$(grep "N/A" "$REPORT" || true)
    STATUS=$(grep '^status:' "$REPORT" | sed 's/status: *//' | tr -d '"')
    if [[ -n "$PLAN_CONTENT" && "$STATUS" == "complete" ]]; then
      echo "  ✓ exploratory scope: empty Plan rendered as N/A and status=complete"
    else
      echo "  ✗ Expected N/A plan and status=complete, got: plan_na=${PLAN_CONTENT:-missing} status=$STATUS"
      exit 1
    fi
  else
    echo "  ✗ compile --mark-complete should succeed for exploratory with empty Plan (exit=$EXIT_CODE)"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 8: multi-line --goal produces a single-line "Goal:" body line
# ---------------------------------------------------------------------------
echo "Test 8: multi-line --goal produces single-line Goal body"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  MULTI_GOAL=$'first line\nsecond line\nthird line'
  REPORT=$(run_init --goal "$MULTI_GOAL")
  # The "> Goal:" line must appear exactly once (no multi-line expansion in body)
  GOAL_LINES=$(grep -c '^> Goal:' "$REPORT")
  # And each of the raw newline-separated parts must NOT appear as separate lines
  # (i.e. "second line" should not start a line after the "> Goal:" line)
  LEAKING=$(awk '/^> Goal:/{found=1; next} found && /^second line/{print; exit}' "$REPORT" || true)
  if [[ "$GOAL_LINES" -eq 1 && -z "$LEAKING" ]]; then
    GOAL_LINE=$(grep '^> Goal:' "$REPORT")
    echo "  ✓ Goal body line is single-line: $GOAL_LINE"
  else
    echo "  ✗ Goal body line is not single-line (goal_lines=$GOAL_LINES leaking=${LEAKING:-none})"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 9: content containing "_pending" substring (not the stub) passes --mark-complete
# ---------------------------------------------------------------------------
echo "Test 9: content containing '_pending' substring passes completeness gate"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  REPORT=$(run_init --goal "research pending queue behavior")
  EXIT_CODE=0
  run_compile --report-path "$REPORT" \
    --summary "The _pending queue was analyzed thoroughly" \
    --findings "Items in _pending state are processed after retry" \
    --plan "Update retry logic to clear _pending flags" \
    --mark-complete >/dev/null 2>&1 || EXIT_CODE=$?
  if [[ "$EXIT_CODE" -eq 0 ]]; then
    STATUS=$(grep '^status:' "$REPORT" | sed 's/status: *//' | tr -d '"')
    if [[ "$STATUS" == "complete" ]]; then
      echo "  ✓ Content containing '_pending' substring passed gate, status=complete"
    else
      echo "  ✗ Expected status=complete, got: $STATUS"
      exit 1
    fi
  else
    echo "  ✗ compile --mark-complete should have succeeded but exited $EXIT_CODE"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 10: --report-path outside .claude/ exits 1
# ---------------------------------------------------------------------------
echo "Test 10: --report-path outside .claude/ exits non-zero"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  # Create a real file outside .claude/ so the path-guard is what fails, not the exists check
  OUTSIDE_FILE="$SANDBOX/outside-report.local.md"
  touch "$OUTSIDE_FILE"
  EXIT_CODE=0
  run_compile --report-path "$OUTSIDE_FILE" \
    --summary "test" >/dev/null 2>&1 || EXIT_CODE=$?
  if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo "  ✓ compile exited non-zero for --report-path outside .claude/"
  else
    echo "  ✗ compile should have failed for path outside .claude/ but exited 0"
    exit 1
  fi

  # Also test traversal path
  EXIT_CODE2=0
  run_compile --report-path "../../etc/passwd" \
    --summary "test" >/dev/null 2>&1 || EXIT_CODE2=$?
  if [[ "$EXIT_CODE2" -ne 0 ]]; then
    echo "  ✓ compile exited non-zero for traversal path ../../etc/passwd"
  else
    echo "  ✗ compile should have failed for traversal path but exited 0"
    exit 1
  fi

  # Test .claude/../outside.txt — passes the prefix check but must be blocked by the .. check
  SENTINEL_CONTENT="sentinel-original"
  SENTINEL_FILE="$SANDBOX/outside.txt"
  echo "$SENTINEL_CONTENT" >"$SENTINEL_FILE"
  mkdir -p "$SANDBOX/.claude"
  EXIT_CODE3=0
  run_compile --report-path ".claude/../outside.txt" \
    --summary "test" >/dev/null 2>&1 || EXIT_CODE3=$?
  if [[ "$EXIT_CODE3" -ne 0 ]]; then
    echo "  ✓ compile exited non-zero for .claude/../outside.txt traversal"
  else
    echo "  ✗ compile should have failed for .claude/../outside.txt but exited 0"
    exit 1
  fi
  if [[ "$(cat "$SENTINEL_FILE")" == "$SENTINEL_CONTENT" ]]; then
    echo "  ✓ sentinel file outside .claude/ was not modified"
  else
    echo "  ✗ sentinel file was overwritten — path traversal guard did not fire"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 11: generated filename uses second-resolution stamp (YYYYMMDDTHHMMSSz)
# ---------------------------------------------------------------------------
echo "Test 11: generated filename uses second-resolution stamp"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  REPORT=$(run_init --goal "test second resolution stamp")
  BASENAME=$(basename "$REPORT")
  # Stamp must be exactly 15 chars: YYYYMMDDTHHMMSSZ
  if echo "$BASENAME" | grep -qE 'research-[a-z0-9-]+-[0-9]{8}T[0-9]{6}Z(-[0-9]+)?\.local\.md$'; then
    echo "  ✓ Filename matches second-resolution stamp pattern YYYYMMDDTHHMMSSz"
  else
    echo "  ✗ Filename '$BASENAME' does not match expected second-resolution pattern"
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 12: collision guard — pre-create the file init would choose so it must
#          fall back to a suffixed path; verify original is unchanged.
# ---------------------------------------------------------------------------
echo "Test 12: collision guard produces distinct files"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  GOAL="collision test goal"

  # Compute the slug the way init-research-report.sh does it
  SLUG_PART=$(echo "$GOAL" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40 | sed 's/-*$//')

  # Pre-create the "next" stamp file so init is forced to use a suffix.
  # We fabricate a fixed stamp so the collision is deterministic.
  FAKE_STAMP="20260101T120000Z"
  mkdir -p .claude
  PREEXISTING_PATH=".claude/research-${SLUG_PART}-${FAKE_STAMP}.local.md"
  echo "pre-existing-sentinel" > "$PREEXISTING_PATH"
  ORIGINAL_CONTENT=$(cat "$PREEXISTING_PATH")

  # Monkey-patch: temporarily override `date` so init picks our fake stamp.
  # We do this by injecting a wrapper on PATH.
  FAKE_BIN_DIR=$(mktemp -d)
  cat > "$FAKE_BIN_DIR/date" << 'DATEEOF'
#!/bin/bash
if [[ "$*" == *"+%Y%m%dT%H%M%SZ"* ]]; then
  echo "20260101T120000Z"
else
  /bin/date "$@"
fi
DATEEOF
  chmod +x "$FAKE_BIN_DIR/date"

  REPORT2=$(PATH="$FAKE_BIN_DIR:$PATH" run_init --goal "$GOAL")
  rm -rf "$FAKE_BIN_DIR"

  # REPORT2 must differ from the pre-existing path
  if [[ "$REPORT2" == "$PREEXISTING_PATH" ]]; then
    echo "  ✗ init returned the pre-existing (colliding) path: $REPORT2"
    exit 1
  fi
  if [[ ! -f "$REPORT2" ]]; then
    echo "  ✗ Suffixed report not created: $REPORT2"
    exit 1
  fi
  # Pre-existing file must be unchanged
  CONTENT_AFTER=$(cat "$PREEXISTING_PATH")
  if [[ "$ORIGINAL_CONTENT" == "$CONTENT_AFTER" ]]; then
    echo "  ✓ Collision guard: init created '$REPORT2' without touching pre-existing '$PREEXISTING_PATH'"
  else
    echo "  ✗ Pre-existing file was modified — collision guard failed"
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
