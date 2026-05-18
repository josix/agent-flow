#!/bin/bash
# Shared Codex co-review dispatcher for agent-flow Phase 4.
# Called by both /orchestrate and /team-orchestrate after Lawliet completes.
#
# Usage:
#   bash dispatch-codex-review.sh \
#     --state-file <path-to-state-file> \
#     --lawliet-findings <path-to-findings-file>
#
# Output (stdout, YAML-like key: value lines):
#   codex_ran: true|false
#   codex_exit: <number>            (only when codex_ran: true)
#   codex_verdict: <string>         (only when codex_ran: true)
#   codex_raw_path: <tmpfile-path>  (only when codex_ran: true and codex exit 0)
#   codex_skip_reason: <string>     (only when codex_ran: false)
#
# The caller is responsible for rm -f "$codex_raw_path" after reading it.

set -euo pipefail

STATE_FILE=""
LAWLIET_FINDINGS=""

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file)
      STATE_FILE="$2"
      shift 2
      ;;
    --lawliet-findings)
      LAWLIET_FINDINGS="$2"
      shift 2
      ;;
    *)
      echo "warn: unknown flag: $1" >&2
      shift
      ;;
  esac
done

# Validate required flags
if [[ -z "$STATE_FILE" ]]; then
  echo "error: --state-file is required" >&2
  exit 1
fi
if [[ -z "$LAWLIET_FINDINGS" ]]; then
  echo "error: --lawliet-findings is required" >&2
  exit 1
fi
if [[ ! -f "$STATE_FILE" ]]; then
  echo "error: state file not found: $STATE_FILE" >&2
  exit 1
fi

# Read codex.available from state file
CODEX_AVAILABLE=$(grep -A1 '^codex:' "$STATE_FILE" | grep 'available:' | sed 's/.*available: *//')

if [[ "$CODEX_AVAILABLE" != "true" ]]; then
  echo "codex_ran: false"
  echo "codex_skip_reason: unavailable"
  exit 0
fi

# Read task description from state file
TASK_DESC=$(grep '^task:' "$STATE_FILE" | sed 's/^task: *//')

# Build GIT_DIFF (merge-base..HEAD + working tree + untracked)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/||')
DEFAULT_BRANCH=${DEFAULT_BRANCH:-origin/main}
MERGE_BASE=$(git merge-base HEAD "$DEFAULT_BRANCH" 2>/dev/null || echo "$DEFAULT_BRANCH")
UNTRACKED=$(git ls-files --others --exclude-standard)
UNTRACKED_DIFF=""
if [ -n "$UNTRACKED" ]; then
  while IFS= read -r f; do
    UNTRACKED_DIFF+=$'\n'"$(git diff --no-index -- /dev/null "$f" 2>/dev/null || true)"
  done <<< "$UNTRACKED"
fi
GIT_DIFF=$(printf '%s\n%s\n%s' "$(git diff "$MERGE_BASE"..HEAD 2>/dev/null || true)" "$(git diff HEAD 2>/dev/null || true)" "$UNTRACKED_DIFF")

# Read Lawliet findings
LAWLIET_FINDINGS_CONTENT=""
if [[ -s "$LAWLIET_FINDINGS" ]]; then
  LAWLIET_FINDINGS_CONTENT=$(cat "$LAWLIET_FINDINGS")
else
  echo "warn: Lawliet findings empty or missing — Codex receiving empty section" >&2
fi

# Create output temp file (caller must rm -f it after reading)
CODEX_OUT=$(mktemp)

# Build prompt body
BODY=$(printf '%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s' \
  "You are the Phase 4 co-reviewer. Follow the rubric in AGENTS.md at the repo root." \
  "## Task description" \
  "$TASK_DESC" \
  "## Lawliet's review (already completed — do not duplicate)" \
  "$LAWLIET_FINDINGS_CONTENT" \
  "## Diff under review" \
  "$GIT_DIFF")

# Run codex with timeout fallback
CODEX_EXIT=0
if command -v timeout >/dev/null 2>&1; then
  set +e
  printf '%s' "$BODY" | timeout 120 codex exec \
    -s read-only --ignore-user-config \
    -c model_reasoning_effort="high" \
    --output-last-message "$CODEX_OUT" - 2>&1 | tail -5 >&2
  CODEX_EXIT=${PIPESTATUS[1]}
  set -e
elif command -v gtimeout >/dev/null 2>&1; then
  set +e
  printf '%s' "$BODY" | gtimeout 120 codex exec \
    -s read-only --ignore-user-config \
    -c model_reasoning_effort="high" \
    --output-last-message "$CODEX_OUT" - 2>&1 | tail -5 >&2
  CODEX_EXIT=${PIPESTATUS[1]}
  set -e
else
  echo "warn: no timeout/gtimeout binary found — Codex dispatch will not be time-bounded (install coreutils on macOS: brew install coreutils)" >&2
  set +e
  printf '%s' "$BODY" | codex exec \
    -s read-only --ignore-user-config \
    -c model_reasoning_effort="high" \
    --output-last-message "$CODEX_OUT" - 2>&1 | tail -5 >&2
  CODEX_EXIT=${PIPESTATUS[1]}
  set -e
fi

if [[ "$CODEX_EXIT" -ne 0 ]]; then
  echo "warn: codex exec failed with exit $CODEX_EXIT — treating as advisory (Phase 4 degrades to Lawliet-only)" >&2
  echo "codex_ran: true"
  echo "codex_exit: $CODEX_EXIT"
  echo "codex_verdict: ADVISORY"
  echo "codex_raw_path: $CODEX_OUT"
  exit 0
fi

# Parse first non-blank line of output as verdict
FIRST_LINE=$(awk 'NF{print; exit}' "$CODEX_OUT")

case "$FIRST_LINE" in
  APPROVED|NEEDS_CHANGES|BLOCKED)
    CODEX_VERDICT="$FIRST_LINE"
    ;;
  *)
    echo "warn: Codex verdict unparseable — treating as advisory" >&2
    CODEX_VERDICT="UNPARSEABLE"
    ;;
esac

echo "codex_ran: true"
echo "codex_exit: 0"
echo "codex_verdict: $CODEX_VERDICT"
echo "codex_raw_path: $CODEX_OUT"
exit 0
