#!/bin/bash
# snapshot-untracked.sh — record the set of untracked files that exist before
# an orchestrate run starts, so dispatch-codex-review.sh can tell "pre-existing
# clutter" (aider caches, doc-site exports, other tickets' tmp/ drafts, ...)
# apart from files this run actually created or modified.
#
# Usage:
#   bash snapshot-untracked.sh --state-file <path-to-state-file> [--force]
#
# Behavior:
#   - Reads `started_at` from the state file's YAML frontmatter and uses it to
#     tie the baseline to this orchestration run (see dispatch-codex-review.sh
#     for how staleness is judged from this same value).
#   - Writes .claude/review-baseline-untracked.local.txt (NUL-separated
#     records: a header record `agent-flow-untracked-baseline v1
#     started_at=<started_at>`, then one record per untracked path from
#     `git ls-files -z --others --exclude-standard`).
#   - Idempotent: if a baseline already exists with the same started_at header,
#     it is left untouched (mtime included) unless --force is passed. This
#     matters for relaunches after an escalation (start_round > 0), which must
#     not re-capture a partially-implemented tree as "pre-existing".
#   - Never blocks the caller: a missing state file, a missing started_at, or
#     a cwd outside a git work tree all print a warning and exit 0 without
#     writing a file (`baseline_status: skipped`). dispatch-codex-review.sh's
#     fallback path handles a missing baseline.
#
# Output (stdout, key: value lines):
#   baseline_status: written|kept|skipped
#   baseline_path: .claude/review-baseline-untracked.local.txt   (written|kept only)
#   baseline_count: <n>                                          (written|kept only)
#
# The baseline file lives under .claude/ and matches the `.claude/*.local.*`
# pattern in the agent-flow managed .gitignore block (scripts/ensure-gitignore.sh),
# so it is never committed.

set -euo pipefail

STATE_FILE=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file)
      STATE_FILE="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    *)
      echo "warn: unknown flag: $1" >&2
      shift
      ;;
  esac
done

if [[ -z "$STATE_FILE" ]]; then
  echo "error: --state-file is required" >&2
  exit 1
fi

BASELINE_FILE=".claude/review-baseline-untracked.local.txt"

skip() {
  echo "warn: $1" >&2
  echo "baseline_status: skipped"
  exit 0
}

[[ -f "$STATE_FILE" ]] || skip "state file not found: $STATE_FILE — skipping untracked-file baseline"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || skip "not inside a git work tree — skipping untracked-file baseline"

STARTED_AT=$(grep -m1 '^started_at:' "$STATE_FILE" | sed 's/^started_at: *//; s/"//g' || true)
[[ -n "$STARTED_AT" ]] || skip "no started_at in $STATE_FILE — skipping untracked-file baseline"

HEADER="agent-flow-untracked-baseline v1 started_at=$STARTED_AT"

mkdir -p .claude

if [[ "$FORCE" != true && -f "$BASELINE_FILE" ]]; then
  EXISTING_HEADER=""
  IFS= read -r -d '' EXISTING_HEADER < "$BASELINE_FILE" || true
  if [[ "$EXISTING_HEADER" == "$HEADER" ]]; then
    COUNT=$(( $(tr -cd '\0' < "$BASELINE_FILE" | wc -c | tr -d ' ') - 1 ))
    [[ "$COUNT" -lt 0 ]] && COUNT=0
    echo "baseline_status: kept"
    echo "baseline_path: $BASELINE_FILE"
    echo "baseline_count: $COUNT"
    exit 0
  fi
fi

TMP="${BASELINE_FILE}.tmp.$$"
RAW_PATHS=$(mktemp)  # outside .claude/ so it never shows up in its own snapshot
cleanup() { [[ -f "$TMP" ]] && rm -f "$TMP"; [[ -f "$RAW_PATHS" ]] && rm -f "$RAW_PATHS"; }
trap cleanup EXIT

# Capture untracked paths BEFORE writing anything under .claude/ — writing TMP
# first would make the temp file itself show up as a new untracked path.
git ls-files -z --others --exclude-standard > "$RAW_PATHS"
printf '%s\0' "$HEADER" > "$TMP"
cat "$RAW_PATHS" >> "$TMP"
mv "$TMP" "$BASELINE_FILE"
trap - EXIT

COUNT=$(( $(tr -cd '\0' < "$BASELINE_FILE" | wc -c | tr -d ' ') - 1 ))
[[ "$COUNT" -lt 0 ]] && COUNT=0

echo "baseline_status: written"
echo "baseline_path: $BASELINE_FILE"
echo "baseline_count: $COUNT"
exit 0
