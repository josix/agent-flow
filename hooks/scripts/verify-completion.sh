#!/bin/bash
set -uo pipefail
# Note: -e removed to allow proper error handling

# Read input from stdin
input=$(cat)

# Extract project info
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")

# Check for bypass file - allows skipping verification for known issues
# Create .claude/skip-test-verification to bypass test checks
bypass_file="$project_dir/.claude/skip-test-verification"
if [ -f "$bypass_file" ]; then
  reason=$(cat "$bypass_file" 2>/dev/null | head -1 || echo "Bypass file present")
  echo "{\"decision\": \"approve\", \"reason\": \"Test verification bypassed: $reason\", \"systemMessage\": \"Test verification skipped due to bypass file\"}"
  exit 0
fi

# Check for known failures file - allows specific expected failures
# Format: one test name per line (e.g., tests/test_foo.py::TestClass::test_method)
known_failures_file="$project_dir/.claude/known-test-failures"

# Check for custom test command file
# Create .claude/test-command with the shell command to run tests
# Example: source .venv/bin/activate && PYTHONPATH=src pytest tests/
custom_test_cmd_file="$project_dir/.claude/test-command"

# Check for package.json (Node.js project)
if [ -f "$project_dir/package.json" ]; then
  # Check if tests exist and should run
  has_test=$(jq -r '.scripts.test // ""' "$project_dir/package.json" 2>/dev/null || echo "")
  if [ -n "$has_test" ] && [ "$has_test" != "null" ]; then
    # Run tests
    cd "$project_dir"
    if ! npm test 2>&1; then
      echo '{"decision": "block", "reason": "Tests failed. Please fix failing tests before completing.", "systemMessage": "Verification failed: tests not passing"}'
      exit 2
    fi
  fi

  # Check TypeScript compilation
  if [ -f "$project_dir/tsconfig.json" ]; then
    cd "$project_dir"
    if ! npx tsc --noEmit 2>&1; then
      echo '{"decision": "block", "reason": "TypeScript compilation errors. Please fix type errors.", "systemMessage": "Verification failed: type errors found"}'
      exit 2
    fi
  fi
fi

# Check for Python project
if [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/setup.py" ]; then
  cd "$project_dir"

  # Determine pytest command
  # Priority: custom test command > uv run pytest > global pytest
  pytest_cmd=""
  if [ -f "$custom_test_cmd_file" ]; then
    # Use custom test command from file (first non-comment line)
    pytest_cmd=$(grep -v '^#' "$custom_test_cmd_file" 2>/dev/null | grep -v '^$' | head -1 || true)
  elif command -v uv &> /dev/null && [ -f "$project_dir/uv.lock" ]; then
    pytest_cmd="uv run pytest"
  elif command -v pytest &> /dev/null && [ -d "$project_dir/tests" ]; then
    pytest_cmd="pytest"
  fi

  # Run pytest if available
  if [ -n "$pytest_cmd" ]; then
    # If known failures file exists, compare against it
    if [ -f "$known_failures_file" ]; then
      # Run pytest and capture output + exit code
      # For custom commands, run via bash -c; otherwise append flags directly
      if [ -f "$custom_test_cmd_file" ]; then
        test_output=$(bash -c "$pytest_cmd --tb=no -q" 2>&1)
      else
        test_output=$($pytest_cmd --tb=no -q 2>&1)
      fi
      pytest_exit_code=$?

      # Check for collection/import errors (these are fatal)
      if echo "$test_output" | grep -qE "(ImportError|ModuleNotFoundError|SyntaxError|ERROR collecting)"; then
        error_msg=$(echo "$test_output" | grep -E "(ImportError|ModuleNotFoundError|SyntaxError|ERROR)" | head -1)
        echo "{\"decision\": \"block\", \"reason\": \"Test collection failed: $error_msg\", \"systemMessage\": \"Verification failed: test import/collection error\"}"
        exit 2
      fi

      # Extract failed test names from output (handle empty case)
      actual_failures=$(echo "$test_output" | grep "^FAILED" | sed 's/^FAILED //' | sed 's/ -.*$//' | sort || true)
      known_failures=$(grep -v '^#' "$known_failures_file" 2>/dev/null | grep -v '^$' | sort || true)

      # If no actual failures and pytest succeeded, approve
      if [ -z "$actual_failures" ] && [ "$pytest_exit_code" -eq 0 ]; then
        echo '{"decision": "approve", "reason": "All tests passed", "systemMessage": "All tests passing"}'
        exit 0
      fi

      # If no actual failures but pytest failed, something else went wrong
      if [ -z "$actual_failures" ] && [ "$pytest_exit_code" -ne 0 ]; then
        echo '{"decision": "block", "reason": "Tests failed with unknown error", "systemMessage": "Verification failed: pytest returned non-zero exit code"}'
        exit 2
      fi

      # Find new failures (failures not in known list)
      # Use temporary files to avoid process substitution issues
      tmp_actual=$(mktemp)
      tmp_known=$(mktemp)
      echo "$actual_failures" > "$tmp_actual"
      echo "$known_failures" > "$tmp_known"
      new_failures=$(comm -23 "$tmp_actual" "$tmp_known" 2>/dev/null || cat "$tmp_actual")
      rm -f "$tmp_actual" "$tmp_known"

      # Trim whitespace
      new_failures=$(echo "$new_failures" | sed '/^$/d' | tr '\n' ' ')

      if [ -n "$new_failures" ]; then
        echo "{\"decision\": \"block\", \"reason\": \"New test failures detected: $new_failures\", \"systemMessage\": \"Verification failed: new pytest failures\"}"
        exit 2
      else
        # Only known failures - approve
        echo '{"decision": "approve", "reason": "Tests passed (known failures ignored)", "systemMessage": "All new tests passing, known failures ignored"}'
        exit 0
      fi
    else
      # No known failures file - require all tests to pass
      if ! $pytest_cmd --tb=short 2>&1; then
        echo '{"decision": "block", "reason": "Tests failed. Please fix failing tests.", "systemMessage": "Verification failed: pytest tests not passing"}'
        exit 2
      fi
    fi
  fi

  # Run type checking if mypy is available
  if command -v mypy &> /dev/null && [ -f "$project_dir/mypy.ini" ]; then
    if ! mypy . 2>&1; then
      echo '{"decision": "block", "reason": "Type check errors. Please fix type errors.", "systemMessage": "Verification failed: mypy errors found"}'
      exit 2
    fi
  fi
fi

# All checks passed
echo '{"decision": "approve", "reason": "Verification passed", "systemMessage": "All verification checks passed"}'
exit 0
