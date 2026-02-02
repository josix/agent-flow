---
name: deep-dive
description: Gather comprehensive codebase context using parallel exploration agents
argument-hint: [--full | --focus=<path> | --refresh]
---

# Deep-Dive Command

Gather comprehensive codebase context for the current session using parallel exploration agents.

## Arguments

- `--full` (default): Full codebase exploration
- `--focus=<path>`: Focus exploration on a specific path (e.g., `--focus=src/auth`)
- `--refresh`: Refresh existing deep-dive context

## State Initialization

**FIRST**: Initialize deep-dive state by running:

```bash
# Parse arguments
SCOPE="full"
FOCUS_PATH=""
REFRESH_FLAG=""

# Check for --focus=<path>
if [[ "$ARGUMENTS" == *"--focus="* ]]; then
  SCOPE="focused"
  FOCUS_PATH=$(echo "$ARGUMENTS" | sed -n 's/.*--focus=\([^ ]*\).*/\1/p')
fi

# Check for --refresh
if [[ "$ARGUMENTS" == *"--refresh"* ]]; then
  REFRESH_FLAG="--refresh"
fi

# Initialize deep-dive state
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-deep-dive.sh \
  --scope "$SCOPE" \
  ${FOCUS_PATH:+--focus-path "$FOCUS_PATH"} \
  $REFRESH_FLAG
```

This creates `.claude/deep-dive.local.md` to track exploration progress.

## Your Role

You are coordinating a parallel exploration workflow. Fire multiple Riko agents simultaneously to gather codebase context, then synthesize findings with Senku.

**CRITICAL BEHAVIORAL CONSTRAINTS:**
- Fire ALL exploration agents at once (parallel, not sequential)
- Do NOT wait for one agent before starting the next
- Each agent explores a DIFFERENT aspect of the codebase
- ALWAYS update state after each phase transition

## Workflow Phases

### Phase 1: Parallel Exploration (Fire Immediately)

**Fire ALL agents at once using Task tool.** Do not wait between spawns.

Each Riko agent explores a different aspect:

```
// Fire all these agents SIMULTANEOUSLY (5+ concurrent)

Task(agent="Riko", prompt="
PROJECT STRUCTURE: Explore directory layout and file organization.
- List top-level directories and their purposes
- Identify monorepo vs single package
- Find entry points (main files, index files)
- Report: directory structure overview
")

Task(agent="Riko", prompt="
CONVENTIONS: Find coding standards and patterns.
- Check config files (.eslintrc, .prettierrc, tsconfig.json, pyproject.toml)
- Look for .editorconfig, style guides
- Find naming conventions from existing code
- Report: coding conventions list
")

Task(agent="Riko", prompt="
ANTI-PATTERNS: Find forbidden patterns and warnings.
- Search for 'DO NOT', 'NEVER', 'ALWAYS', 'DEPRECATED', 'TODO', 'FIXME'
- Check for documented anti-patterns in README, CONTRIBUTING
- Look for lint rule comments indicating forbidden patterns
- Report: anti-patterns list with sources
")

Task(agent="Riko", prompt="
BUILD AND CI: Understand build system and automation.
- Find package.json scripts, Makefile, build configs
- Check .github/workflows, CI configurations
- Identify test framework and test locations
- Report: build commands and CI pipeline
")

Task(agent="Riko", prompt="
ARCHITECTURE: Map key components and dependencies.
- Identify core modules and their relationships
- Find dependency injection, service patterns
- Map data flow between components
- Report: architecture overview with component map
")

Task(agent="Riko", prompt="
TESTING: Understand test structure and patterns.
- Find test directories and naming conventions
- Identify test framework (jest, pytest, etc.)
- Look for test utilities, fixtures, mocks
- Report: testing patterns and locations
")
```

**Dynamic Agent Scaling**: Based on project size, spawn additional agents:

| Factor | Threshold | Additional Agents |
|--------|-----------|-------------------|
| Total files | >100 | +1 per 100 files |
| Directory depth | >= 4 | +2 for deep exploration |
| Monorepo | detected | +1 per package/workspace |
| Multiple languages | >1 | +1 per language |

