#!/bin/bash
# test-dispatch-jev-review.sh — plain-bash tests for dispatch-jev-review.sh
# Style: test-dispatch-codex-review.sh (FAILED counter, ✓/✗ echo, stub curl on PATH)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/dispatch-jev-review.sh"

FAILED=0
DUMMY_KEY='dummy-KEY-123'

setup_sandbox() {
  local sb="$1"
  git init -q -b main "$sb"
  printf 'state.md\nstubbin/\n.claude/\n*.bak\n' > "$sb/.gitignore"
  git -C "$sb" add .gitignore
  git -C "$sb" -c user.email=t@t -c user.name=t commit -m init -q
  git -C "$sb" update-ref refs/remotes/origin/main refs/heads/main
  git -C "$sb" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  mkdir -p "$sb/stubbin" "$sb/stubbin/responses" "$sb/.claude"
  cat > "$sb/state.md" << 'EOF'
---
started_at: "2026-01-01T00:00:00Z"
task: "t"
intent:
  goal: "Add a greeting"
  description: "d"
  actions: "ACTIONS_SENTINEL"
  constraints: "c"
  assumptions: "ASSUMPTIONS_SENTINEL"
jev:
  available: true
  api_key_present: true
  key_env: "TYPESAFE_API_KEY"
  model: "jev-1.13.0"
---
EOF
  # jq/curl are real system binaries; the stub replaces only curl.
  ln -s "$(command -v jq)" "$sb/stubbin/jq"
  printf 'small change\n' > "$sb/keep.txt"
  git -C "$sb" add keep.txt
}

install_curl_stub() {
  cat > "$1/stubbin/curl" << 'STUB_EOF'
#!/bin/bash
sb="$(dirname "$0")"
{ printf '%s ' "$@"; printf '\n'; } >> "$sb/argv.log"
cat > "$sb/config.txt"
out_file=""
i=1
args=("$@")
n=${#args[@]}
while [[ $i -le $n ]]; do
  a="${args[$((i-1))]}"
  case "$a" in
    --data-binary)
      i=$((i+1)); df="${args[$((i-1))]#@}"; cp "$df" "$sb/body.json" ;;
    -o)
      i=$((i+1)); out_file="${args[$((i-1))]}" ;;
  esac
  i=$((i+1))
done
n=$(( $(cat "$sb/calls.count" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$sb/calls.count"
resp="$sb/responses/$n"
status=200
body='{}'
if [[ -f "$resp" ]]; then
  status=$(sed -n '1p' "$resp")
  body=$(tail -n +2 "$resp")
fi
[[ -n "$out_file" ]] && printf '%s' "$body" > "$out_file"
printf '%s 0.05' "$status"
exit "${STUB_EXIT:-0}"
STUB_EOF
  chmod +x "$1/stubbin/curl"
}

# Ambient environments (including this dev machine) may export a real
# TYPESAFE_API_KEY for other tools. Every invocation below uses `env -i` so
# no test can ever inherit it or the real API endpoint — a second fence on
# top of the per-test AGENT_FLOW_JEV_BASE_URL=.invalid override.
run_dispatch() {
  # $1 sandbox; remaining args passed through as env KEY=VAL pairs before the command
  local sb="$1"; shift
  (
    cd "$sb" || exit 1
    env -i PATH="$sb/stubbin:/usr/bin:/bin:/usr/local/bin" HOME="$HOME" \
      AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY" AGENT_FLOW_JEV_BASE_URL="https://jev.invalid" \
      ${@+"$@"} bash "$DISPATCH" --state-file state.md 2>"$sb/stubbin/stderr.log"
  )
}

resp() { # sandbox status body -> responses/1
  printf '%s\n%s' "$2" "$3" > "$1/stubbin/responses/1"
}

score_body() {
  jq -nc --arg at "$1" --arg uc "$2" --arg nc "$3" --arg ss "$4" \
    '{model:"jev-1.13.0", answers:{addresses_task:{type:"noul",noul:($at|tonumber)}, unrelated_changes:{type:"noul",noul:($uc|tonumber)}, needs_clarification:{type:"noul",noul:($nc|tonumber)}, security_surface:{type:"noul",noul:($ss|tonumber)}}}'
}

echo "T1: success path, thresholding and shadow log"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 "$(score_body 0.9 0.95 0.85 0.1)"
OUT=$(run_dispatch "$SANDBOX")
OK=true
echo "$OUT" | grep -q '^jev_ran: true$' || OK=false
echo "$OUT" | grep -q '^jev_over_threshold: unrelated_changes,needs_clarification$' || OK=false
echo "$OUT" | grep -q '^jev_surfaced: unrelated_changes$' || OK=false
[[ -f "$SANDBOX/.claude/jev/shadow-log.jsonl" ]] || OK=false
LINES=$(wc -l < "$SANDBOX/.claude/jev/shadow-log.jsonl" | tr -d ' ')
[[ "$LINES" -eq 1 ]] || OK=false
jq -e '.kind=="score" and .started_at=="2026-01-01T00:00:00Z"' "$SANDBOX/.claude/jev/shadow-log.jsonl" >/dev/null 2>&1 || OK=false
if [[ "$OK" == true ]]; then echo "  ✓ scores, over_threshold, surfaced, shadow log all correct"; else echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1)); fi
rm -rf "$SANDBOX"; echo

