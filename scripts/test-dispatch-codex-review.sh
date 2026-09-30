#!/bin/bash
# test-dispatch-codex-review.sh — plain-bash tests for dispatch-codex-review.sh
# Style: test-ensure-gitignore.sh (FAILED counter, ✓/✗ echo, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/dispatch-codex-review.sh"
SNAPSHOT="$SCRIPT_DIR/snapshot-untracked.sh"

FAILED=0

# Build a git sandbox the dispatcher can run in (it needs origin/HEAD under set -e)
setup_sandbox() {
  local sb="$1"
  git init -q -b main "$sb"
  git -C "$sb" -c user.email=t@t -c user.name=t commit --allow-empty -m init -q
  git -C "$sb" update-ref refs/remotes/origin/main refs/heads/main
  git -C "$sb" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  mkdir -p "$sb/stubbin"
  printf 'started_at: "2026-09-30T00:00:00Z"\ntask: test task\ncodex:\n  available: true\n' > "$sb/state.md"
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
# Test 5: Parallel mode — no --lawliet-findings; prompt says Lawliet runs in parallel
# ---------------------------------------------------------------------------
echo "Test 5: Parallel mode without --lawliet-findings"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift 2; else shift; fi
done
cat > "$(dirname "$0")/prompt.txt"
printf 'APPROVED\n' > "$out"
EOF
chmod +x "$SANDBOX/stubbin/codex"
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" bash "$DISPATCH" --state-file state.md 2>/dev/null || true)
if echo "$OUTPUT" | grep -q '^codex_verdict: APPROVED$' \
  && grep -q 'reviewing in parallel' "$SANDBOX/stubbin/prompt.txt" \
  && grep -q '^## Output contract' "$SANDBOX/stubbin/prompt.txt"; then
  echo "  ✓ runs without findings file, inlines the plugin rubric, tells Codex Lawliet is parallel"
else
  echo "  ✗ unexpected output: $OUTPUT"
  FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 6: Size guards — artifacts/oversized untracked files skipped; huge diff → --stat
# ---------------------------------------------------------------------------
echo "Test 6: Untracked artifact skip and diff-size cap"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift 2; else shift; fi
done
cat > "$(dirname "$0")/prompt.txt"
printf 'APPROVED\n' > "$out"
EOF
chmod +x "$SANDBOX/stubbin/codex"
(
  cd "$SANDBOX" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  mkdir -p .playwright-mcp && printf 'SNAPSHOT_MARKER\n' > .playwright-mcp/snap.yml
  printf 'small change\n' > keep.txt
  head -c 200000 /dev/zero | tr '\0' 'a' > big.txt
)
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" bash "$DISPATCH" --state-file state.md 2>/dev/null || true)
P="$SANDBOX/stubbin/prompt.txt"
if grep -q 'small change' "$P" && ! grep -q 'SNAPSHOT_MARKER' "$P" \
  && grep -q '.playwright-mcp/snap.yml (artifact path)' "$P" && grep -q 'big.txt (200000 bytes)' "$P"; then
  echo "  ✓ artifact and oversized untracked files listed as omitted, small file included"
else
  echo "  ✗ untracked guard failed"; FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" AGENT_FLOW_CODEX_MAX_DIFF_CHARS=10 bash "$DISPATCH" --state-file state.md 2>/dev/null || true)
if grep -q 'Full diff omitted' "$P" && ! grep -q 'small change' "$P"; then
  echo "  ✓ diff over the cap replaced by --stat"
else
  echo "  ✗ diff cap not applied"; FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 7: pre-existing untracked files are skipped
# ---------------------------------------------------------------------------
echo "Test 7: pre-existing untracked files are skipped"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift 2; else shift; fi
done
cat > "$(dirname "$0")/prompt.txt"
printf 'APPROVED\n' > "$out"
EOF
chmod +x "$SANDBOX/stubbin/codex"
STDERR_FILE=$(mktemp)
(
  cd "$SANDBOX" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf 'OLD_MARKER\n' > old-notes.md
  bash "$SNAPSHOT" --state-file state.md >/dev/null
  # No mtime manipulation here: old-notes.md predates the baseline write, so it
  # is never newer than it — unlike Test 8, which deliberately re-touches a
  # baseline member after backdating the baseline to force the "-nt" refinement.
  printf 'NEW_MARKER\n' > new.py
)
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" bash "$DISPATCH" --state-file state.md 2>"$STDERR_FILE" || true)
P="$SANDBOX/stubbin/prompt.txt"
if grep -q 'NEW_MARKER' "$P" && ! grep -q 'OLD_MARKER' "$P" \
  && grep -q 'existed before this run' "$P" \
  && ! grep -q 'old-notes.md' "$P" \
  && echo "$OUTPUT" | grep -qE '^codex_untracked: inlined=.* preexisting=[1-9][0-9]* .*baseline=used$'; then
  echo "  ✓ pre-existing file excluded, new file inlined, counted in codex_untracked"
else
  echo "  ✗ unexpected output: $OUTPUT"; FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
rm -f "$STDERR_FILE"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 8: a file modified after the snapshot is re-included; odd paths survive
# ---------------------------------------------------------------------------
echo "Test 8: pre-existing file edited after snapshot is re-included"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift 2; else shift; fi
done
cat > "$(dirname "$0")/prompt.txt"
printf 'APPROVED\n' > "$out"
EOF
chmod +x "$SANDBOX/stubbin/codex"
(
  cd "$SANDBOX" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  mkdir -p "a b"
  printf 'BEFORE\n' > "a b/ünï.md"
  bash "$SNAPSHOT" --state-file state.md >/dev/null
  touch -t 202001010000 .claude/review-baseline-untracked.local.txt
  printf 'EDITED_MARKER\n' >> "a b/ünï.md"
)
BASELINE_COUNT=$(cd "$SANDBOX" && bash "$SNAPSHOT" --state-file state.md | grep '^baseline_count: ' | sed 's/^baseline_count: //')
BASELINE_STATUS_LINE=$(cd "$SANDBOX" && bash "$SNAPSHOT" --state-file state.md | grep '^baseline_status: ')
cp "$SANDBOX/.claude/review-baseline-untracked.local.txt" /tmp/agent-flow-test8-before.bin 2>/dev/null || true
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" bash "$DISPATCH" --state-file state.md 2>/dev/null || true)
P="$SANDBOX/stubbin/prompt.txt"
if grep -q 'EDITED_MARKER' "$P" \
  && [[ "$BASELINE_COUNT" -ge 1 ]] \
  && [[ "$BASELINE_STATUS_LINE" == "baseline_status: kept" ]] \
  && cmp -s /tmp/agent-flow-test8-before.bin "$SANDBOX/.claude/review-baseline-untracked.local.txt"; then
  echo "  ✓ file edited after snapshot is re-inlined; repeat snapshot runs are idempotent"
else
  echo "  ✗ unexpected output: $OUTPUT (count=$BASELINE_COUNT, status=$BASELINE_STATUS_LINE)"; FAILED=$((FAILED+1))
fi
rm -f /tmp/agent-flow-test8-before.bin
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 9: no baseline, or a stale baseline, falls back to today's behavior
# ---------------------------------------------------------------------------
echo "Test 9: no baseline / stale baseline falls back to inlining"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift 2; else shift; fi
done
cat > "$(dirname "$0")/prompt.txt"
printf 'APPROVED\n' > "$out"
EOF
chmod +x "$SANDBOX/stubbin/codex"
(
  cd "$SANDBOX" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf 'OLD_MARKER\n' > old-notes.md
)
STDERR_FILE=$(mktemp)
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" bash "$DISPATCH" --state-file state.md 2>"$STDERR_FILE" || true)
P="$SANDBOX/stubbin/prompt.txt"
if grep -q 'OLD_MARKER' "$P" \
  && grep -q 'baseline missing' "$STDERR_FILE" \
  && echo "$OUTPUT" | grep -q 'baseline=missing$'; then
  echo "  ✓ no baseline: inlines, warns, reports baseline=missing"
else
  echo "  ✗ missing-baseline case failed: $OUTPUT"; FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"

OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" AGENT_FLOW_CODEX_INLINE_UNTRACKED=0 bash "$DISPATCH" --state-file state.md 2>/dev/null || true)
if ! grep -q 'OLD_MARKER' "$P" && echo "$OUTPUT" | grep -q 'preexisting=[1-9][0-9]*.*baseline=missing$'; then
  echo "  ✓ AGENT_FLOW_CODEX_INLINE_UNTRACKED=0 disables inlining entirely in the fallback path"
else
  echo "  ✗ inline-untracked kill switch failed: $OUTPUT"; FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"

(cd "$SANDBOX" && bash "$SNAPSHOT" --state-file state.md >/dev/null)
printf 'started_at: "2099-01-01T00:00:00Z"\ntask: test task\ncodex:\n  available: true\n' > "$SANDBOX/state.md"
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" bash "$DISPATCH" --state-file state.md 2>/dev/null || true)
if grep -q 'OLD_MARKER' "$P" && echo "$OUTPUT" | grep -q 'baseline=stale$'; then
  echo "  ✓ stale baseline (started_at mismatch): inlines, reports baseline=stale"
else
  echo "  ✗ stale-baseline case failed: $OUTPUT"; FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"

# snapshot-untracked.sh edge cases: never blocks the caller
NOSTATE_OUT=$(cd "$SANDBOX" && bash "$SNAPSHOT" --state-file does-not-exist.md 2>/dev/null)
NOSTARTED=$(mktemp -d)
printf 'task: no started_at\n' > "$NOSTARTED/state.md"
NOSTARTED_OUT=$(cd "$NOSTARTED" && bash "$SNAPSHOT" --state-file state.md 2>/dev/null)
NONGIT=$(mktemp -d)
printf 'started_at: "x"\n' > "$NONGIT/state.md"
NONGIT_OUT=$(cd "$NONGIT" && bash "$SNAPSHOT" --state-file state.md 2>/dev/null)
if [[ "$NOSTATE_OUT" == "baseline_status: skipped" ]] \
  && [[ "$NOSTARTED_OUT" == "baseline_status: skipped" ]] \
  && [[ "$NONGIT_OUT" == "baseline_status: skipped" ]] \
  && [[ ! -e "$NOSTARTED/.claude/review-baseline-untracked.local.txt" ]] \
  && [[ ! -e "$NONGIT/.claude/review-baseline-untracked.local.txt" ]]; then
  echo "  ✓ snapshot-untracked.sh exits 0 and writes nothing for missing state/started_at/non-git cwd"
else
  echo "  ✗ snapshot-untracked.sh edge case failed"; FAILED=$((FAILED+1))
fi
rm -rf "$NOSTARTED" "$NONGIT"
rm -f "$STDERR_FILE"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 10: extended artifact exclusions
# ---------------------------------------------------------------------------
echo "Test 10: extended artifact exclusions"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift 2; else shift; fi
done
cat > "$(dirname "$0")/prompt.txt"
printf 'APPROVED\n' > "$out"
EOF
chmod +x "$SANDBOX/stubbin/codex"
(
  cd "$SANDBOX" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  mkdir -p tmp sub/tmp .senku docs/_build src
  printf 'TMP1\n' > tmp/draft.md
  printf 'TMP2\n' > sub/tmp/x.md
  printf 'AIDER1\n' > .aider.chat.history.md
  printf 'COMPLEXIPY1\n' > complexipy-results.json
  printf 'PATCH1\n' > fix.patch
  printf 'LOG1\n' > run.log
  printf 'SENKU1\n' > .senku/plan.md
  printf 'BUILD1\n' > docs/_build/index.html
  printf 'src change\n' > src/keep.py
)
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" bash "$DISPATCH" --state-file state.md 2>/dev/null || true)
P="$SANDBOX/stubbin/prompt.txt"
if ! grep -qE 'TMP1|TMP2|AIDER1|COMPLEXIPY1|PATCH1|LOG1|SENKU1|BUILD1' "$P" \
  && grep -q 'tmp/draft.md (artifact path)' "$P" \
  && grep -q 'sub/tmp/x.md (artifact path)' "$P" \
  && grep -q '.aider.chat.history.md (artifact path)' "$P" \
  && grep -q 'complexipy-results.json (artifact path)' "$P" \
  && grep -q 'fix.patch (artifact path)' "$P" \
  && grep -q 'run.log (artifact path)' "$P" \
  && grep -q '.senku/plan.md (artifact path)' "$P" \
  && grep -q 'docs/_build/index.html (artifact path)' "$P" \
  && grep -q 'src change' "$P" \
  && echo "$OUTPUT" | grep -q 'artifact=8'; then
  echo "  ✓ extended artifact exclusions applied, src/keep.py inlined"
else
  echo "  ✗ extended artifact exclusion failed: $OUTPUT"; FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 11: secret-name guard
# ---------------------------------------------------------------------------
echo "Test 11: secret-name guard"
SANDBOX=$(mktemp -d)
setup_sandbox "$SANDBOX"
cat > "$SANDBOX/stubbin/codex" << 'EOF'
#!/bin/bash
out=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then out="$2"; shift 2; else shift; fi
done
cat > "$(dirname "$0")/prompt.txt"
printf 'APPROVED\n' > "$out"
EOF
chmod +x "$SANDBOX/stubbin/codex"
(
  cd "$SANDBOX" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf 'SECRET_MARKER\n' > .env.local
  printf 'SECRET_MARKER\n' > prod.env
  printf 'SECRET_MARKER\n' > deploy.pem
  printf 'export const envelope = 1\n' > envelope.ts
)
OUTPUT=$(cd "$SANDBOX" && PATH="$SANDBOX/stubbin:$PATH" bash "$DISPATCH" --state-file state.md 2>/dev/null || true)
P="$SANDBOX/stubbin/prompt.txt"
if ! grep -q 'SECRET_MARKER' "$P" \
  && grep -q '.env.local (secret-like name)' "$P" \
  && grep -q 'prod.env (secret-like name)' "$P" \
  && grep -q 'deploy.pem (secret-like name)' "$P" \
  && grep -q 'envelope' "$P" \
  && echo "$OUTPUT" | grep -q 'secret=3'; then
  echo "  ✓ secret-like files never inlined, envelope.ts unaffected"
else
  echo "  ✗ secret-name guard failed: $OUTPUT"; FAILED=$((FAILED+1))
fi
RAW_PATH=$(echo "$OUTPUT" | grep '^codex_raw_path: ' | sed 's/^codex_raw_path: //' || true)
[[ -n "$RAW_PATH" ]] && rm -f "$RAW_PATH"
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
