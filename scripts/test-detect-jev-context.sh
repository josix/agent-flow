#!/bin/bash
# test-detect-jev-context.sh — plain-bash tests for detect-jev-context.sh
# Style: test-ensure-gitignore.sh (FAILED counter, ✓/✗ echo, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$SCRIPT_DIR/detect-jev-context.sh"

FAILED=0
DUMMY_KEY="dummy-KEY-should-never-appear-123"

# Sandbox PATH holding only curl+jq stubs plus core utils needed by the shell itself.
make_stubbin() {
  local sb="$1"
  mkdir -p "$sb/stubbin"
  cat > "$sb/stubbin/curl" << 'EOF'
#!/bin/bash
exit 0
EOF
  cat > "$sb/stubbin/jq" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$sb/stubbin/curl" "$sb/stubbin/jq"
}

run_detect() {
  # Runs with a controlled PATH: sandbox stubbin first, then a minimal system PATH.
  env -i PATH="$1/stubbin:/usr/bin:/bin" "${@:2}" /bin/bash "$DETECT"
}

echo "Test D1: no opt-in"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(run_detect "$SANDBOX")
if echo "$OUT" | grep -q '^  available: false$' && echo "$OUT" | grep -q 'not enabled (set AGENT_FLOW_JEV=1)'; then
  echo "  ✓ available: false, not-enabled reason"
else
  echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D2: kill switch beats opt-in"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(run_detect "$SANDBOX" AGENT_FLOW_NO_JEV=1 AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY")
if echo "$OUT" | grep -q '^  available: false$' && echo "$OUT" | grep -q 'opt-out via AGENT_FLOW_NO_JEV'; then
  echo "  ✓ kill switch wins"
else
  echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D3: opt-in, no key"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(run_detect "$SANDBOX" AGENT_FLOW_JEV=1)
if echo "$OUT" | grep -q '^  api_key_present: false$' && echo "$OUT" | grep -q 'TYPESAFE_API_KEY'; then
  echo "  ✓ api_key_present: false, names TYPESAFE_API_KEY"
else
  echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D4: opt-in + key + curl/jq → available"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(run_detect "$SANDBOX" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY")
if echo "$OUT" | grep -q '^  available: true$' && ! echo "$OUT" | grep -q '^  reason:'; then
  echo "  ✓ available: true, no reason line"
else
  echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D5: jq missing"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"; rm -f "$SANDBOX/stubbin/jq"
OUT=$(run_detect "$SANDBOX" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY")
if echo "$OUT" | grep -q 'jq not found'; then
  echo "  ✓ jq not found"
else
  echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D6: custom key env name"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(run_detect "$SANDBOX" AGENT_FLOW_JEV=1 AGENT_FLOW_JEV_API_KEY_ENV=MY_JEV_KEY MY_JEV_KEY="$DUMMY_KEY")
if echo "$OUT" | grep -q '^  available: true$' && echo "$OUT" | grep -q '^  key_env: "MY_JEV_KEY"$'; then
  echo "  ✓ custom key_env honored"
else
  echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D7: invalid key env name, no code execution"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(cd "$SANDBOX" && run_detect "$SANDBOX" AGENT_FLOW_JEV=1 'AGENT_FLOW_JEV_API_KEY_ENV=BAD-NAME' 'BAD-NAME=$(touch x)')
if echo "$OUT" | grep -q '^  available: false$' && echo "$OUT" | grep -q 'invalid AGENT_FLOW_JEV_API_KEY_ENV' && [[ ! -f "$SANDBOX/x" ]]; then
  echo "  ✓ invalid key_env rejected, no command executed"
else
  echo "  ✗ unexpected: $OUT (x exists: $([[ -f "$SANDBOX/x" ]] && echo yes || echo no))"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D8: key value never printed"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(run_detect "$SANDBOX" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY")
ERR=$(env -i PATH="$SANDBOX/stubbin:/usr/bin:/bin" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY" /bin/bash "$DETECT" 2>&1 >/dev/null)
if ! echo "$OUT" | grep -q "$DUMMY_KEY" && ! echo "$ERR" | grep -q "$DUMMY_KEY"; then
  echo "  ✓ key absent from stdout and stderr"
else
  echo "  ✗ key leaked"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D9: output is valid YAML shape"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(run_detect "$SANDBOX" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY")
FIRST_KV=$(echo "$OUT" | sed -n '2p')
SHAPE_OK=true
[[ "$FIRST_KV" == "  available: true" ]] || SHAPE_OK=false
while IFS= read -r line; do
  [[ "$line" == "jev:" ]] && continue
  [[ "$line" =~ ^\ \ [a-z_]+:\  ]] || { SHAPE_OK=false; break; }
