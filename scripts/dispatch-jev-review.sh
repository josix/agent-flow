#!/bin/bash
# Shared JEV (typesafe.ai "System One") dispatcher for agent-flow Phase 4.
# Advisory only: the caller (workflows/implement-review-verify.js) must never
# let JEV output change a verdict, block, or start a fix round.
#
# Usage:
#   bash dispatch-jev-review.sh --state-file <path-to-state-file> [--round <n>] [--mode diff]
#
# Env vars: AGENT_FLOW_JEV (opt-in, must be "1"), AGENT_FLOW_NO_JEV (kill switch),
# AGENT_FLOW_JEV_API_KEY_ENV (default TYPESAFE_API_KEY), AGENT_FLOW_JEV_MODEL,
# AGENT_FLOW_JEV_BASE_URL, AGENT_FLOW_JEV_THRESHOLD (default 0.8),
# AGENT_FLOW_JEV_TIMEOUT (default 20s), AGENT_FLOW_JEV_MAX_DIFF_CHARS (default 90000),
# AGENT_FLOW_JEV_MAX_FILE_BYTES (default 100000).
#
# The caller never handles the API key: it is read only by indirect expansion
# of the env var named by AGENT_FLOW_JEV_API_KEY_ENV, and it reaches curl only
# via `curl --config -` on stdin — never argv, a file, or stdout/stderr.
#
# Stdout contract (one "key: value" per line; always exits 0):
#   jev_ran: true|false
#   jev_skip_reason: <reason>                 (only when jev_ran: false)
#   jev_questions_version: v1
#   jev_model: <id>
#   jev_threshold: <tau>
#   jev_truncated: true|false
#   jev_score_addresses_task: <0..1>
#   jev_score_unrelated_changes: <0..1>
#   jev_score_needs_clarification: <0..1>
#   jev_score_security_surface: <0..1>
#   jev_over_threshold: none|<comma-separated ids>
#   jev_surfaced: none|<comma-separated ids>          (subset of over_threshold; surface:true only)
#   jev_latency_ms: <int>
#
# Skip reasons: bad_mode, disabled, not_enabled, unavailable, missing_dep,
# questions_missing, no_key, bad_key, bad_url, no_diff, secret_suspected,
# timeout, network, too_large, auth, bad_request, rate_limited, overloaded,
# http_<code>, error.

set -euo pipefail
umask 077

STATE_FILE=""
ROUND=0
MODE="diff"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file)
      STATE_FILE="${2:-}"
      shift 2
      ;;
    --round)
      ROUND="${2:-0}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    *)
      echo "warn: unknown flag: $1" >&2
      shift
      ;;
  esac
done

if ! [[ "$ROUND" =~ ^[0-9]+$ ]]; then
  ROUND=0
fi

TMP_FILES=()
cleanup() {
  local f
  for f in ${TMP_FILES[@]+"${TMP_FILES[@]}"}; do
    [[ -f "$f" ]] && rm -f "$f"
  done
}
trap cleanup EXIT

SHADOW_LOG_DIR=".claude/jev"
SHADOW_LOG="$SHADOW_LOG_DIR/shadow-log.jsonl"

skip_pre() {
  # Pre-gate skip: no file writes, no git, no network.
  echo "jev_ran: false"
  echo "jev_skip_reason: $1"
  exit 0
}

skip_post() {
  # Post-gate skip: write one shadow-log line (no network call was made).
  write_shadow_log "$1" "null" "[]" "[]" "false" "0"
  echo "jev_ran: false"
  echo "jev_skip_reason: $1"
  exit 0
}

