#!/bin/bash
# Append a Phase 6 outcome line to the JEV shadow log for later calibration.
# Usage: record-jev-shadow.sh --state-file <path>   (JSON on stdin)
# stdin shape: {"status": "...", "profile": "...", "history": [...]}
# (the workflow result's status/profile and its history array, verbatim JSON)
#
# Every field from stdin is re-projected through a whitelist before it is
# written, so free text (a summary, a Lawliet quote, etc.) can never reach
# the log file.
#
# Always exits 0. Stdout:
#   jev_recorded: true|false
#   jev_skip_reason: unavailable|bad_input   (only when jev_recorded: false)

set -euo pipefail
umask 077

STATE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file)
      STATE_FILE="${2:-}"
      shift 2
      ;;
    *)
      echo "warn: unknown flag: $1" >&2
      shift
      ;;
  esac
done

fail() {
  echo "jev_recorded: false"
  echo "jev_skip_reason: $1"
  exit 0
}

if [[ -z "$STATE_FILE" || ! -f "$STATE_FILE" ]]; then
  fail unavailable
fi
if ! command -v jq >/dev/null 2>&1; then
  fail unavailable
fi

JEV_AVAILABLE=$(grep -A5 '^jev:' "$STATE_FILE" 2>/dev/null | grep '  available:' | head -1 | sed 's/.*available: *//')
if [[ "$JEV_AVAILABLE" != "true" ]]; then
  fail unavailable
fi

INPUT_TMP=$(mktemp)
trap 'rm -f "$INPUT_TMP"' EXIT
cat > "$INPUT_TMP"

if ! jq -e 'type=="object" and (.history|type=="array")' "$INPUT_TMP" >/dev/null 2>&1; then
  fail bad_input
fi

STARTED_AT=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^started_at:' | head -1 | sed 's/^started_at: *//' | tr -d '"')

mkdir -p .claude/jev 2>/dev/null || true
jq -c \
  --arg started_at "$STARTED_AT" \
  --argjson known_ids '["addresses_task","unrelated_changes","needs_clarification","security_surface"]' \
  '
  def clean_jev:
    if type == "object" then
      { scores: ((.scores // {}) | with_entries(select(.value|type=="number"))),
        over: ((.over // []) | map(select(type=="string" and (. as $x | $known_ids | index($x) != null)))),
        surfaced: ((.surfaced // []) | map(select(type=="string" and (. as $x | $known_ids | index($x) != null)))),
        truncated: ((.truncated // false) | if type=="boolean" then . else false end) }
    elif type == "string" and test("^(off|skipped:[a-z_0-9]+)$") then .
    else null
    end;
  def clean_entry:
    { round: (if (.round|type)=="number" then .round else null end),
      lawliet: (if .lawliet=="APPROVED" or .lawliet=="NEEDS_CHANGES" then .lawliet else null end),
      codex: (if (.codex|type)=="string" then .codex[0:20] else null end),
      alphonse: (if .alphonse=="VERIFIED" or .alphonse=="FAILED" or .alphonse=="ENVIRONMENT_BLOCKED" then .alphonse else null end),
      open: (if (.open|type)=="number" then .open else null end),
      errors: (if (.errors|type)=="number" then .errors else null end),
      intent_mismatch: (if (.intent_mismatch|type)=="boolean" then .intent_mismatch else null end),
      jev: (.jev | clean_jev) };
  {
    kind: "outcome",
    started_at: $started_at,
    status: (if .status=="complete" or .status=="capped" or .status=="escalation" or .status=="divergence" or .status=="blocked" then .status else null end),
    profile: (if .profile=="fast" or .profile=="standard" or .profile=="thorough" then .profile else null end),
    history: (.history | map(clean_entry))
  }
  ' "$INPUT_TMP" >> .claude/jev/shadow-log.jsonl 2>/dev/null || fail bad_input

echo "jev_recorded: true"
exit 0
