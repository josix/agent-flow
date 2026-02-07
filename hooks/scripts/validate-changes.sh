#!/bin/bash
set -euo pipefail

# Read input from stdin
input=$(cat)

# Extract tool information
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
tool_input=$(echo "$input" | jq -r '.tool_input // {}')
file_path=$(echo "$tool_input" | jq -r '.file_path // ""')

# Skip validation for non-file operations
if [ -z "$file_path" ]; then
  echo '{"continue": true, "systemMessage": "No file path to validate"}'
  exit 0
fi

# Deny path traversal attempts
if [[ "$file_path" == *".."* ]]; then
  echo '{"continue": false, "systemMessage": "Path traversal detected - blocking write operation"}'
  exit 2
fi

# Deny writes to sensitive files
sensitive_patterns=(
  "*.env"
  "*.env.*"
  "*credentials*"
  "*secret*"
  "*.pem"
  "*.key"
  "*id_rsa*"
  "*id_ed25519*"
)

for pattern in "${sensitive_patterns[@]}"; do
  # shellcheck disable=SC2053
  if [[ "$(basename "$file_path")" == $pattern ]]; then
    echo '{"continue": false, "systemMessage": "Cannot write to sensitive file: '"$file_path"'"}'
    exit 2
  fi
done

# Deny writes to system paths
system_paths=(
  "/etc/"
  "/usr/"
  "/bin/"
  "/sbin/"
  "/var/"
  "/root/"
)

for sys_path in "${system_paths[@]}"; do
  if [[ "$file_path" == "$sys_path"* ]]; then
    echo '{"continue": false, "systemMessage": "Cannot write to system path: '"$file_path"'"}'
    exit 2
  fi
done

# Validation passed
echo '{"continue": true, "systemMessage": "File write validated: '"$file_path"'"}'
exit 0
