# Deep-Dive Architecture Synthesis

This reference defines how Senku synthesizes findings from parallel Riko agents during the `/deep-dive` command.

## Overview

During deep-dive, multiple Riko agents explore different aspects of the codebase in parallel. Senku's role is to merge these findings into a coherent, actionable context document.

## Input Format

Each Riko agent returns findings in this structure:

```markdown
## [Focus Area] Findings

### Key Discoveries
- [Discovery 1 with file path]
- [Discovery 2 with file path]

### Evidence
- `path/to/file.ts:123` - [What was found]

### Summary
[2-3 sentence synthesis]
```

Focus areas include: PROJECT STRUCTURE, CONVENTIONS, ANTI-PATTERNS, BUILD AND CI, ARCHITECTURE, TESTING

## Synthesis Process

### Step 1: Collect and Validate

For each agent's findings:
1. Verify file paths are real (mentioned in evidence)
2. Check for conflicting information across agents
3. Note any gaps (areas not covered)

### Step 2: Resolve Conflicts

When agents report conflicting information:
- Prefer evidence with file paths over general claims
- Check if both claims are true in different contexts
- Note the conflict in Agent Notes if unresolvable

### Step 3: Merge by Section

Map agent findings to output sections:

| Agent Focus | Output Section |
|-------------|----------------|
| PROJECT STRUCTURE | Repository Overview (tech stack, entry points) |
| ARCHITECTURE | Architecture Map (component table) |
| CONVENTIONS | Conventions (naming, testing, error handling) |
| ANTI-PATTERNS | Anti-Patterns (DO NOT list) |
| BUILD AND CI | Repository Overview (build commands) |
| TESTING | Conventions (testing section) |

### Step 4: Generate Tables

**Architecture Map** - Create from ARCHITECTURE findings:
```markdown
| Component | Location | Purpose |
|-----------|----------|---------|
| API Server | src/api/ | REST endpoints |
| Auth Module | src/auth/ | JWT authentication |
```

**Key Files Quick Reference** - Synthesize from all findings:
```markdown
| Task | Look Here |
|------|-----------|
| Add API endpoint | src/api/routes/ |
| Add tests | src/__tests__/ |
| Configure build | package.json, tsconfig.json |
```

### Step 5: Prioritize Information

Order information by usefulness:
1. Tech stack and entry points (highest)
2. Key patterns and conventions
3. Anti-patterns and warnings
4. Build commands and CI
5. Agent notes and edge cases (lowest)

## Output Format

Generate content matching deep-dive.local.md structure:

```markdown
## Repository Overview
- **Tech Stack**: [languages, frameworks, key libraries]
- **Entry Points**: [main files with paths]
- **Key Patterns**: [dominant architectural patterns]

[Additional context paragraph if needed]

## Architecture Map
| Component | Location | Purpose |
|-----------|----------|---------|
| [Name] | [Path] | [One-line purpose] |

## Conventions
- **Naming**: [file naming, variable naming]
- **Testing**: [test location, naming, patterns]
- **Error handling**: [error patterns, logging]
- **Imports**: [import ordering, path aliases]

## Anti-Patterns (DO NOT)
- [Anti-pattern 1 with reason]
- [Anti-pattern 2 with reason]

## Key Files Quick Reference
| Task | Look Here |
|------|-----------|
| [Common task] | [Relevant files/dirs] |

## Agent Notes
[Any findings relevant for downstream agents that don't fit above]
[Conflicts or uncertainties]
[Gaps in coverage]
```

## Quality Criteria

Good synthesis:
- Every claim has a file path backing it
- No redundant information across sections
- Actionable for downstream agents
- Concise (aim for <200 lines total)
- Tables are populated, not "pending"

Bad synthesis:
- Generic advice that applies to all projects
- Information repeated in multiple sections
- Claims without file path evidence
- Verbose explanations instead of bullet points

## Example Synthesis

**Input from Riko agents:**

```
## PROJECT STRUCTURE Findings
### Key Discoveries
- TypeScript monorepo with npm workspaces
- 3 packages: cli, core, web
### Evidence
- `package.json:5` - workspaces: ["packages/*"]
- `packages/cli/src/index.ts:1` - CLI entry

## CONVENTIONS Findings
### Key Discoveries
- Strict TypeScript, no any
- Jest for testing, tests colocated
### Evidence
- `tsconfig.json:3` - "strict": true
- `jest.config.js:2` - testMatch: ["**/*.test.ts"]
```

**Synthesized output:**

```markdown
## Repository Overview
- **Tech Stack**: TypeScript, npm workspaces (monorepo)
- **Entry Points**: packages/cli/src/index.ts, packages/core/src/index.ts, packages/web/src/index.ts
- **Key Patterns**: Monorepo with 3 packages (cli, core, web)

## Conventions
- **TypeScript**: Strict mode, no `any` types
- **Testing**: Jest, tests colocated with source (*.test.ts)

## Key Files Quick Reference
| Task | Look Here |
|------|-----------|
| Add CLI command | packages/cli/src/ |
| Core library changes | packages/core/src/ |
| Configure TypeScript | tsconfig.json |
```

## Edge Cases

### Insufficient Coverage
If agents didn't cover an area, note it:
```markdown
## Agent Notes
- Testing patterns not fully explored (no test files found)
```

### Large Codebase
For very large codebases with many findings:
- Prioritize most-used components
- Group similar items
- Reference additional files rather than inlining everything

### Conflicting Information
```markdown
## Agent Notes
- Import style varies: some files use aliases (@/), others use relative paths
  - Prefer aliases per tsconfig.json paths configuration
```
