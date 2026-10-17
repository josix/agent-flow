#!/bin/bash
# Shared Codex co-review dispatcher for agent-flow Phase 4.
# Called by /orchestrate, normally in parallel with Lawliet (no findings file);
# pass --lawliet-findings only when running after Lawliet.
#
# Usage:
#   bash dispatch-codex-review.sh \
#     --state-file <path-to-state-file> \
#     [--lawliet-findings <path-to-findings-file>] \
#     [--diff-base <rev>]   # review-fix rounds: review only changes since <rev>
#
# Size guards (Codex rejects prompts over ~1M chars — seen with 6M–180M
# diffs inflated by untracked artifacts):
#   - untracked files are skipped when binary, over AGENT_FLOW_CODEX_MAX_FILE_BYTES
#     (default 100000), or under common artifact dirs (extended list below)
#   - untracked files with a secret-like basename (.env, *.pem, id_rsa*, ...)
#     are never inlined
#   - untracked files that already existed before this run — per
#     .claude/review-baseline-untracked.local.txt, written by
#     scripts/snapshot-untracked.sh — are skipped and only counted, not listed
#   - the whole diff is capped at AGENT_FLOW_CODEX_MAX_DIFF_CHARS (default 800000);
#     beyond that Codex gets `git diff --stat` and reads files itself
#
# Untracked-file precedence (first match wins): pre-existing (baseline) >
# secret-like name > artifact path > oversize/binary > inline.
#
# Baseline fallback: when no baseline exists, or its started_at doesn't match
# this run's state file, this script falls back to inlining all untracked
# files (still subject to the secret/artifact/size guards above) and prints a
# `warn:` line. Set AGENT_FLOW_CODEX_INLINE_UNTRACKED=0 to disable inlining
# entirely in that fallback (untracked files are then counted as
# "pre-existing" and never inlined).
#
# Output (stdout, YAML-like key: value lines):
#   codex_ran: true|false
#   codex_exit: <number>            (only when codex_ran: true)
#   codex_verdict: <string>         (only when codex_ran: true)
#   codex_raw_path: <tmpfile-path>  (only when codex_ran: true; on failure it
#                                    points at whatever partial output exists)
#   codex_skip_reason: <string>     (unavailable when codex_ran: false;
#                                    timeout | error when codex_ran: true and
#                                    codex exec exited non-zero)
#   codex_untracked: inlined=<n> preexisting=<n> artifact=<n> secret=<n>
#                     oversize_or_binary=<n> baseline=<used|missing|stale>
#                     (only when codex_ran: true; informational)
#
# The caller is responsible for rm -f "$codex_raw_path" after reading it.

set -euo pipefail

STATE_FILE=""
LAWLIET_FINDINGS=""
DIFF_BASE=""

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
    --diff-base)
      DIFF_BASE="$2"
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

# Resolve model: AGENT_FLOW_CODEX_MODEL env var > top-level model in ~/.codex/config.toml > empty
CODEX_MODEL=""
if [[ -n "${AGENT_FLOW_CODEX_MODEL:-}" ]]; then
  CODEX_MODEL="$AGENT_FLOW_CODEX_MODEL"
  echo "info: codex model $CODEX_MODEL (source: env)" >&2