echo "T2/T3: polarity and boundary at tau=0.8"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 "$(score_body 0.2 0.8 0.0 0.0)"
OUT=$(run_dispatch "$SANDBOX")
if echo "$OUT" | grep -q '^jev_over_threshold: addresses_task,unrelated_changes$'; then
  echo "  ✓ low-polarity 0.2 and high-polarity boundary 0.8 both flagged"
else
  echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "T4: HTTP status mapping"
for pair in "401:auth" "422:bad_request" "500:http_500"; do
  code="${pair%%:*}"; want="${pair##*:}"
  SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
  resp "$SANDBOX" "$code" '{}'
  OUT=$(run_dispatch "$SANDBOX")
  if echo "$OUT" | grep -q "^jev_skip_reason: $want\$"; then
    echo "  ✓ HTTP $code -> $want"
  else
    echo "  ✗ HTTP $code: $OUT"; FAILED=$((FAILED+1))
  fi
  rm -rf "$SANDBOX"
done
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
printf '400\n{"detail":{"error_type":"max_tokens_exceeded"}}' > "$SANDBOX/stubbin/responses/1"
OUT=$(run_dispatch "$SANDBOX")
if echo "$OUT" | grep -q '^jev_skip_reason: too_large$'; then echo "  ✓ HTTP 400 max_tokens_exceeded -> too_large"; else echo "  ✗ $OUT"; FAILED=$((FAILED+1)); fi
rm -rf "$SANDBOX"; echo

echo "T4b: 429 retries once then succeeds"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 429 '{}'
printf '200\n%s' "$(score_body 0.1 0.1 0.1 0.1)" > "$SANDBOX/stubbin/responses/2"
OUT=$(run_dispatch "$SANDBOX")
CALLS=$(cat "$SANDBOX/stubbin/calls.count" 2>/dev/null || echo 0)
if echo "$OUT" | grep -q '^jev_ran: true$' && [[ "$CALLS" -eq 2 ]]; then
  echo "  ✓ retried once after 429, scored on second attempt"
else
  echo "  ✗ calls=$CALLS out=$OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "T5: curl exit codes map to timeout/network"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
OUT=$(run_dispatch "$SANDBOX" STUB_EXIT=28)
if echo "$OUT" | grep -q '^jev_skip_reason: timeout$'; then echo "  ✓ curl exit 28 -> timeout"; else echo "  ✗ $OUT"; FAILED=$((FAILED+1)); fi
rm -rf "$SANDBOX"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
OUT=$(run_dispatch "$SANDBOX" STUB_EXIT=7)
if echo "$OUT" | grep -q '^jev_skip_reason: network$'; then echo "  ✓ curl exit 7 -> network"; else echo "  ✗ $OUT"; FAILED=$((FAILED+1)); fi
rm -rf "$SANDBOX"; echo

