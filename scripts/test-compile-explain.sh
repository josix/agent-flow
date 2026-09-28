#!/bin/bash
# test-compile-explain.sh — plain-bash tests for compile-explain.sh and explain-lint.py
# Style: test-research-report.sh (FAILED counter, mktemp -d sandboxes, ✓/✗, exit non-zero on failure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILE_SCRIPT="$SCRIPT_DIR/compile-explain.sh"
LINT_SCRIPT="$SCRIPT_DIR/lib/explain-lint.py"

FAILED=0

write_valid_fragment() {
  # $1 = target path
  cat > "$1" << 'FRAGEOF'
<section class="module" id="demo">
  <div class="module__header">
    <h2 class="module__title">Demo</h2>
  </div>
  <section class="screen">
    <h3 class="screen__title">Screen 1</h3>
    <div class="screen__body">
      <p class="callout callout--insight">Demo insight, one screen.</p>
    </div>
  </section>
</section>
FRAGEOF
}

# ---------------------------------------------------------------------------
# Test 1: portability — no templates/ or scripts/ in the sandbox
# ---------------------------------------------------------------------------
echo "Test 1: portability (no templates/ or scripts/ in sandbox)"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  mkdir -p .claude/explain-briefs
  cat > .claude/explain-briefs/demo.md << 'BRIEFEOF'
---
title: Demo
lang: zh-TW
---
BRIEFEOF
  write_valid_fragment .claude/explain-briefs/demo.fragment.html

  if ! bash "$COMPILE_SCRIPT" > /tmp/compile-explain-t1.out 2>&1; then
    echo "  ✗ compile-explain.sh exited non-zero"
    cat /tmp/compile-explain-t1.out
    exit 1
  fi

  PASS=true
  [[ -f explain-out/index.html ]] || { echo "  ✗ explain-out/index.html not created"; PASS=false; }
  grep -qF '<html lang="zh-TW">' explain-out/index.html || { echo "  ✗ missing <html lang=\"zh-TW\">"; PASS=false; }
  grep -qF 'Demo insight, one screen.' explain-out/index.html || { echo "  ✗ fragment text not present"; PASS=false; }
  for tok in '__STYLES__' '__SCRIPT__' '__MODULE_FRAGMENT__' '__LANG__'; do
    grep -qF "$tok" explain-out/index.html && { echo "  ✗ leftover placeholder: $tok"; PASS=false; }
  done
  [[ -d templates ]] && { echo "  ✗ a templates/ directory was created in the sandbox"; PASS=false; }
  if [[ "$PASS" == true ]]; then
    echo "  ✓ compiles from a sandbox with no local templates/ or scripts/"
  else
    exit 1
  fi
  rm -f /tmp/compile-explain-t1.out
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 2: lang fallback — missing lang: gives en; malformed lang: falls back to en
# ---------------------------------------------------------------------------
echo "Test 2: lang fallback to en"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  mkdir -p .claude/explain-briefs
  cat > .claude/explain-briefs/demo.md << 'BRIEFEOF'
---
title: Demo
---
BRIEFEOF
  write_valid_fragment .claude/explain-briefs/demo.fragment.html
  bash "$COMPILE_SCRIPT" > /dev/null 2>&1
  grep -qF '<html lang="en">' explain-out/index.html || { echo "  ✗ missing lang: gave wrong lang"; exit 1; }
  echo "  ✓ missing lang: defaults to en"
) || ((FAILED++))
rm -rf "$SANDBOX"

SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  mkdir -p .claude/explain-briefs
  printf -- '---\ntitle: Demo\nlang: en"><x\n---\n' > .claude/explain-briefs/demo.md
  write_valid_fragment .claude/explain-briefs/demo.fragment.html
  bash "$COMPILE_SCRIPT" > /dev/null 2>&1
  grep -qF '<html lang="en">' explain-out/index.html || { echo "  ✗ malformed lang: did not fall back to en"; exit 1; }
  echo "  ✓ malformed lang: falls back to en"
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 3: forbidden class makes compile exit non-zero
# ---------------------------------------------------------------------------
echo "Test 3: forbidden class (chat-window) fails the compile"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  mkdir -p .claude/explain-briefs
  cat > .claude/explain-briefs/demo.md << 'BRIEFEOF'
---
title: Demo
lang: en
---
BRIEFEOF
  cat > .claude/explain-briefs/demo.fragment.html << 'FRAGEOF'
<section class="module" id="demo">
  <section class="screen">
    <h3 class="screen__title">Screen 1</h3>
    <div class="screen__body">
      <div class="chat-window">bad</div>
    </div>
  </section>
</section>
FRAGEOF
  if bash "$COMPILE_SCRIPT" > /dev/null 2>&1; then
    echo "  ✗ compile-explain.sh exited 0 with a forbidden class present"
    exit 1
  else
    echo "  ✓ compile-explain.sh exits non-zero on forbidden class"
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 4: explain-lint.py readability rules 9-11
# ---------------------------------------------------------------------------
echo "Test 4: lint rules 9-11 (no visual, long paragraph, unfilled placeholder)"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  LONG_PARA=$(python3 -c "print('x' * 700)")
  cat > bad.fragment.html << FRAGEOF
<section class="module" id="bad">
  <section class="screen">
    <h3 class="screen__title">Screen 1</h3>
    <div class="screen__body">
      <p>$LONG_PARA</p>
      <p>__MODULE_TLDR__</p>
    </div>
  </section>
</section>
FRAGEOF

  OUT=$(python3 "$LINT_SCRIPT" bad.fragment.html 2>&1)
  EXIT=$?
  PASS=true
  echo "$OUT" | grep -q 'has no visual element' || { echo "  ✗ rule 9 (no visual element) did not fire"; PASS=false; }
  echo "$OUT" | grep -q 'paragraph over 600 characters' || { echo "  ✗ rule 10 (long paragraph) did not fire"; PASS=false; }
  echo "$OUT" | grep -q 'unfilled placeholder __MODULE_TLDR__' || { echo "  ✗ rule 11 (unfilled placeholder) did not fire"; PASS=false; }
  if [[ "$EXIT" -ne 0 ]]; then
    echo "  ✗ lint exited $EXIT without --strict (warnings should not fail the build)"
    PASS=false
  fi
  if python3 "$LINT_SCRIPT" --strict bad.fragment.html > /dev/null 2>&1; then
    echo "  ✗ lint --strict exited 0 despite warnings"
    PASS=false
  fi
  if [[ "$PASS" == true ]]; then
    echo "  ✓ rules 9-11 fire as warnings; --strict promotes them to a failure"
  else
    exit 1
  fi
) || ((FAILED++))
rm -rf "$SANDBOX"
echo

# ---------------------------------------------------------------------------
# Test 5: the T1 fragment produces 0 warnings, 0 forbidden
# ---------------------------------------------------------------------------
echo "Test 5: valid fragment lints clean"
SANDBOX=$(mktemp -d)
(cd "$SANDBOX"
  write_valid_fragment demo.fragment.html
  OUT=$(python3 "$LINT_SCRIPT" demo.fragment.html 2>&1)
  if echo "$OUT" | grep -q 'lint: 0 warnings, 0 forbidden'; then
    echo "  ✓ valid fragment reports 0 warnings, 0 forbidden"
  else
    echo "  ✗ unexpected lint output:"
    echo "$OUT"
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
