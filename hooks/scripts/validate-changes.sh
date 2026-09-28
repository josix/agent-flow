#!/bin/bash
set -euo pipefail

# PreToolUse guard for Write|Edit.
# Denies path traversal, sensitive files, and system paths using the
# PreToolUse permissionDecision contract ("deny" rejects only this tool call;
# the old `continue: false` halted the whole session). Silent on success so
# normal writes add no transcript noise.

# Fail open without jq — never break sessions over a missing dependency.
command -v jq &>/dev/null || exit 0

file_path=$(jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
[[ -z "$file_path" ]] && exit 0

deny() {
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}

# Path traversal: a ".." path segment, not any filename containing "..".
if [[ "/$file_path/" == *"/../"* ]]; then
  deny "Path traversal detected in $file_path — use a normalized path"
fi

base=$(basename "$file_path")
case "$base" in
  .env|.env.*|*.env|*.pem|*.key|id_rsa*|id_ed25519*|credentials|credentials.*|*.credentials|secrets.*|*.secret|*.secrets)
    deny "Refusing to write sensitive file: $file_path"
    ;;
esac

# macOS $TMPDIR lives under /var/folders — temp files are not system writes.
case "$file_path" in /var/folders/*|/var/tmp/*) exit 0 ;; esac
for sys_path in /etc/ /usr/ /bin/ /sbin/ /var/ /root/; do
  if [[ "$file_path" == "$sys_path"* ]]; then
    deny "Refusing to write system path: $file_path"
  fi
done

exit 0