echo "T6: malformed / missing / out-of-range answers -> error"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
printf '200\nnot json' > "$SANDBOX/stubbin/responses/1"
OUT=$(run_dispatch "$SANDBOX")
[[ $(echo "$OUT" | grep -c '^jev_skip_reason: error$') -eq 1 ]] && A=ok || A=fail
rm -rf "$SANDBOX"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 '{"model":"jev-1.13.0","answers":{"addresses_task":{"type":"noul","noul":0.9}}}'
OUT=$(run_dispatch "$SANDBOX")
[[ $(echo "$OUT" | grep -c '^jev_skip_reason: error$') -eq 1 ]] && B=ok || B=fail
rm -rf "$SANDBOX"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 "$(score_body 1.5 0.1 0.1 0.1)"
OUT=$(run_dispatch "$SANDBOX")
[[ $(echo "$OUT" | grep -c '^jev_skip_reason: error$') -eq 1 ]] && C=ok || C=fail
if [[ "$A" == ok && "$B" == ok && "$C" == ok ]]; then
  echo "  ✓ malformed JSON, missing id, out-of-range noul all -> error"
else
  echo "  ✗ malformed=$A missing=$B range=$C"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "T7: pre-gate skips (no curl call, no .claude/jev/ dir)"
check_pregate() {
  local desc="$1" want="$2"; shift 2
  SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
  OUT=$(cd "$SANDBOX" && env -i PATH="$SANDBOX/stubbin:/usr/bin:/bin:/usr/local/bin" HOME="$HOME" AGENT_FLOW_JEV_BASE_URL="https://jev.invalid" "$@" bash "$DISPATCH" --state-file state.md 2>/dev/null)
  local ok=true
  echo "$OUT" | grep -q "^jev_skip_reason: $want\$" || ok=false
  [[ -f "$SANDBOX/stubbin/calls.count" ]] && ok=false
  [[ -d "$SANDBOX/.claude/jev" ]] && ok=false
  if [[ "$ok" == true ]]; then echo "  ✓ $desc"; else echo "  ✗ $desc: $OUT"; FAILED=$((FAILED+1)); fi
  rm -rf "$SANDBOX"
}
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; sed -i.bak 's/available: true/available: false/' "$SANDBOX/state.md"; rm -f "$SANDBOX/state.md.bak"
install_curl_stub "$SANDBOX"
OUT=$(cd "$SANDBOX" && env -i PATH="$SANDBOX/stubbin:/usr/bin:/bin:/usr/local/bin" HOME="$HOME" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY" AGENT_FLOW_JEV_BASE_URL="https://jev.invalid" bash "$DISPATCH" --state-file state.md 2>/dev/null)
echo "$OUT" | grep -q '^jev_skip_reason: unavailable$' && echo "  ✓ available: false -> unavailable" || { echo "  ✗ $OUT"; FAILED=$((FAILED+1)); }
rm -rf "$SANDBOX"
check_pregate "AGENT_FLOW_NO_JEV=1 -> disabled" disabled AGENT_FLOW_NO_JEV=1 AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY"
check_pregate "no AGENT_FLOW_JEV -> not_enabled" not_enabled TYPESAFE_API_KEY="$DUMMY_KEY"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
OUT=$(cd "$SANDBOX" && env -i PATH="$SANDBOX/stubbin:/usr/bin:/bin:/usr/local/bin" HOME="$HOME" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY" AGENT_FLOW_JEV_BASE_URL="https://jev.invalid" bash "$DISPATCH" --state-file state.md --mode plan 2>/dev/null)
echo "$OUT" | grep -q '^jev_skip_reason: bad_mode$' && echo "  ✓ --mode plan -> bad_mode" || { echo "  ✗ $OUT"; FAILED=$((FAILED+1)); }
rm -rf "$SANDBOX"
check_pregate "empty key -> no_key" no_key AGENT_FLOW_JEV=1
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
OUT=$(cd "$SANDBOX" && env -i PATH="$SANDBOX/stubbin:/usr/bin:/bin:/usr/local/bin" HOME="$HOME" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY='has"quote' AGENT_FLOW_JEV_BASE_URL="https://jev.invalid" bash "$DISPATCH" --state-file state.md 2>/dev/null)
echo "$OUT" | grep -q '^jev_skip_reason: bad_key$' && echo "  ✓ key with \" -> bad_key" || { echo "  ✗ $OUT"; FAILED=$((FAILED+1)); }
rm -rf "$SANDBOX"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
OUT=$(cd "$SANDBOX" && env -i PATH="$SANDBOX/stubbin:/usr/bin:/bin:/usr/local/bin" HOME="$HOME" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY" AGENT_FLOW_JEV_BASE_URL="http://example.com" bash "$DISPATCH" --state-file state.md 2>/dev/null)
echo "$OUT" | grep -q '^jev_skip_reason: bad_url$' && echo "  ✓ non-https base url -> bad_url" || { echo "  ✗ $OUT"; FAILED=$((FAILED+1)); }
rm -rf "$SANDBOX"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"
mkdir -p "$SANDBOX/stubbin2"; ln -s "$(command -v curl)" "$SANDBOX/stubbin2/curl"
OUT=$(cd "$SANDBOX" && env -i PATH="$SANDBOX/stubbin2:/usr/bin:/bin" HOME="$HOME" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY" AGENT_FLOW_JEV_BASE_URL="https://jev.invalid" bash "$DISPATCH" --state-file state.md 2>/dev/null)
echo "$OUT" | grep -q '^jev_skip_reason: missing_dep$' && echo "  ✓ no jq on PATH -> missing_dep" || { echo "  ✗ $OUT"; FAILED=$((FAILED+1)); }
rm -rf "$SANDBOX"
echo

echo "T8: secret pattern in diff text -> secret_suspected, no curl call"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
printf 'AKIA%s\n' 'ABCDEFGHIJKLMNOP' > "$SANDBOX/leak.txt"
OUT=$(run_dispatch "$SANDBOX")
if echo "$OUT" | grep -q '^jev_skip_reason: secret_suspected$' && [[ ! -f "$SANDBOX/stubbin/calls.count" ]]; then
  echo "  ✓ AKIA-pattern aborts before any network call"
else
  echo "  ✗ $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "T9: secret-like untracked path omitted from the request"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 "$(score_body 0.1 0.1 0.1 0.1)"
printf 'SENTINEL_TOKEN\n' > "$SANDBOX/id_rsa"
OUT=$(run_dispatch "$SANDBOX")
if ! grep -q 'SENTINEL_TOKEN' "$SANDBOX/stubbin/body.json" 2>/dev/null; then
  echo "  ✓ secret-like path content absent from request body"
else
  echo "  ✗ sentinel leaked into body.json"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "T10: oversized diff truncated"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 "$(score_body 0.1 0.1 0.1 0.1)"
head -c 5000 /dev/zero | tr '\0' 'a' > "$SANDBOX/big.txt"
git -C "$SANDBOX" add big.txt
OUT=$(run_dispatch "$SANDBOX" AGENT_FLOW_JEV_MAX_DIFF_CHARS=1000)
STATE_LEN=$(jq -r '.state' "$SANDBOX/stubbin/body.json" 2>/dev/null | wc -c | tr -d ' ')
if echo "$OUT" | grep -q '^jev_truncated: true$' && [[ "$STATE_LEN" -lt 2000 ]]; then
  echo "  ✓ diff truncated to the char cap"
else
  echo "  ✗ out=$OUT state_len=$STATE_LEN"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "T11: key hygiene (argv/stdout/stderr/body/log never hold the key; config carries it)"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 "$(score_body 0.1 0.1 0.1 0.1)"
OUT=$(run_dispatch "$SANDBOX")
OK=true
grep -q "$DUMMY_KEY" "$SANDBOX/stubbin/argv.log" 2>/dev/null && OK=false
echo "$OUT" | grep -q "$DUMMY_KEY" && OK=false
grep -q "$DUMMY_KEY" "$SANDBOX/stubbin/stderr.log" 2>/dev/null && OK=false
grep -q "$DUMMY_KEY" "$SANDBOX/stubbin/body.json" 2>/dev/null && OK=false
grep -q "$DUMMY_KEY" "$SANDBOX/.claude/jev/shadow-log.jsonl" 2>/dev/null && OK=false
grep -q "Authorization: Bearer $DUMMY_KEY" "$SANDBOX/stubbin/config.txt" 2>/dev/null || OK=false
if [[ "$OK" == true ]]; then echo "  ✓ key only reaches curl via the stdin config document"; else echo "  ✗ key hygiene violation"; FAILED=$((FAILED+1)); fi
rm -rf "$SANDBOX"; echo

echo "T13: request shape (model, question ids, goal/constraints present, actions/assumptions absent)"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 "$(score_body 0.1 0.1 0.1 0.1)"
run_dispatch "$SANDBOX" >/dev/null
BODY="$SANDBOX/stubbin/body.json"
OK=true
jq -e '.model=="jev-1.13.0"' "$BODY" >/dev/null 2>&1 || OK=false
jq -e '(.questions|keys|sort)==["addresses_task","needs_clarification","security_surface","unrelated_changes"]' "$BODY" >/dev/null 2>&1 || OK=false
jq -e '.questions.addresses_task.type=="noul" and (.questions.addresses_task.criteria.true|type=="string")' "$BODY" >/dev/null 2>&1 || OK=false
grep -q 'Goal:' "$BODY" || OK=false
grep -q 'Add a greeting' "$BODY" || OK=false
grep -q 'Description:' "$BODY" || OK=false
grep -q 'ACTIONS_SENTINEL' "$BODY" && OK=false
grep -q 'ASSUMPTIONS_SENTINEL' "$BODY" && OK=false
if [[ "$OK" == true ]]; then echo "  ✓ request shape correct, actions/assumptions never sent"; else echo "  ✗ request shape drift"; FAILED=$((FAILED+1)); fi
rm -rf "$SANDBOX"; echo

echo "T14: escaped goal unescapes correctly in state text"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; install_curl_stub "$SANDBOX"
resp "$SANDBOX" 200 "$(score_body 0.1 0.1 0.1 0.1)"
sed -i.bak 's/goal: "Add a greeting"/goal: "say \\"hi\\" \\\\ ok"/' "$SANDBOX/state.md"; rm -f "$SANDBOX/state.md.bak"
run_dispatch "$SANDBOX" >/dev/null
if jq -r '.state' "$SANDBOX/stubbin/body.json" | grep -qF 'say "hi" \ ok'; then
  echo "  ✓ escaped goal unescaped in state text"
else
  echo "  ✗ $(cat "$SANDBOX/stubbin/body.json" 2>/dev/null)"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "T15: clean tree with no diff -> no_diff, no curl call"
SANDBOX=$(mktemp -d)
git init -q -b main "$SANDBOX"
printf 'state.md\nstubbin/\n.claude/\n*.bak\n' > "$SANDBOX/.gitignore"
git -C "$SANDBOX" add .gitignore
git -C "$SANDBOX" -c user.email=t@t -c user.name=t commit -m init -q
git -C "$SANDBOX" update-ref refs/remotes/origin/main refs/heads/main
git -C "$SANDBOX" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
mkdir -p "$SANDBOX/stubbin"
ln -s "$(command -v jq)" "$SANDBOX/stubbin/jq"
cat > "$SANDBOX/state.md" << 'EOF'
---
started_at: "2026-01-01T00:00:00Z"
task: "t"
intent:
  goal: "g"
  description: "d"
  constraints: "c"
jev:
  available: true
  api_key_present: true
  key_env: "TYPESAFE_API_KEY"
  model: "jev-1.13.0"
---
EOF
install_curl_stub "$SANDBOX"
OUT=$(run_dispatch "$SANDBOX")
if echo "$OUT" | grep -q '^jev_skip_reason: no_diff$' && [[ ! -f "$SANDBOX/stubbin/calls.count" ]]; then
  echo "  ✓ clean tree -> no_diff, no curl call"
else
  echo "  ✗ $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

# ---------------------------------------------------------------------------
# record-jev-shadow.sh
# ---------------------------------------------------------------------------
RECORD="$SCRIPT_DIR/record-jev-shadow.sh"

echo "R1: unavailable -> no file"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"; sed -i.bak 's/available: true/available: false/' "$SANDBOX/state.md"; rm -f "$SANDBOX/state.md.bak"
OUT=$(cd "$SANDBOX" && echo '{"status":"complete","profile":"standard","history":[]}' | bash "$RECORD" --state-file state.md)
if echo "$OUT" | grep -q '^jev_recorded: false$' && [[ ! -f "$SANDBOX/.claude/jev/shadow-log.jsonl" ]]; then
  echo "  ✓ unavailable -> no file written"
else
  echo "  ✗ $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "R2: valid input -> one outcome line, free text stripped"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"
INPUT=$(jq -nc '{status:"complete", profile:"standard", history:[{round:0, lawliet:"APPROVED", codex:"APPROVEDxxxxxxxxxxxxxxxxxxxx", alphonse:"VERIFIED", open:0, errors:0, intent_mismatch:false, jev:{scores:{addresses_task:0.9}, over:["addresses_task"], surfaced:["addresses_task"], truncated:false}, summary:"SECRET_TEXT"}]}')
OUT=$(cd "$SANDBOX" && echo "$INPUT" | bash "$RECORD" --state-file state.md)
LOG="$SANDBOX/.claude/jev/shadow-log.jsonl"
OK=true
echo "$OUT" | grep -q '^jev_recorded: true$' || OK=false
[[ $(wc -l < "$LOG" | tr -d ' ') -eq 1 ]] || OK=false
grep -q 'SECRET_TEXT' "$LOG" && OK=false
jq -e '.history[0].codex=="APPROVEDxxxxxxxxxxxx"' "$LOG" >/dev/null 2>&1 || OK=false
jq -e '.history[0]|has("summary")|not' "$LOG" >/dev/null 2>&1 || OK=false
if [[ "$OK" == true ]]; then echo "  ✓ one outcome line written, free text fields absent"; else echo "  ✗ $(cat "$LOG" 2>/dev/null)"; FAILED=$((FAILED+1)); fi
rm -rf "$SANDBOX"; echo

echo "R3: invalid JSON -> bad_input, no line"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"
OUT=$(cd "$SANDBOX" && echo 'not json' | bash "$RECORD" --state-file state.md)
if echo "$OUT" | grep -q '^jev_recorded: false$' && echo "$OUT" | grep -q '^jev_skip_reason: bad_input$' && [[ ! -f "$SANDBOX/.claude/jev/shadow-log.jsonl" ]]; then
  echo "  ✓ invalid JSON -> bad_input, no line, exit 0"
else
  echo "  ✗ $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "R4: lawliet:free text and injected jev string are rejected to null"
SANDBOX=$(mktemp -d); setup_sandbox "$SANDBOX"
INPUT=$(jq -nc '{status:"complete", profile:"standard", history:[{round:0, lawliet:"free text", alphonse:"VERIFIED", jev:"off"}]}')
OUT=$(cd "$SANDBOX" && echo "$INPUT" | bash "$RECORD" --state-file state.md)
LOG="$SANDBOX/.claude/jev/shadow-log.jsonl"
if jq -e '.history[0].lawliet==null and .history[0].jev=="off"' "$LOG" >/dev/null 2>&1; then
  echo "  ✓ free-text lawliet rejected, known-shape jev string passed through"
else
  echo "  ✗ $(cat "$LOG" 2>/dev/null)"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "============================================"
if [[ "$FAILED" -eq 0 ]]; then
  echo "✓ All tests passed"
  exit 0
else
  echo "✗ Failed tests: $FAILED"
  exit 1
fi