write_shadow_log() {
  # $1 skip_reason (empty string means scored), $2 scores JSON or "null",
  # $3 over_threshold JSON array, $4 surfaced JSON array, $5 truncated bool, $6 latency_ms
  mkdir -p "$SHADOW_LOG_DIR" 2>/dev/null || return 0
  local started_at
  started_at=$(printf '%s' "${FRONTMATTER:-}" | grep '^started_at:' | head -1 | sed 's/^started_at: *//' | tr -d '"')
  local reason_json
  if [[ -z "$1" ]]; then reason_json="null"; else reason_json=$(jq -n --arg r "$1" '$r'); fi
  jq -nc \
    --arg started_at "$started_at" \
    --argjson round "$ROUND" \
    --arg qv "v1" \
    --arg model "${MODEL:-}" \
    --argjson threshold "${THRESHOLD:-0.8}" \
    --argjson truncated "$5" \
    --argjson diff_chars "${DIFF_CHARS:-0}" \
    --argjson omitted_files "${OMITTED_COUNT:-0}" \
    --argjson scores "$2" \
    --argjson over_threshold "$3" \
    --argjson surfaced "$4" \
    --argjson skip_reason "$reason_json" \
    --argjson latency_ms "$6" \
    '{kind:"score", started_at:$started_at, round:$round, questions_version:$qv, model:$model, threshold:$threshold, truncated:$truncated, diff_chars:$diff_chars, omitted_files:$omitted_files, scores:$scores, over_threshold:$over_threshold, surfaced:$surfaced, skip_reason:$skip_reason, latency_ms:$latency_ms}' \
    >> "$SHADOW_LOG" 2>/dev/null || true
}

