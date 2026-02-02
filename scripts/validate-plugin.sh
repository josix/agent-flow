#!/bin/bash
# validate-plugin.sh - Validate plugin structure and components
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED_TESTS=0

echo "Agent Flow Plugin Validation"
echo "============================================"
echo

# Test 1: Plugin manifest
echo "Test 1: Plugin manifest validation"
if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
  if jq . "$PLUGIN_ROOT/.claude-plugin/plugin.json" > /dev/null 2>&1; then
    NAME=$(jq -r '.name' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
    if [ "$NAME" = "agent-flow" ]; then
      echo "  ✓ plugin.json valid with name: $NAME"
    else
      echo "  ✗ plugin.json has incorrect name: $NAME"
      ((FAILED_TESTS++))
    fi
  else
    echo "  ✗ plugin.json is invalid JSON"
    ((FAILED_TESTS++))
  fi
else
  echo "  ✗ plugin.json not found"
  ((FAILED_TESTS++))
fi
echo

# Test 2: Hooks configuration
echo "Test 2: Hooks configuration validation"
if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
  if jq . "$PLUGIN_ROOT/hooks/hooks.json" > /dev/null 2>&1; then
    HOOK_EVENTS=$(jq -r '.hooks | keys[]' "$PLUGIN_ROOT/hooks/hooks.json" 2>/dev/null)
    echo "  ✓ hooks.json valid with events: $HOOK_EVENTS" | tr '\n' ' '
    echo
  else
    echo "  ✗ hooks.json is invalid JSON"
    ((FAILED_TESTS++))
  fi
else
  echo "  ✗ hooks.json not found"
  ((FAILED_TESTS++))
fi
echo

# Test 3: Hook scripts
echo "Test 3: Hook script validation"
for script in "$PLUGIN_ROOT"/hooks/scripts/*.sh "$PLUGIN_ROOT"/scripts/*.sh; do
  if [ -f "$script" ]; then
    SCRIPT_NAME=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
      if [ -x "$script" ]; then
        echo "  ✓ $SCRIPT_NAME: valid syntax, executable"
      else
        echo "  ⚠ $SCRIPT_NAME: valid syntax, not executable"
      fi
    else
      echo "  ✗ $SCRIPT_NAME: syntax error"
      ((FAILED_TESTS++))
    fi
  fi
done
echo

# Test 4: Agent files
echo "Test 4: Agent file validation"
EXPECTED_AGENTS=("Senku" "Loid" "Riko" "Lawliet" "Alphonse")
for agent in "${EXPECTED_AGENTS[@]}"; do
  AGENT_FILE="$PLUGIN_ROOT/agents/$agent.md"
  if [ -f "$AGENT_FILE" ]; then
    # Check for YAML frontmatter
    if head -n 1 "$AGENT_FILE" | grep -q "^---"; then
      MARKERS=$(head -n 50 "$AGENT_FILE" | grep -c "^---")
      if [ "$MARKERS" -ge 2 ]; then
        echo "  ✓ $agent.md: valid frontmatter"
      else
        echo "  ✗ $agent.md: incomplete frontmatter"
        ((FAILED_TESTS++))
      fi
    else
      echo "  ✗ $agent.md: missing frontmatter"
      ((FAILED_TESTS++))
    fi
  else
    echo "  ✗ $agent.md: not found"
    ((FAILED_TESTS++))
  fi
done
echo

# Test 5: Skill files
echo "Test 5: Skill file validation"
EXPECTED_SKILLS=("task-classification" "verification-gates")
for skill in "${EXPECTED_SKILLS[@]}"; do
  SKILL_FILE="$PLUGIN_ROOT/skills/$skill/SKILL.md"
  if [ -f "$SKILL_FILE" ]; then
    if head -n 1 "$SKILL_FILE" | grep -q "^---"; then
      NAME=$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" | grep "^name:" | head -1)
      if [ -n "$NAME" ]; then
        echo "  ✓ $skill/SKILL.md: valid with $NAME"
      else
        echo "  ⚠ $skill/SKILL.md: missing name field"
      fi
    else
      echo "  ✗ $skill/SKILL.md: missing frontmatter"
      ((FAILED_TESTS++))
    fi
  else
    echo "  ✗ $skill/SKILL.md: not found"
    ((FAILED_TESTS++))
  fi
done
echo

# Test 6: Command files
echo "Test 6: Command file validation"
EXPECTED_COMMANDS=("orchestrate" "deep-dive")
for cmd in "${EXPECTED_COMMANDS[@]}"; do
  CMD_FILE="$PLUGIN_ROOT/commands/$cmd.md"
  if [ -f "$CMD_FILE" ]; then
    if head -n 1 "$CMD_FILE" | grep -q "^---"; then
      DESC=$(sed -n '/^---$/,/^---$/p' "$CMD_FILE" | grep "^description:" | head -1)
      if [ -n "$DESC" ]; then
        echo "  ✓ $cmd.md: valid with $DESC"
      else
        echo "  ⚠ $cmd.md: missing description"
      fi
    else
      echo "  ✗ $cmd.md: missing frontmatter"
      ((FAILED_TESTS++))
    fi
  else
    echo "  ✗ $cmd.md: not found"
    ((FAILED_TESTS++))
  fi
done
echo

# Test 7: Edge case - path traversal detection
echo "Test 7: Path traversal detection (validate-changes.sh)"
TEST_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "/tmp/../etc/passwd"}}'
RESULT=$(echo "$TEST_INPUT" | "$PLUGIN_ROOT/hooks/scripts/validate-changes.sh" 2>&1 || true)
if echo "$RESULT" | grep -q "Path traversal"; then
  echo "  ✓ Path traversal detected and blocked"
else
  echo "  ✗ Path traversal not detected"
  ((FAILED_TESTS++))
fi
echo

# Test 8: Edge case - sensitive file detection
echo "Test 8: Sensitive file detection (validate-changes.sh)"
TEST_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "/tmp/.env"}}'
RESULT=$(echo "$TEST_INPUT" | "$PLUGIN_ROOT/hooks/scripts/validate-changes.sh" 2>&1 || true)
if echo "$RESULT" | grep -q "Cannot write to sensitive file"; then
  echo "  ✓ Sensitive file write blocked"
else
  echo "  ✗ Sensitive file write not blocked"
  ((FAILED_TESTS++))
fi
echo

# Test 9: Edge case - system path detection
echo "Test 9: System path detection (validate-changes.sh)"
TEST_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "/etc/passwd"}}'
RESULT=$(echo "$TEST_INPUT" | "$PLUGIN_ROOT/hooks/scripts/validate-changes.sh" 2>&1 || true)
if echo "$RESULT" | grep -q "Cannot write to system path"; then
  echo "  ✓ System path write blocked"
else
  echo "  ✗ System path write not blocked"
  ((FAILED_TESTS++))
fi
echo

# Test 10: Happy path - valid file write
echo "Test 10: Valid file write (validate-changes.sh)"
TEST_INPUT='{"tool_name": "Write", "tool_input": {"file_path": "/tmp/valid-file.txt"}}'
RESULT=$(echo "$TEST_INPUT" | "$PLUGIN_ROOT/hooks/scripts/validate-changes.sh" 2>&1 || true)
if echo "$RESULT" | grep -q '"continue": true'; then
  echo "  ✓ Valid file write allowed"
else
  echo "  ✗ Valid file write incorrectly blocked"
  ((FAILED_TESTS++))
fi
echo

# Summary
echo "============================================"
echo "Validation complete"
if [ "$FAILED_TESTS" -eq 0 ]; then
  echo "✓ All tests passed"
  exit 0
else
  echo "✗ Failed tests: $FAILED_TESTS"
  exit 1
fi