done <<< "$OUT"
YAML_OK=true
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "$OUT" | python3 -c 'import sys, yaml; yaml.safe_load(sys.stdin)' >/dev/null 2>&1 || YAML_OK=false
fi
if [[ "$SHAPE_OK" == true && "$YAML_OK" == true ]]; then
  echo "  ✓ line shape and YAML parse OK"
else
  echo "  ✗ shape_ok=$SHAPE_OK yaml_ok=$YAML_OK: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test D10: invalid model falls back to default"
SANDBOX=$(mktemp -d); make_stubbin "$SANDBOX"
OUT=$(run_detect "$SANDBOX" AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY" 'AGENT_FLOW_JEV_MODEL=x" y')
if echo "$OUT" | grep -q '^  model: "jev-1.13.0"$'; then
  echo "  ✓ invalid model falls back to jev-1.13.0"
else
  echo "  ✗ unexpected: $OUT"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

# ---------------------------------------------------------------------------
# init-orchestration.sh integration
# ---------------------------------------------------------------------------
echo "Test I1: init-orchestration.sh, no opt-in"
SANDBOX=$(mktemp -d)
git init -q -b main "$SANDBOX"
git -C "$SANDBOX" -c user.email=t@t -c user.name=t commit --allow-empty -m init -q
(cd "$SANDBOX" && env -i PATH="/usr/bin:/bin:/usr/local/bin" HOME="$HOME" AGENT_FLOW_NO_GITIGNORE=1 AGENT_FLOW_NO_CODEX=1 AGENT_FLOW_NO_AGENTSVIEW=1 bash "$SCRIPT_DIR/init-orchestration.sh" test task >/dev/null 2>&1)
OUT=$(grep -A1 '^jev:' "$SANDBOX/.claude/orchestration.local.md" || true)
LOG=$(grep '^- JEV signal:' "$SANDBOX/.claude/orchestration.local.md" || true)
if echo "$OUT" | grep -q 'available: false' && echo "$LOG" | grep -q 'Not enabled'; then
  echo "  ✓ jev block present, available: false, log line present"
else
  echo "  ✗ out=[$OUT] log=[$LOG]"; FAILED=$((FAILED+1))
fi
rm -rf "$SANDBOX"; echo

echo "Test I2: init-orchestration.sh, opt-in + key + stub curl/jq"
SANDBOX=$(mktemp -d)
git init -q -b main "$SANDBOX"
git -C "$SANDBOX" -c user.email=t@t -c user.name=t commit --allow-empty -m init -q
mkdir -p "$SANDBOX/stubbin"
cp "$(command -v curl)" "$SANDBOX/stubbin/curl" 2>/dev/null || ln -s "$(command -v curl)" "$SANDBOX/stubbin/curl"
cp "$(command -v jq)" "$SANDBOX/stubbin/jq" 2>/dev/null || ln -s "$(command -v jq)" "$SANDBOX/stubbin/jq"
(cd "$SANDBOX" && env -i PATH="$SANDBOX/stubbin:/usr/bin:/bin:/usr/local/bin" HOME="$HOME" AGENT_FLOW_NO_GITIGNORE=1 AGENT_FLOW_NO_CODEX=1 AGENT_FLOW_NO_AGENTSVIEW=1 AGENT_FLOW_JEV=1 TYPESAFE_API_KEY="$DUMMY_KEY" bash "$SCRIPT_DIR/init-orchestration.sh" test task >/dev/null 2>&1)
STATE="$SANDBOX/.claude/orchestration.local.md"
OUT=$(grep -A1 '^jev:' "$STATE" || true)
if echo "$OUT" | grep -q 'available: true' && ! grep -q "$DUMMY_KEY" "$STATE"; then
  echo "  ✓ available: true, dummy key absent from state file"
else
  echo "  ✗ out=[$OUT]"; FAILED=$((FAILED+1))
fi
echo

echo "Test I3: jev: block byte-identical across update-orchestration-state.sh"
extract_jev() { awk '/^jev:/{p=1} p{print; if (/^jev:/) n=0; else n++; if (n==4) exit}' "$1"; }
BEFORE=$(extract_jev "$STATE")
(cd "$SANDBOX" && env -i PATH="$SANDBOX/stubbin:/usr/bin:/bin:/usr/local/bin" HOME="$HOME" bash "$SCRIPT_DIR/update-orchestration-state.sh" --phase planning --set-intent-goal 'g "q" \x' >/dev/null 2>&1)
AFTER=$(extract_jev "$STATE")
if [[ "$BEFORE" == "$AFTER" ]]; then
  echo "  ✓ jev block unchanged by update-orchestration-state.sh"
else
  echo "  ✗ before=[$BEFORE] after=[$AFTER]"; FAILED=$((FAILED+1))
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