join_or_none() {
  if [[ $# -eq 0 ]]; then
    echo "none"
  else
    local IFS=,
    echo "$*"
  fi
}

is_secret_path() {
  local low
  low=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$low" in
    *.env|*.env.*|*/.env|*/.env.*|.env|.env.*|*.pem|*.key|*id_rsa*|*id_ed25519*|*id_ecdsa*|*id_dsa*|*secret*|*credential*)
      return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Pre-gate checks (order matters; each exits before touching git/network/disk)
# ---------------------------------------------------------------------------

if [[ "$MODE" != "diff" ]]; then
  skip_pre bad_mode
fi

if [[ "${AGENT_FLOW_NO_JEV:-}" == "1" ]]; then
  skip_pre disabled
fi

if [[ "${AGENT_FLOW_JEV:-}" != "1" ]]; then
  skip_pre not_enabled
fi

if [[ -z "$STATE_FILE" || ! -f "$STATE_FILE" ]]; then
  skip_pre unavailable
fi

JEV_BLOCK=$(grep -A5 '^jev:' "$STATE_FILE" || true)
JEV_STATE_AVAILABLE=$(printf '%s\n' "$JEV_BLOCK" | grep '  available:' | head -1 | sed 's/.*available: *//')
if [[ "$JEV_STATE_AVAILABLE" != "true" ]]; then
  skip_pre unavailable
fi

if ! command -v curl >/dev/null 2>&1; then
  skip_pre missing_dep
fi
if ! command -v jq >/dev/null 2>&1; then
  skip_pre missing_dep
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QFILE="$ROOT_DIR/templates/jev/questions.v1.json"
if [[ ! -r "$QFILE" ]] || ! jq -e '.questions | type == "array" and length > 0' "$QFILE" >/dev/null 2>&1; then
  skip_pre questions_missing
fi

KEY_ENV=$(printf '%s\n' "$JEV_BLOCK" | grep '  key_env:' | head -1 | sed 's/.*key_env: *//' | tr -d '"')
if [[ -z "$KEY_ENV" ]] || ! [[ "$KEY_ENV" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  skip_pre no_key
fi
KEY_VALUE="${!KEY_ENV:-}"
if [[ -z "$KEY_VALUE" ]]; then
  skip_pre no_key
fi
case "$KEY_VALUE" in
  *'"'*|*'\'*)
    skip_pre bad_key ;;
esac
case "$KEY_VALUE" in
  *$'\r'*|*$'\n'*) skip_pre bad_key ;;
esac

BASE_URL="${AGENT_FLOW_JEV_BASE_URL:-https://api.typesafe.ai}"
case "$BASE_URL" in
  https://*|http://127.0.0.1*|http://localhost*) ;;
  *) skip_pre bad_url ;;
esac
ENDPOINT="${BASE_URL%/}/v1/systemone"

MODEL_FROM_STATE=$(printf '%s\n' "$JEV_BLOCK" | grep '  model:' | head -1 | sed 's/.*model: *//' | tr -d '"')
MODEL="${AGENT_FLOW_JEV_MODEL:-${MODEL_FROM_STATE:-jev-1.13.0}}"
if ! [[ "$MODEL" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "warn: JEV model is invalid — using jev-1.13.0" >&2
  MODEL="jev-1.13.0"
fi

THRESHOLD="${AGENT_FLOW_JEV_THRESHOLD:-0.8}"
THRESHOLD_OK=$(awk -v t="$THRESHOLD" 'BEGIN{ if (t+0 != t) { print 0 } else if (t+0 >= 0.5 && t+0 <= 1.0) { print 1 } else { print 0 } }' 2>/dev/null || echo 0)
if [[ "$THRESHOLD_OK" != "1" ]]; then
  echo "warn: AGENT_FLOW_JEV_THRESHOLD invalid — using 0.8" >&2
  THRESHOLD=0.8
fi

# ---------------------------------------------------------------------------
# Read intent (frontmatter only; actions/assumptions/task-when-goal-set are
# never sent — see skills/verification-gates/references/jev-signal.md)
# ---------------------------------------------------------------------------

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
unescape() {
  printf '%s' "$1" | jq -Rr 'try fromjson catch .'
}
GOAL=$(unescape "$(printf '%s\n' "$FRONTMATTER" | grep '^  goal:' | head -1 | sed 's/^  goal: *//')")
CONSTRAINTS=$(unescape "$(printf '%s\n' "$FRONTMATTER" | grep '^  constraints:' | head -1 | sed 's/^  constraints: *//')")
DESCRIPTION=$(unescape "$(printf '%s\n' "$FRONTMATTER" | grep '^  description:' | head -1 | sed 's/^  description: *//')")
TASK=$(unescape "$(printf '%s\n' "$FRONTMATTER" | grep '^task:' | head -1 | sed 's/^task: *//')")
if [[ -z "$GOAL" ]]; then GOAL="$TASK"; fi

# ---------------------------------------------------------------------------
# Build the diff (always the full change; JEV has no --diff-base mode)
# ---------------------------------------------------------------------------

MAX_FILE_BYTES="${AGENT_FLOW_JEV_MAX_FILE_BYTES:-100000}"
MAX_DIFF_CHARS="${AGENT_FLOW_JEV_MAX_DIFF_CHARS:-90000}"
if ! [[ "$MAX_DIFF_CHARS" =~ ^[0-9]+$ ]] || [[ "$MAX_DIFF_CHARS" -le 0 ]]; then
  echo "warn: AGENT_FLOW_JEV_MAX_DIFF_CHARS invalid — using 90000" >&2
  MAX_DIFF_CHARS=90000
elif [[ "$MAX_DIFF_CHARS" -gt 90000 ]]; then
  echo "warn: AGENT_FLOW_JEV_MAX_DIFF_CHARS=$MAX_DIFF_CHARS exceeds 90000 — live 400s (max_tokens_exceeded) were seen between 100000 and 150000 chars" >&2
fi

SECRET_PATHSPECS=(':(exclude,glob,icase)**/.env*' ':(exclude,glob,icase)**/*.pem' ':(exclude,glob,icase)**/*.key' ':(exclude,glob,icase)**/id_*' ':(exclude,glob,icase)**/*secret*' ':(exclude,glob,icase)**/*credential*')

DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/||' || true)
DEFAULT_BRANCH=${DEFAULT_BRANCH:-origin/main}
MERGE_BASE=$(git merge-base HEAD "$DEFAULT_BRANCH" 2>/dev/null || echo "$DEFAULT_BRANCH")

TRACKED_DIFF=$(printf '%s\n%s' \
  "$(git diff "$MERGE_BASE"..HEAD -- . "${SECRET_PATHSPECS[@]}" 2>/dev/null || true)" \
  "$(git diff HEAD -- . "${SECRET_PATHSPECS[@]}" 2>/dev/null || true)")

OMITTED_COUNT=0
OMITTED_NOTE=""

# Tracked files excluded by the secret pathspecs above (listed, not inlined).
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if is_secret_path "$f"; then
    OMITTED_COUNT=$((OMITTED_COUNT+1))
    OMITTED_NOTE+=$'\n'"#   $f (secret-like path)"
  fi
done < <({ git diff --name-only "$MERGE_BASE"..HEAD 2>/dev/null; git diff --name-only HEAD 2>/dev/null; } | sort -u)

UNTRACKED_DIFF=""
while IFS= read -r -d '' f; do
  [[ -z "$f" || ! -f "$f" ]] && continue
  if is_secret_path "$f"; then
    OMITTED_COUNT=$((OMITTED_COUNT+1))
    OMITTED_NOTE+=$'\n'"#   $f (secret-like path)"
    continue
  fi
  case "$f" in
    node_modules/*|*/node_modules/*|.venv/*|venv/*|dist/*|build/*|.next/*|coverage/*|\
    .claude/*|graphify-out/*|explain-out/*|site/*|*.min.js|*.map|*.lock)
      OMITTED_COUNT=$((OMITTED_COUNT+1))
      OMITTED_NOTE+=$'\n'"#   $f (artifact path)"
      continue ;;
  esac
  size=$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo 0)
  if [[ "${size:-0}" -gt "$MAX_FILE_BYTES" ]]; then
    OMITTED_COUNT=$((OMITTED_COUNT+1))
    OMITTED_NOTE+=$'\n'"#   $f (${size} bytes)"
    continue
  fi
  if [[ "$(git diff --no-index --numstat -- /dev/null "$f" 2>/dev/null | cut -f1)" == "-" ]]; then
    OMITTED_COUNT=$((OMITTED_COUNT+1))
    OMITTED_NOTE+=$'\n'"#   $f (binary)"
    continue
  fi
  UNTRACKED_DIFF+=$'\n'"$(git diff --no-index -- /dev/null "$f" 2>/dev/null || true)"
done < <(git ls-files -z --others --exclude-standard 2>/dev/null)

DIFF_CORE=$(printf '%s\n%s' "$TRACKED_DIFF" "$UNTRACKED_DIFF")
DIFF_CORE_TRIMMED="$(printf '%s' "$DIFF_CORE" | tr -d '[:space:]')"

if [[ -z "$DIFF_CORE_TRIMMED" ]]; then
  skip_post no_diff
fi

DIFF_CHARS=${#DIFF_CORE}
DIFF_TRUNCATED=false
DIFF_FOR_STATE="$DIFF_CORE"
if [[ "$DIFF_CHARS" -gt "$MAX_DIFF_CHARS" ]]; then
  DIFF_TRUNCATED=true
  DIFF_FOR_STATE="${DIFF_CORE:0:$MAX_DIFF_CHARS}"
fi

# ---------------------------------------------------------------------------
# Assemble the state text (order: Goal, Constraints, Description, Diff)
# ---------------------------------------------------------------------------

STATE_TEXT=""
[[ -n "$GOAL" ]] && STATE_TEXT+="Goal:
$GOAL

"
[[ -n "$CONSTRAINTS" ]] && STATE_TEXT+="Constraints:
$CONSTRAINTS

"
[[ -n "$DESCRIPTION" ]] && STATE_TEXT+="Description:
$DESCRIPTION

"
STATE_TEXT+="Diff:
$DIFF_FOR_STATE"

# ---------------------------------------------------------------------------
# Secret scan (whole state text, before truncation of the diff for sending)
# ---------------------------------------------------------------------------

SECRET_SCAN_TEXT="Goal:
$GOAL

Constraints:
$CONSTRAINTS

Description:
$DESCRIPTION

Diff:
$DIFF_CORE"

SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'
  '\-\-\-\-\-BEGIN ([A-Z0-9]+ )*PRIVATE KEY\-\-\-\-\-'
  'sk-[A-Za-z0-9_-]{20,}'
  'gh[pousr]_[A-Za-z0-9]{36,}'
  'xox[abprs]-[A-Za-z0-9-]{10,}'
)
for pat in "${SECRET_PATTERNS[@]}"; do
  if printf '%s' "$SECRET_SCAN_TEXT" | grep -Eq -- "$pat"; then
    echo "warn: secret-pattern match in diff/intent text — aborting before any network call" >&2
    skip_post secret_suspected
  fi
done

# ---------------------------------------------------------------------------
# Build request body and call the API. The key reaches curl only via a
# `--config -` stdin document, never argv, a file, or stdout/stderr.
# ---------------------------------------------------------------------------

STATE_TMP=$(mktemp); TMP_FILES+=("$STATE_TMP")
BODY_TMP=$(mktemp); TMP_FILES+=("$BODY_TMP")
RESP_TMP=$(mktemp); TMP_FILES+=("$RESP_TMP")

printf '%s' "$STATE_TEXT" > "$STATE_TMP"
jq -Rs --arg model "$MODEL" --slurpfile q "$QFILE" \
  '{state: ., model: $model, questions: ($q[0].questions | map({key: .id, value: {type: "noul", instructions: .instructions, criteria: .criteria}}) | from_entries)}' \
  < "$STATE_TMP" > "$BODY_TMP"

TIMEOUT="${AGENT_FLOW_JEV_TIMEOUT:-20}"
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || TIMEOUT=20

TOTAL_TIME=0
ATTEMPT=1
HTTP_CODE=""
CURL_EXIT=0
while :; do
  set +e
  CURL_OUT=$(printf 'header = "Authorization: Bearer %s"\n' "$KEY_VALUE" | curl -sS --max-time "$TIMEOUT" --config - \
    -H 'Content-Type: application/json' --data-binary "@$BODY_TMP" \
    -o "$RESP_TMP" -w '%{http_code} %{time_total}' "$ENDPOINT")
  CURL_EXIT=$?
  set -e
  if [[ "$CURL_EXIT" -ne 0 ]]; then
    break
  fi
  HTTP_CODE=$(printf '%s' "$CURL_OUT" | awk '{print $1}')
  TIME_TOTAL=$(printf '%s' "$CURL_OUT" | awk '{print $2}')
  TOTAL_TIME=$(awk -v a="$TOTAL_TIME" -v b="${TIME_TOTAL:-0}" 'BEGIN{printf "%f", a+b}')
  if [[ ( "$HTTP_CODE" == "429" || "$HTTP_CODE" == "529" ) && "$ATTEMPT" -lt 2 ]]; then
    ATTEMPT=$((ATTEMPT+1))
    sleep 1
    continue
  fi
  break
done
LATENCY_MS=$(awk -v t="$TOTAL_TIME" 'BEGIN{printf "%d", t*1000}')

if [[ "$CURL_EXIT" -ne 0 ]]; then
  if [[ "$CURL_EXIT" -eq 28 ]]; then REASON=timeout; else REASON=network; fi
  skip_post "$REASON"
fi

case "$HTTP_CODE" in
  200) ;;
  400)
    if grep -q 'max_tokens_exceeded' "$RESP_TMP" 2>/dev/null; then
      skip_post too_large
    else
      skip_post http_400
    fi
    ;;
  401) skip_post auth ;;
  422) skip_post bad_request ;;
  429) skip_post rate_limited ;;
  529) skip_post overloaded ;;
  *) skip_post "http_${HTTP_CODE:-unknown}" ;;
esac

if ! jq -e . "$RESP_TMP" >/dev/null 2>&1; then
  skip_post error
fi

IDS=(addresses_task unrelated_changes needs_clarification security_surface)
SCORES_JSON="{}"
PARSE_ERROR=false
for id in "${IDS[@]}"; do
  val=$(jq -r --arg id "$id" '.answers[$id].noul // empty | select(type=="number")' "$RESP_TMP" 2>/dev/null || true)
  if [[ -z "$val" ]]; then PARSE_ERROR=true; break; fi
  in_range=$(awk -v v="$val" 'BEGIN{print (v>=0 && v<=1) ? 1 : 0}')
  if [[ "$in_range" != "1" ]]; then PARSE_ERROR=true; break; fi
  SCORES_JSON=$(printf '%s' "$SCORES_JSON" | jq --arg id "$id" --argjson v "$val" '. + {($id): $v}')
done
if [[ "$PARSE_ERROR" == true ]]; then
  skip_post error
fi

RESP_MODEL=$(jq -r '.model // empty' "$RESP_TMP" 2>/dev/null || true)
if [[ -n "$RESP_MODEL" && "$RESP_MODEL" != "$MODEL" ]]; then
  echo "warn: JEV response model '$RESP_MODEL' differs from requested '$MODEL'" >&2
fi
OUT_MODEL="${RESP_MODEL:-$MODEL}"

SURFACE_IDS=$(jq -r '.questions[] | select(.surface) | .id' "$QFILE")
OVER=()
SURFACED=()
for id in "${IDS[@]}"; do
  flag_when=$(jq -r --arg id "$id" '.questions[] | select(.id==$id) | .flag_when' "$QFILE")
  score=$(printf '%s' "$SCORES_JSON" | jq -r --arg id "$id" '.[$id]')
  flagged=$(awk -v s="$score" -v t="$THRESHOLD" -v fw="$flag_when" 'BEGIN{
    eps=1e-9
    if (fw=="high") { print (s >= t-eps) ? 1 : 0 } else { print (s <= (1-t)+eps) ? 1 : 0 }
  }')
  if [[ "$flagged" == "1" ]]; then
    OVER+=("$id")
    if printf '%s\n' "$SURFACE_IDS" | grep -qx "$id"; then
      SURFACED+=("$id")
    fi
  fi
done

OVER_JSON=$(printf '%s\n' "${OVER[@]+"${OVER[@]}"}" | jq -Rsc 'split("\n") | map(select(length>0))')
SURFACED_JSON=$(printf '%s\n' "${SURFACED[@]+"${SURFACED[@]}"}" | jq -Rsc 'split("\n") | map(select(length>0))')

write_shadow_log "" "$SCORES_JSON" "$OVER_JSON" "$SURFACED_JSON" "$DIFF_TRUNCATED" "$LATENCY_MS"

echo "jev_ran: true"
echo "jev_questions_version: v1"
echo "jev_model: $OUT_MODEL"
echo "jev_threshold: $THRESHOLD"
echo "jev_truncated: $DIFF_TRUNCATED"
echo "jev_score_addresses_task: $(printf '%s' "$SCORES_JSON" | jq -r '.addresses_task')"
echo "jev_score_unrelated_changes: $(printf '%s' "$SCORES_JSON" | jq -r '.unrelated_changes')"
echo "jev_score_needs_clarification: $(printf '%s' "$SCORES_JSON" | jq -r '.needs_clarification')"
echo "jev_score_security_surface: $(printf '%s' "$SCORES_JSON" | jq -r '.security_surface')"
echo "jev_over_threshold: $(join_or_none ${OVER[@]+"${OVER[@]}"})"
echo "jev_surfaced: $(join_or_none ${SURFACED[@]+"${SURFACED[@]}"})"
echo "jev_latency_ms: $LATENCY_MS"
exit 0
