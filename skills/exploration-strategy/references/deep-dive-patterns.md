# Deep-Dive Exploration Patterns

This reference defines exploration patterns for the `/deep-dive` command, where multiple Riko agents run in parallel to gather comprehensive codebase context.

## Overview

When participating in a `/deep-dive` command, you are one of several parallel agents exploring different aspects of the codebase. Each agent has a specific focus area assigned.

## Focus Area Definitions

### 1. PROJECT STRUCTURE

**Goal**: Map directory layout and file organization

**Exploration targets**:
- Top-level directories and their purposes
- Monorepo vs single package detection
- Entry points (main files, index files)
- Package boundaries and workspaces

**Search patterns**:
```
Glob: **/package.json, **/pyproject.toml, **/go.mod
Glob: **/index.ts, **/main.ts, **/main.py, **/main.go
Glob: **/src/*, **/lib/*, **/pkg/*
Read: Root README.md
```

**Output**: Directory structure overview with entry points

### 2. CONVENTIONS

**Goal**: Identify coding standards and patterns

**Exploration targets**:
- Config files (.eslintrc, .prettierrc, tsconfig.json, pyproject.toml)
- Style guides and .editorconfig
- Naming conventions from existing code
- Comment style and documentation patterns

**Search patterns**:
```
Glob: **/.eslintrc*, **/.prettierrc*, **/tsconfig.json
Glob: **/.editorconfig, **/CONTRIBUTING.md
Grep: "// eslint-disable" for rule patterns
Grep: "@param", "@returns" for JSDoc style
```

**Output**: Coding conventions list with sources

### 3. ANTI-PATTERNS

**Goal**: Find forbidden patterns and warnings

**Exploration targets**:
- Comments with 'DO NOT', 'NEVER', 'ALWAYS', 'DEPRECATED'
- Documented anti-patterns in README, CONTRIBUTING
- Lint rule comments indicating restrictions
- TODO/FIXME items indicating known issues

**Search patterns**:
```
Grep: "DO NOT|NEVER|ALWAYS|DEPRECATED"
Grep: "TODO|FIXME|HACK|XXX"
Grep: "eslint-disable.*no-"
Read: CONTRIBUTING.md, CODE_OF_CONDUCT.md
```

**Output**: Anti-patterns list with sources and reasons

### 4. BUILD AND CI

**Goal**: Understand build system and automation

**Exploration targets**:
- Package.json scripts, Makefile, build configs
- CI/CD configurations (.github/workflows)
- Test framework and test locations
- Release and deployment processes

**Search patterns**:
```
Glob: **/package.json -> read scripts section
Glob: **/Makefile, **/justfile
Glob: **/.github/workflows/*.yml
Glob: **/docker-compose.yml, **/Dockerfile
Read: CI workflow files
```

**Output**: Build commands and CI pipeline summary

### 5. ARCHITECTURE

**Goal**: Map key components and dependencies

**Exploration targets**:
- Core modules and their relationships
- Dependency injection, service patterns
- Data flow between components
- API boundaries and interfaces

**Search patterns**:
```
Grep: "export class|export interface|export type"
Grep: "import.*from"
Glob: **/services/*, **/providers/*, **/modules/*
Read: Architecture docs if present
```

**Output**: Architecture overview with component map (as table)

### 6. TESTING

**Goal**: Understand test structure and patterns

**Exploration targets**:
- Test directories and naming conventions
- Test framework identification (jest, pytest, etc.)
- Test utilities, fixtures, mocks
- Coverage configuration

**Search patterns**:
```
Glob: **/*.test.ts, **/*.spec.ts, **/test_*.py
Glob: **/jest.config.*, **/pytest.ini, **/conftest.py
Glob: **/__tests__/*, **/tests/*, **/test/*
Glob: **/__mocks__/*, **/fixtures/*
```

**Output**: Testing patterns and locations

## Output Format

Structure findings for synthesis:

```markdown
## [Focus Area] Findings

### Key Discoveries
- [Discovery 1 with file path]
- [Discovery 2 with file path]

### Evidence
- `path/to/file.ts:123` - [What was found]
- `path/to/config.json` - [Relevant configuration]

### Summary
[2-3 sentence synthesis of findings]
```

## Convergence Criteria

Your exploration is complete when:

1. **Coverage**: You have examined all relevant directories for your focus area
2. **Evidence**: Every claim has a file path or code snippet
3. **Actionable**: Findings can be directly used by downstream agents
4. **Concise**: No redundant information (other agents cover other areas)

## Parallel Agent Coordination

When running as part of deep-dive:

- **DO NOT** explore areas assigned to other agents
- **DO** focus deeply on your assigned aspect
- **DO** provide structured output for synthesis
- **DO NOT** wait for other agents (you run in parallel)
- **DO** report completion to orchestrator when done

Your findings will be merged with other agents' findings by Senku during the synthesis phase.

## Dynamic Scaling

For large codebases, additional focus areas may be assigned:

| Focus Area | When Assigned |
|------------|---------------|
| Large file analysis | >10 files over 500 lines |
| Cross-cutting concerns | >100 total files |
| Deep modules | Directory depth >= 4 |
| Per-package exploration | Monorepo detected |
| Per-language exploration | Multiple languages detected |

## Example Output

```markdown
## PROJECT STRUCTURE Findings

### Key Discoveries
- Monorepo with 3 packages (cli, core, web)
- TypeScript throughout, strict mode enabled
- Main entry: src/index.ts in each package

### Evidence
- `package.json` - workspaces: ["packages/*"]
- `packages/cli/src/index.ts:1` - Main CLI entry
- `packages/core/src/index.ts:1` - Core library exports
- `tsconfig.json:3` - "strict": true

### Summary
TypeScript monorepo using npm workspaces with three packages. Each package has its own entry point at src/index.ts. Strict TypeScript compilation is enforced project-wide.
```