Example additional agents for large projects:
```
Task(agent="Riko", prompt="Large file analysis: Find files >500 lines, report complexity hotspots")
Task(agent="Riko", prompt="Cross-cutting concerns: Find shared utilities across directories")
Task(agent="Riko", prompt="Deep modules: Explore nested directories at depth 4+")
```

### Phase 2: Synthesis

After collecting all agent results, **delegate to Senku** for synthesis:

```
Task(agent="Senku", prompt="
ARCHITECTURE SYNTHESIS: Merge parallel agent findings into coherent context.

Agent findings to synthesize:
[Insert collected findings from Phase 1]

Create unified output covering:
1. Repository Overview (tech stack, entry points, key patterns)
2. Architecture Map (components, locations, purposes as table)
3. Conventions (naming, testing, error handling)
4. Anti-Patterns (DO NOT list)
5. Key Files Quick Reference (task -> location mapping)
6. Agent Notes (anything relevant for downstream agents)

Output format should match deep-dive.local.md structure.
")
```

### Phase 3: Compile Output

After Senku completes synthesis, compile the final output:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-deep-dive.sh \
  --tech-stack "<from synthesis>" \
  --entry-points "<from synthesis>" \
  --key-patterns "<from synthesis>" \
  --overview "<from synthesis>" \
  --architecture "<from synthesis>" \
  --conventions "<from synthesis>" \
  --antipatterns "<from synthesis>" \
  --quick-reference "<from synthesis>" \
  --agent-notes "<from synthesis>" \
  --mark-complete
```

## Output Structure

The final `.claude/deep-dive.local.md` will contain:

```markdown
---
generated: {timestamp}
scope: full | focused
focus_path: null | "<path>"
expires_hint: "refresh when codebase significantly changes"
---

# Deep-Dive Context

## Repository Overview
- Tech stack: ...
- Entry points: ...
- Key patterns: ...

## Architecture Map
| Component | Location | Purpose |
|-----------|----------|---------|

## Conventions
- Naming: ...
- Testing: ...
- Error handling: ...

## Anti-Patterns (DO NOT)
- ...

## Key Files Quick Reference
| Task | Look Here |
|------|-----------|

## Agent Notes
Findings relevant for downstream agents...
```

## Integration with /orchestrate

After deep-dive completes, use with orchestrate:

```
/orchestrate --use-deep-dive Add user authentication
```

This injects the deep-dive context into Phase 1 (Exploration), allowing Riko to skip redundant exploration.

## Critical Rules

1. **PARALLEL EXECUTION** - Fire all exploration agents at once
2. **NO SEQUENTIAL WAITING** - Don't wait for one agent before starting the next
3. **DIFFERENT ASPECTS** - Each agent explores a different area
4. **SCALE DYNAMICALLY** - Add more agents for larger codebases
5. **SYNTHESIZE ONCE** - Senku merges all findings at the end
6. **UPDATE STATE** - Track phase progress in state file
7. **EPHEMERAL OUTPUT** - deep-dive.local.md is session-scoped

## State Monitoring

Check current deep-dive state:
```bash
head -30 .claude/deep-dive.local.md
```

Check phase:
```bash
grep '^phase:' .claude/deep-dive.local.md
```

## Example Session

```
User: /deep-dive --focus=src/api

[Initialize state]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-deep-dive.sh --scope focused --focus-path src/api

[Fire parallel agents - ALL AT ONCE]
Task(agent="Riko", prompt="PROJECT STRUCTURE for src/api: ...")
Task(agent="Riko", prompt="CONVENTIONS in src/api: ...")
Task(agent="Riko", prompt="ANTI-PATTERNS in src/api: ...")
Task(agent="Riko", prompt="API ENDPOINTS: Find all route definitions...")
Task(agent="Riko", prompt="DATA MODELS: Find schemas and types...")

[Collect results, then synthesize]
Task(agent="Senku", prompt="ARCHITECTURE SYNTHESIS: ...")

[Compile output]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-deep-dive.sh --tech-stack "..." --mark-complete

[Report]
Deep-dive complete. Context saved to .claude/deep-dive.local.md
Use: /orchestrate --use-deep-dive <task>
```

## Task

Begin deep-dive exploration for: $ARGUMENTS

Start by initializing state and firing parallel Riko agents.
