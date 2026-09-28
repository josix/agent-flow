#!/bin/bash
set -uo pipefail
# Note: -e removed to allow proper error handling
#
# Stop hook: run the project's tests/type checks before Claude finishes.
#
# Performance gates (this hook fires on EVERY Stop, including Q&A turns):
#   1. In a git repo with no uncommitted source changes -> exit immediately.
#   2. If the same change fingerprint already passed -> exit immediately.
# Output contract: silent on success; {"decision":"block",...} on failure.
# Tool output goes to stderr so stdout stays a single JSON object.

input=$(cat)

command -v jq &>/dev/null || exit 0

# Stop-hook retry guard (prevents infinite loops)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // "false"' 2>/dev/null || echo "false")
[ "$stop_hook_active" = "true" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

block() {
  # $1 = reason (shown to Claude), $2 = systemMessage (shown to user)
  jq -cn --arg reason "$1" --arg msg "$2" '{decision: "block", reason: $reason, systemMessage: $msg}'
  exit 0
}

# Bypass file - allows skipping verification for known issues
# Create .claude/skip-test-verification to bypass test checks
bypass_file="$project_dir/.claude/skip-test-verification"
if [ -f "$bypass_file" ]; then
  reason=$(head -n 1 "$bypass_file" 2>/dev/null || echo "Bypass file present")
  jq -cn --arg msg "Test verification bypassed: $reason" '{systemMessage: $msg}'
  exit 0
fi

cd "$project_dir" 2>/dev/null || block "verify-completion: cannot cd into project dir: $project_dir" "Verification failed: project directory inaccessible"

# ---------------------------------------------------------------------------
# Change gate + pass cache (git repos only; non-git dirs always verify)
# ---------------------------------------------------------------------------
cache_file="$project_dir/.claude/.verify-completion-pass"
fingerprint=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Docs and agent state never need a test run.
  pathspec=(-- . ':(exclude)*.md' ':(exclude)*.rst' ':(exclude)*.txt' ':(exclude)docs/**' ':(exclude).claude/**')
  if [ -z "$(git status --porcelain "${pathspec[@]}" 2>/dev/null)" ]; then
    exit 0
  fi
  fingerprint=$(
    {
      git rev-parse HEAD 2>/dev/null
      git diff HEAD "${pathspec[@]}" 2>/dev/null
      git ls-files -z --others --exclude-standard "${pathspec[@]}" 2>/dev/null | xargs -0 git hash-object -- 2>/dev/null
    } | git hash-object --stdin 2>/dev/null
  )
  if [ -n "$fingerprint" ] && [ -f "$cache_file" ] && [ "$(cat "$cache_file" 2>/dev/null)" = "$fingerprint" ]; then
    exit 0
  fi
fi

tail_of() { printf '%s' "$1" | tail -n 15; }

# Known failures: one test id per line (e.g., tests/test_foo.py::TestClass::test_method)
known_failures_file="$project_dir/.claude/known-test-failures"
# Custom test command: first non-comment line of .claude/test-command
custom_test_cmd_file="$project_dir/.claude/test-command"

# ---------------------------------------------------------------------------
# Node.js
# ---------------------------------------------------------------------------
if [ -f "$project_dir/package.json" ]; then
  has_test=$(jq -r '.scripts.test // ""' "$project_dir/package.json" 2>/dev/null || echo "")
  # npm init's placeholder always fails — treat it as "no tests".
  if [ -n "$has_test" ] && [ "$has_test" != "null" ] && [[ "$has_test" != *"no test specified"* ]]; then
    if ! out=$(npm test 2>&1); then
      echo "$out" >&2
      block "Tests failed. Please fix failing tests before completing. Last output:
$(tail_of "$out")" "Verification failed: tests not passing"
    fi
  fi

  # Only type-check with a project-local tsc: `npx --no-install` would fail
  # (and block the stop) when TypeScript isn't installed in node_modules.
  if [ -f "$project_dir/tsconfig.json" ] && [ -x "$project_dir/node_modules/.bin/tsc" ]; then
    if ! out=$(npx --no-install tsc --noEmit 2>&1); then
      echo "$out" >&2
      block "TypeScript compilation errors. Please fix type errors:
$(tail_of "$out")" "Verification failed: type errors found"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Python
# ---------------------------------------------------------------------------
if [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/setup.py" ]; then
  # Priority: custom test command > uv run pytest > global pytest
  pytest_cmd=""
  if [ -f "$custom_test_cmd_file" ]; then
    pytest_cmd=$(grep -v '^#' "$custom_test_cmd_file" 2>/dev/null | grep -v '^$' | head -1 || true)
  elif command -v uv &> /dev/null && [ -f "$project_dir/uv.lock" ]; then
    pytest_cmd="uv run pytest"
  elif command -v pytest &> /dev/null && [ -d "$project_dir/tests" ]; then
    pytest_cmd="pytest"
  fi

  if [ -n "$pytest_cmd" ]; then
    # TRUST BOUNDARY: $pytest_cmd from .claude/test-command is executed verbatim
    # with this hook's privileges. Anyone who can write .claude/ can run
    # arbitrary commands when the Stop hook fires. This is intentional (the file
    # is a local developer override) — do not feed it untrusted content.
    if [ -f "$known_failures_file" ]; then
      if [ -f "$custom_test_cmd_file" ]; then
        test_output=$(bash -c "$pytest_cmd --tb=no -q" 2>&1)
      else
        test_output=$($pytest_cmd --tb=no -q 2>&1)
      fi
      pytest_exit_code=$?

      # Collection/import errors are fatal
      if echo "$test_output" | grep -qE "(ImportError|ModuleNotFoundError|SyntaxError|ERROR collecting)"; then
        error_msg=$(echo "$test_output" | grep -E "(ImportError|ModuleNotFoundError|SyntaxError|ERROR)" | head -1)
        block "Test collection failed: $error_msg" "Verification failed: test import/collection error"
      fi

      actual_failures=$(echo "$test_output" | grep "^FAILED" | sed 's/^FAILED //' | sed 's/ -.*$//' | sort || true)
      known_failures=$(grep -v '^#' "$known_failures_file" 2>/dev/null | grep -v '^$' | sort || true)

      if [ -z "$actual_failures" ] && [ "$pytest_exit_code" -ne 0 ]; then
        block "Tests failed with unknown error:
$(tail_of "$test_output")" "Verification failed: pytest returned non-zero exit code"
      fi

      if [ -n "$actual_failures" ]; then
        new_failures=$(comm -23 <(echo "$actual_failures") <(echo "$known_failures") 2>/dev/null | sed '/^$/d' | tr '\n' ' ')
        if [ -n "$new_failures" ]; then
          block "New test failures detected: $new_failures" "Verification failed: new pytest failures"
        fi
      fi
    else
      if [ -f "$custom_test_cmd_file" ]; then
        out=$(bash -c "$pytest_cmd --tb=short" 2>&1)
      else
        out=$($pytest_cmd --tb=short 2>&1)
      fi
      # shellcheck disable=SC2181
      if [ $? -ne 0 ]; then
        echo "$out" >&2
        block "Tests failed. Please fix failing tests. Last output:
$(tail_of "$out")" "Verification failed: pytest tests not passing"
      fi
    fi
  fi

  if command -v mypy &> /dev/null && [ -f "$project_dir/mypy.ini" ]; then
    if ! out=$(mypy . 2>&1); then
      echo "$out" >&2
      block "Type check errors. Please fix type errors:
$(tail_of "$out")" "Verification failed: mypy errors found"
    fi
  fi
fi

# All checks passed — remember this fingerprint so the next Stop is free.
if [ -n "$fingerprint" ]; then
  mkdir -p "$(dirname "$cache_file")" 2>/dev/null && printf '%s' "$fingerprint" > "$cache_file" 2>/dev/null
fi
exit 0
