#!/bin/bash
set -euo pipefail

# Read input from stdin
input=$(cat)

# Extract project info
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

# Check for package.json (Node.js project)
if [ -f "$project_dir/package.json" ]; then
  # Check if tests exist and should run
  has_test=$(jq -r '.scripts.test // ""' "$project_dir/package.json")
  if [ -n "$has_test" ] && [ "$has_test" != "null" ]; then
    # Run tests
    cd "$project_dir"
    if ! npm test 2>&1; then
      echo '{"decision": "block", "reason": "Tests failed. Please fix failing tests before completing.", "systemMessage": "Verification failed: tests not passing"}' >&2
      exit 2
    fi
  fi

  # Check TypeScript compilation
  if [ -f "$project_dir/tsconfig.json" ]; then
    cd "$project_dir"
    if ! npx tsc --noEmit 2>&1; then
      echo '{"decision": "block", "reason": "TypeScript compilation errors. Please fix type errors.", "systemMessage": "Verification failed: type errors found"}' >&2
      exit 2
    fi
  fi
fi

# Check for Python project
if [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/setup.py" ]; then
  cd "$project_dir"

  # Run pytest if available
  if command -v pytest &> /dev/null; then
    if ! pytest --tb=short 2>&1; then
      echo '{"decision": "block", "reason": "Tests failed. Please fix failing tests.", "systemMessage": "Verification failed: pytest tests not passing"}' >&2
      exit 2
    fi
  fi

  # Run type checking if mypy is available
  if command -v mypy &> /dev/null && [ -f "$project_dir/mypy.ini" ]; then
    if ! mypy . 2>&1; then
      echo '{"decision": "block", "reason": "Type check errors. Please fix type errors.", "systemMessage": "Verification failed: mypy errors found"}' >&2
      exit 2
    fi
  fi
fi

# All checks passed
echo '{"decision": "approve", "reason": "Verification passed", "systemMessage": "All verification checks passed"}'
exit 0
