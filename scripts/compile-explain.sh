#!/usr/bin/env bash

# Agent Flow - Explain Compilation Script
# Assembles per-module briefs + fragments into explain-out/index.html
# v1: single-module assembly using sed sentinel injection

set -euo pipefail

TEMP_FILE=""
cleanup() {
  [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
  return 0
}
trap cleanup EXIT

EXPLAIN_OUT="explain-out"
BRIEFS_DIR=".claude/explain-briefs"
TEMPLATES_DIR="templates/explain"
REVISE_SLUG=""
LINT_STRICT=""
NO_LINT=""

print_usage() {
  cat << 'HELP_EOF'
Agent Flow - Explain Compilation (v1)

USAGE:
  compile-explain.sh [--revise <slug>] [--strict] [--no-lint] [-h|--help]

OPTIONS:
  --revise <slug>   Regenerate only the named module fragment
  --strict          Exit 1 if lint produces any warnings (not just forbidden)
  --no-lint         Skip lint step entirely
  -h, --help        Show this help and exit 0

DESCRIPTION:
  Assembles .claude/explain-briefs/*.fragment.html into explain-out/index.html
  using templates/explain/_base.html as the shell. Injects CSS and JS inline.
  Writes explain-out/status.json with per-module state.
  Runs explain-lint.py on fragments after Stage 3 (always; unless --no-lint).

EXAMPLES:
  bash scripts/compile-explain.sh
  bash scripts/compile-explain.sh --revise orchestration-pipeline
  bash scripts/compile-explain.sh --strict
  bash scripts/compile-explain.sh --no-lint

OUTPUT:
  explain-out/index.html        rendered course HTML
  explain-out/status.json       per-module feedback state
HELP_EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_usage
      exit 0
      ;;
    --revise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --revise requires a slug argument" >&2
        exit 1
      fi
      REVISE_SLUG="$2"
      shift 2
      ;;
    --strict)
      LINT_STRICT="--strict"
      shift
      ;;
    --no-lint)
      NO_LINT="--no-lint"
      shift
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

# Validate required directories and templates
if [[ ! -d "$BRIEFS_DIR" ]]; then
  echo "Error: $BRIEFS_DIR not found. Run /agent-flow:explain first." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATES_DIR/_base.html" ]]; then
  echo "Error: $TEMPLATES_DIR/_base.html not found." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATES_DIR/styles.css" ]]; then
  echo "Error: $TEMPLATES_DIR/styles.css not found." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATES_DIR/main.js" ]]; then
  echo "Error: $TEMPLATES_DIR/main.js not found." >&2
  exit 1
fi

# Ensure explain-out/ exists
mkdir -p "$EXPLAIN_OUT"

# Collect fragment files
if [[ -n "$REVISE_SLUG" ]]; then
  FRAGMENT="$BRIEFS_DIR/${REVISE_SLUG}.fragment.html"
  if [[ ! -f "$FRAGMENT" ]]; then
    echo "Error: fragment not found: $FRAGMENT" >&2
    exit 1
  fi
  FRAGMENT_FILES=("$FRAGMENT")
else
  shopt -s nullglob
  FRAGMENT_FILES=("$BRIEFS_DIR"/*.fragment.html)
  shopt -u nullglob
fi

if [[ ${#FRAGMENT_FILES[@]} -eq 0 ]]; then
  echo "Warning: no fragment files found in $BRIEFS_DIR" >&2
  echo "  Wrote empty course to $EXPLAIN_OUT/index.html"
fi

# Extract module title from the first brief found (fallback to "Explain")
MODULE_TITLE="Explain"
if [[ ${#FRAGMENT_FILES[@]} -gt 0 ]]; then
  FIRST_SLUG="$(basename "${FRAGMENT_FILES[0]}" .fragment.html)"
  BRIEF_FILE="$BRIEFS_DIR/${FIRST_SLUG}.md"
  if [[ -f "$BRIEF_FILE" ]]; then
    EXTRACTED=$(grep -m1 '^title:' "$BRIEF_FILE" | sed 's/^title:[[:space:]]*//' | tr -d '"' || true)
    [[ -n "$EXTRACTED" ]] && MODULE_TITLE="$EXTRACTED"
  fi
fi

MODULE_DATE="$(date '+%Y-%m-%d')"

# Build the combined fragment by concatenating all fragments
COMBINED_FRAGMENT_FILE="${EXPLAIN_OUT}/index.html.fragments.tmp.$$"
TEMP_FILE="$COMBINED_FRAGMENT_FILE"

if [[ ${#FRAGMENT_FILES[@]} -gt 0 ]]; then
  for frag in "${FRAGMENT_FILES[@]}"; do
    cat "$frag"
    echo ""
  done > "$COMBINED_FRAGMENT_FILE"
else
  echo "<p>No modules found. Run <code>/agent-flow:explain &lt;topic&gt;</code> first.</p>" > "$COMBINED_FRAGMENT_FILE"
fi

# Stage 1: inject styles into base template
STAGE1="${EXPLAIN_OUT}/index.html.stage1.tmp.$$"
sed -e "/\\/\\* __STYLES__ \\*\\//r ${TEMPLATES_DIR}/styles.css" \
    -e "/\\/\\* __STYLES__ \\*\\//d" \
    "$TEMPLATES_DIR/_base.html" > "$STAGE1"

# Stage 2: inject script
STAGE2="${EXPLAIN_OUT}/index.html.stage2.tmp.$$"
sed -e "/\\/\\* __SCRIPT__ \\*\\//r ${TEMPLATES_DIR}/main.js" \
    -e "/\\/\\* __SCRIPT__ \\*\\//d" \
    "$STAGE1" > "$STAGE2"
rm -f "$STAGE1"

# Stage 3: inject module fragment
STAGE3="${EXPLAIN_OUT}/index.html.stage3.tmp.$$"
TEMP_FILE="$STAGE3"
sed -e "/<!-- __MODULE_FRAGMENT__ -->/r ${COMBINED_FRAGMENT_FILE}" \
    -e "/<!-- __MODULE_FRAGMENT__ -->/d" \
    "$STAGE2" > "$STAGE3"
rm -f "$STAGE2"
rm -f "$COMBINED_FRAGMENT_FILE"
TEMP_FILE=""

# Lint: validate fragments against styles.css / main.js contract
if [[ ${#FRAGMENT_FILES[@]} -gt 0 ]]; then
  echo ""
  echo "compile-explain.sh: running explain-lint.py..."
  LINT_ARGS=()
  [[ -n "$LINT_STRICT" ]] && LINT_ARGS+=("$LINT_STRICT")
  [[ -n "$NO_LINT"     ]] && LINT_ARGS+=("$NO_LINT")
  python3 scripts/lib/explain-lint.py ${LINT_ARGS[@]+"${LINT_ARGS[@]}"} "${FRAGMENT_FILES[@]}"
  LINT_EXIT=$?
  if [[ $LINT_EXIT -ne 0 ]]; then
    echo "compile-explain.sh: lint failed (exit $LINT_EXIT) — see above for details" >&2
    exit "$LINT_EXIT"
  fi
fi

# Stage 4: substitute text placeholders using a Python one-liner (handles / in values safely)
FIRST_SLUG_SAFE="${FIRST_SLUG:-explain}"
# Requires python3 (already a prereq per README). Values passed via argv to avoid sed metachar issues.
python3 - "$STAGE3" "$MODULE_TITLE" "$MODULE_DATE" "$FIRST_SLUG_SAFE" "${EXPLAIN_OUT}/index.html" << 'PYEOF'
import sys

in_path, title, date_str, slug, out_path = sys.argv[1:]
with open(in_path) as f:
    content = f.read()
content = content.replace('__TITLE__', title)
content = content.replace('__DATE__', date_str)
content = content.replace('__SLUG__', slug)
with open(out_path, 'w') as f:
    f.write(content)
PYEOF
rm -f "$STAGE3"

# Write status.json
SLUG_LIST=""
for frag in "${FRAGMENT_FILES[@]}"; do
  slug="$(basename "$frag" .fragment.html)"
  SLUG_LIST="${SLUG_LIST}    {\"slug\": \"${slug}\", \"state\": \"pending\", \"notes\": \"\"},\n"
done
SLUG_LIST="${SLUG_LIST%,\\n}"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Write status.json directly via python
python3 << PYEOF3
import json, os, sys
from datetime import datetime, timezone

briefs_dir = "${BRIEFS_DIR}"
explain_out = "${EXPLAIN_OUT}"
ts = "${TIMESTAMP}"

modules = []
try:
    entries = sorted(os.listdir(briefs_dir))
except FileNotFoundError:
    entries = []

for entry in entries:
    if entry.endswith('.fragment.html'):
        slug = entry[:-len('.fragment.html')]
        modules.append({"slug": slug, "state": "pending", "notes": ""})

status = {"generated": ts, "modules": modules}
with open(os.path.join(explain_out, 'status.json'), 'w') as f:
    json.dump(status, f, indent=2)
PYEOF3

echo ""
echo "compile-explain.sh: assembly complete."
echo "  Output:  ${EXPLAIN_OUT}/index.html"
echo "  Modules: ${#FRAGMENT_FILES[@]}"
echo "  Status:  ${EXPLAIN_OUT}/status.json"
echo ""
echo "Open in browser: file://$(pwd)/${EXPLAIN_OUT}/index.html"

exit 0