else
  _CODEX_CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"
  if [[ -r "$_CODEX_CONFIG" ]]; then
    CODEX_MODEL=$(awk '
      /^[[:space:]]*\[/ { exit }
      /^[[:space:]]*model[[:space:]]*=/ {
        sub(/^[^=]*=[[:space:]]*/, "")
        gsub(/^"|"$/, "")
        print
        exit
      }
    ' "$_CODEX_CONFIG")
    if [[ -n "$CODEX_MODEL" ]]; then
      echo "info: codex model $CODEX_MODEL (source: config.toml)" >&2
    fi
  fi
fi

# Build model args array (safe for bash 3.2 with set -u)
CODEX_MODEL_ARGS=()
if [[ -n "$CODEX_MODEL" ]]; then
  CODEX_MODEL_ARGS=(-m "$CODEX_MODEL")
fi

# Read task description from state file
TASK_DESC=$(grep '^task:' "$STATE_FILE" | sed 's/^task: *//')

# Read the untracked-file baseline (scripts/snapshot-untracked.sh), if any,
# and classify it against this run's started_at.
STARTED_AT=$(grep -m1 '^started_at:' "$STATE_FILE" | sed 's/^started_at: *//; s/"//g' || true)
BASELINE_FILE=".claude/review-baseline-untracked.local.txt"
BASELINE_STATUS="missing"
NL=$'\n'
BASELINE_SET="$NL"
if [[ -f "$BASELINE_FILE" ]]; then
  BASELINE_HDR=""
  {
    IFS= read -r -d '' BASELINE_HDR || true
    while IFS= read -r -d '' p; do BASELINE_SET+="$p$NL"; done
  } < "$BASELINE_FILE"
  if [[ -n "$STARTED_AT" && "$BASELINE_HDR" == "agent-flow-untracked-baseline v1 started_at=$STARTED_AT" ]]; then
    BASELINE_STATUS="used"
  else
    BASELINE_STATUS="stale"
  fi
fi
if [[ "$BASELINE_STATUS" != "used" ]]; then
  echo "warn: untracked-file baseline $BASELINE_STATUS — falling back to inlining untracked files (artifact/secret/size guards still apply)" >&2
fi
INLINE_UNTRACKED="${AGENT_FLOW_CODEX_INLINE_UNTRACKED:-1}"

# Build GIT_DIFF: (merge-base..HEAD + working tree) or (--diff-base..worktree),
# plus untracked files that pass the baseline/secret/artifact/size guards.
MAX_FILE_BYTES="${AGENT_FLOW_CODEX_MAX_FILE_BYTES:-100000}"
MAX_DIFF_CHARS="${AGENT_FLOW_CODEX_MAX_DIFF_CHARS:-800000}"
if [[ -n "$DIFF_BASE" ]]; then
  TRACKED_DIFF=$(git diff "$DIFF_BASE" 2>/dev/null || true)
  STAT_RANGE=("$DIFF_BASE")
else
  # `|| true`: without origin/HEAD (e.g. a remote added by hand) this pipeline
  # fails and, under set -e + pipefail, used to kill the script with exit 128.
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/||' || true)
  DEFAULT_BRANCH=${DEFAULT_BRANCH:-origin/main}
  MERGE_BASE=$(git merge-base HEAD "$DEFAULT_BRANCH" 2>/dev/null || echo "$DEFAULT_BRANCH")
  TRACKED_DIFF=$(printf '%s\n%s' "$(git diff "$MERGE_BASE"..HEAD 2>/dev/null || true)" "$(git diff HEAD 2>/dev/null || true)")
  STAT_RANGE=("$MERGE_BASE")
fi

UNTRACKED_DIFF=""
SKIPPED_UNTRACKED=()
N_INLINED=0
N_PREEXISTING=0
N_ARTIFACT=0
N_SECRET=0
N_OVERSIZE_OR_BINARY=0
while IFS= read -r -d '' f; do
  [[ -z "$f" || ! -f "$f" ]] && continue

  # 1. Pre-existing (per the baseline, and not modified since it was taken).
  if [[ "$BASELINE_STATUS" == "used" ]]; then
    if [[ "$BASELINE_SET" == *"$NL$f$NL"* ]] && [[ ! "$f" -nt "$BASELINE_FILE" ]]; then
      N_PREEXISTING=$((N_PREEXISTING+1)); continue
    fi
  elif [[ "$INLINE_UNTRACKED" == "0" ]]; then
    N_PREEXISTING=$((N_PREEXISTING+1)); continue
  fi

  # 2. Secret-like basename (same set as hooks/scripts/validate-changes.sh).
  base="${f##*/}"
  case "$base" in
    .env|.env.*|*.env|*.pem|*.key|id_rsa*|id_ed25519*|credentials|credentials.*|*.credentials|secrets.*|*.secret|*.secrets)
      SKIPPED_UNTRACKED+=("$f (secret-like name)"); N_SECRET=$((N_SECRET+1)); continue ;;
  esac

  # 3. Artifact / scratch paths.
  case "$f" in
    node_modules/*|*/node_modules/*|.venv/*|venv/*|dist/*|build/*|.next/*|coverage/*|\
    .playwright-mcp/*|.claude/*|graphify-out/*|explain-out/*|site/*|.agentic-retrieval/*|*.min.js|*.map|*.lock|\
    tmp/*|*/tmp/*|.aider*|*/.aider*|*-results.json|*.patch|*.diff|*.orig|*.rej|\
    _site/*|*/_site/*|_build/*|*/_build/*|htmlcov/*|*/htmlcov/*|.DS_Store|*/.DS_Store|*.log|*.sqlite|*.sqlite3|*.db|.senku/*)
      SKIPPED_UNTRACKED+=("$f (artifact path)"); N_ARTIFACT=$((N_ARTIFACT+1)); continue ;;
  esac

  # 4-5. Oversize / binary.
  size=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
  if [[ "${size:-0}" -gt "$MAX_FILE_BYTES" ]]; then
    SKIPPED_UNTRACKED+=("$f (${size} bytes)"); N_OVERSIZE_OR_BINARY=$((N_OVERSIZE_OR_BINARY+1)); continue
  fi
  if [[ "$(git diff --no-index --numstat -- /dev/null "$f" 2>/dev/null | cut -f1)" == "-" ]]; then
    SKIPPED_UNTRACKED+=("$f (binary)"); N_OVERSIZE_OR_BINARY=$((N_OVERSIZE_OR_BINARY+1)); continue
  fi

  # 6. Inline.
  UNTRACKED_DIFF+=$'\n'"$(git diff --no-index -- /dev/null "$f" 2>/dev/null || true)"
  N_INLINED=$((N_INLINED+1))
done < <(git ls-files -z --others --exclude-standard 2>/dev/null)  # -z: paths with spaces/non-ASCII arrive unquoted

echo "info: untracked files — inlined $N_INLINED, pre-existing $N_PREEXISTING (baseline), artifact $N_ARTIFACT, secret-like $N_SECRET, oversize/binary $N_OVERSIZE_OR_BINARY" >&2

GIT_DIFF=$(printf '%s\n%s' "$TRACKED_DIFF" "$UNTRACKED_DIFF")
if [[ "$N_PREEXISTING" -gt 0 ]]; then
  GIT_DIFF+=$'\n\n'"# $N_PREEXISTING untracked file(s) that existed before this run were left out as unrelated to this task."
fi
if [[ ${#SKIPPED_UNTRACKED[@]} -gt 0 ]]; then
  GIT_DIFF+=$'\n\n'"# Untracked files omitted from this diff (read them directly if relevant):"
  for f in "${SKIPPED_UNTRACKED[@]}"; do GIT_DIFF+=$'\n'"#   $f"; done
fi
CODEX_UNTRACKED_LINE="codex_untracked: inlined=$N_INLINED preexisting=$N_PREEXISTING artifact=$N_ARTIFACT secret=$N_SECRET oversize_or_binary=$N_OVERSIZE_OR_BINARY baseline=$BASELINE_STATUS"
if [[ ${#GIT_DIFF} -gt "$MAX_DIFF_CHARS" ]]; then
  echo "warn: diff is ${#GIT_DIFF} chars (> $MAX_DIFF_CHARS) — sending --stat only; Codex will read files itself" >&2
  GIT_DIFF=$(printf '%s\n\n%s' \
    "# Full diff omitted: ${#GIT_DIFF} chars exceeds the ${MAX_DIFF_CHARS}-char cap. Files changed are listed below; read the relevant ones directly (you have read-only repo access) and review their changes." \
    "$(git diff --stat "${STAT_RANGE[@]}" 2>/dev/null || true)")
fi

# Read Lawliet findings (optional — absent in the parallel Phase 4 + 5 flow)
LAWLIET_FINDINGS_CONTENT="(Lawliet is reviewing in parallel — its linter-grounded findings are not available. Do not duplicate linter/type-checker work; see the rubric above.)"
if [[ -n "$LAWLIET_FINDINGS" ]]; then
  if [[ -s "$LAWLIET_FINDINGS" ]]; then
    LAWLIET_FINDINGS_CONTENT=$(cat "$LAWLIET_FINDINGS")
  else
    echo "warn: Lawliet findings empty or missing — Codex receiving empty section" >&2
    LAWLIET_FINDINGS_CONTENT=""
  fi
fi

# Create output temp file (caller must rm -f it after reading)
CODEX_OUT=$(mktemp)

# Rubric ships with the plugin so it applies in every project, not only in
# repos that happen to carry agent-flow's AGENTS.md. A repo's own AGENTS.md
# (auto-loaded by codex) still adds its repo-specific checklist on top.
RUBRIC_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/codex/review-rubric.md"
if [[ -r "$RUBRIC_FILE" ]]; then
  RUBRIC=$(cat "$RUBRIC_FILE")
else
  echo "warn: Codex rubric not found at $RUBRIC_FILE — falling back to AGENTS.md at the repo root" >&2
  RUBRIC="You are the Phase 4 co-reviewer. Follow the rubric in AGENTS.md at the repo root."
fi
SCOPE_NOTE="Review the full change for this task."
if [[ -n "$DIFF_BASE" ]]; then
  SCOPE_NOTE="This is a re-review after a fix round: the diff below is scoped to the fix (since $DIFF_BASE). Follow the rubric's re-review section."
fi

# Build prompt body
BODY=$(printf '%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s' \
  "$RUBRIC" \
  "$SCOPE_NOTE" \
  "## Task description" \
  "$TASK_DESC" \
  "## Lawliet's review (do not duplicate)" \
  "$LAWLIET_FINDINGS_CONTENT" \
  "## Diff under review" \
  "$GIT_DIFF")

# Run codex, time-bounded when a timeout binary exists.
# AGENT_FLOW_CODEX_TIMEOUT (seconds, default 480) — 120s proved too short for
# real diffs and silently degraded Phase 4 to Lawliet-only.
CODEX_TIMEOUT="${AGENT_FLOW_CODEX_TIMEOUT:-480}"
if ! [[ "$CODEX_TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "warn: AGENT_FLOW_CODEX_TIMEOUT='$CODEX_TIMEOUT' is not an integer — using 480" >&2
  CODEX_TIMEOUT=480
fi
TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout "$CODEX_TIMEOUT")
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout "$CODEX_TIMEOUT")
else
  echo "warn: no timeout/gtimeout binary found — Codex dispatch will not be time-bounded (install coreutils on macOS: brew install coreutils)" >&2
fi
TIMEOUT_USED=false
[[ ${#TIMEOUT_CMD[@]} -gt 0 ]] && TIMEOUT_USED=true

CODEX_EXIT=0
set +e
printf '%s' "$BODY" | ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} codex exec \
  -s read-only --ignore-user-config \
  ${CODEX_MODEL_ARGS[@]+"${CODEX_MODEL_ARGS[@]}"} \
  -c model_reasoning_effort="high" \
  --output-last-message "$CODEX_OUT" - 2>&1 | tail -5 >&2
CODEX_EXIT=${PIPESTATUS[1]}
set -e

if [[ "$CODEX_EXIT" -ne 0 ]]; then
  if [[ "$TIMEOUT_USED" == true && "$CODEX_EXIT" -eq 124 ]]; then
    CODEX_SKIP_REASON="timeout"
  else
    CODEX_SKIP_REASON="error"
  fi
  _CODEX_SNIPPET=""
  if [[ -s "$CODEX_OUT" ]]; then
    _CODEX_SNIPPET=$(tr '\n' ' ' < "$CODEX_OUT" | sed 's/  */ /g' | tail -c 300)
  fi
  if [[ -n "$_CODEX_SNIPPET" ]]; then
    echo "warn: codex exec failed with exit $CODEX_EXIT (${CODEX_SKIP_REASON}) — treating as advisory (Phase 4 degrades to Lawliet-only); codex said: $_CODEX_SNIPPET" >&2
  else
    echo "warn: codex exec failed with exit $CODEX_EXIT (${CODEX_SKIP_REASON}) — treating as advisory (Phase 4 degrades to Lawliet-only)" >&2
  fi
  echo "codex_ran: true"
  echo "codex_exit: $CODEX_EXIT"
  echo "codex_verdict: ADVISORY"
  echo "codex_skip_reason: $CODEX_SKIP_REASON"
  echo "codex_raw_path: $CODEX_OUT"
  echo "$CODEX_UNTRACKED_LINE"
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
echo "$CODEX_UNTRACKED_LINE"
exit 0
