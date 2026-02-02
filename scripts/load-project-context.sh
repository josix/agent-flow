#!/bin/bash
set -euo pipefail

# Read input from stdin (contains session info)
input=$(cat)

# Extract project directory
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Detect project type and set environment variables
detect_project_type() {
  local dir="$1"

  if [ -f "$dir/package.json" ]; then
    echo "nodejs"
  elif [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ]; then
    echo "python"
  elif [ -f "$dir/Cargo.toml" ]; then
    echo "rust"
  elif [ -f "$dir/go.mod" ]; then
    echo "go"
  elif [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ]; then
    echo "java"
  else
    echo "unknown"
  fi
}

# Detect test framework
detect_test_framework() {
  local dir="$1"
  local project_type="$2"

  case "$project_type" in
    nodejs)
      if [ -f "$dir/jest.config.js" ] || [ -f "$dir/jest.config.ts" ]; then
        echo "jest"
      elif [ -f "$dir/vitest.config.js" ] || [ -f "$dir/vitest.config.ts" ]; then
        echo "vitest"
      elif [ -f "$dir/mocha.json" ] || [ -f "$dir/.mocharc.json" ]; then
        echo "mocha"
      else
        echo "npm-test"
      fi
      ;;
    python)
      if [ -f "$dir/pytest.ini" ] || [ -f "$dir/pyproject.toml" ]; then
        echo "pytest"
      else
        echo "unittest"
      fi
      ;;
    rust)
      echo "cargo-test"
      ;;
    go)
      echo "go-test"
      ;;
    java)
      echo "junit"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Get project type
PROJECT_TYPE=$(detect_project_type "$project_dir")
TEST_FRAMEWORK=$(detect_test_framework "$project_dir" "$PROJECT_TYPE")

# Check for TypeScript
HAS_TYPESCRIPT="false"
if [ -f "$project_dir/tsconfig.json" ]; then
  HAS_TYPESCRIPT="true"
fi

# Check for linting configuration
HAS_ESLINT="false"
HAS_RUFF="false"
if [ -f "$project_dir/.eslintrc.js" ] || [ -f "$project_dir/.eslintrc.json" ] || [ -f "$project_dir/eslint.config.js" ]; then
  HAS_ESLINT="true"
fi
if [ -f "$project_dir/ruff.toml" ] || [ -f "$project_dir/pyproject.toml" ]; then
  HAS_RUFF="true"
fi

# Persist environment variables for the session
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PROJECT_TYPE=$PROJECT_TYPE"
    echo "export TEST_FRAMEWORK=$TEST_FRAMEWORK"
    echo "export HAS_TYPESCRIPT=$HAS_TYPESCRIPT"
    echo "export HAS_ESLINT=$HAS_ESLINT"
    echo "export HAS_RUFF=$HAS_RUFF"
  } >> "$CLAUDE_ENV_FILE"
fi

# Output context information
cat << EOF
{
  "systemMessage": "Project context loaded: $PROJECT_TYPE project with $TEST_FRAMEWORK testing framework. TypeScript: $HAS_TYPESCRIPT, ESLint: $HAS_ESLINT, Ruff: $HAS_RUFF"
}
EOF

exit 0
