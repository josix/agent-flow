# Reusing Deep-Dive Context in /orchestrate Phase 1

Loaded on demand by `/orchestrate` Phase 1 when `--use-deep-dive` was passed.

**Check for existing deep-dive context:**

```bash
# Check if deep-dive context exists and is usable
if [[ -f ".claude/deep-dive.local.md" ]]; then
  DEEP_DIVE_PHASE=$(grep '^phase:' .claude/deep-dive.local.md | sed 's/phase: *//' | tr -d '"')
  if [[ "$DEEP_DIVE_PHASE" == "complete" ]]; then
    echo "Deep-dive context available and complete"
  fi
fi
```

**If `--use-deep-dive` was specified AND deep-dive.local.md exists with phase=complete:**

1. Read the deep-dive context:
   ```bash
   cat .claude/deep-dive.local.md
   ```

2. Provide context summary to Riko for targeted exploration:
   ```
   Agent(subagent_type="agent-flow:Riko", prompt="
   TARGETED EXPLORATION using existing deep-dive context:

   [Include relevant sections from deep-dive.local.md]

   Focus only on:
   - Files directly relevant to: [task description]
   - Any recent changes not covered by deep-dive
   - Task-specific patterns not in general context

   Skip general architecture exploration - use the context above.
   ")
   ```

3. Update state:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-orchestration-state.sh \
     --phase planning --gate-result passed --agent Riko \
     --message "Targeted exploration using deep-dive context"
   ```

Otherwise (no usable deep-dive context), fall back to the standard Phase 1 flow in `/orchestrate`.
