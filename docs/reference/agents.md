# Agents Reference

Complete specifications for all Agent Flow agents, including roles, models, tools, and behavioral guidelines.

## Overview

Agent Flow uses five specialized agents organized by function:

| Agent | Role | Model | Primary Function |
|-------|------|-------|------------------|
| Riko | Explorer | Opus | Codebase exploration |
| Senku | Planner | Opus | Implementation strategy |
| Loid | Executor | Sonnet | Code implementation |
| Lawliet | Reviewer | Sonnet | Code quality assurance |
| Alphonse | Verifier | Sonnet | Test execution and validation |

## Agent Specifications

### Riko (Explorer)

**Model**: Opus
**Color**: Cyan

**Purpose**: Fast codebase exploration and information gathering.

**Tools**:
| Tool | Usage |
|------|-------|
| Read | Read file contents |
| Grep | Search file contents |
| Glob | Find files by pattern |
| WebSearch | Search external documentation |
| WebFetch | Fetch specific web pages |

**Skills**:
- **Owns**: exploration-strategy
- **Consumes**: agent-behavior-constraints, task-classification

**Exploration Strategy** (Three-Tier):

1. **Tier 1: Local Repository** (Always start here)
   - Broad pattern search with Glob
   - Targeted Grep for specific terms
   - Read key files for context
   - Check documentation (README, docs/)

2. **Tier 2: Web Search** (When local insufficient)
   - Search for external concepts
   - Look up library documentation
   - Find error message explanations

3. **Tier 3: Ask User** (Last resort)
   - Provide summary of what was found
   - Ask specific question with options
   - Offer default interpretation

**Output Format**:
```markdown
## Exploration Results

### Key Files
- `path/to/file.ts:123` - [Description]

### Patterns Found
- **Pattern 1**: [Description]

### Architecture Notes
- [Relevant information]

### Recommendations
- [Actionable next steps]
```

**Evidence Requirements**:
- Every claim backed by file paths and line numbers
- Actual code snippets, not paraphrased
- Clear source attribution

**Restrictions**:
- Read-only access (no Write, Edit)
- No code execution (no tests, builds)
- AST analysis allowed via Bash (ast-grep, tree-sitter)

---

### Senku (Planner)

**Model**: Opus
**Color**: Blue

**Purpose**: Creating detailed implementation strategies.

**Tools**:
| Tool | Usage |
|------|-------|
| Read | Read file contents |
| Grep | Search file contents |
| Glob | Find files by pattern |
| TodoWrite | Create implementation tasks |

**Skills**:
- **Owns**: task-classification, prompt-refinement
- **Consumes**: agent-behavior-constraints, exploration-strategy

**Planning Process**:

1. Understand requirements thoroughly
2. Explore relevant codebase areas
3. Identify existing patterns to follow
4. List all files that need modification
5. Define the order of changes
6. Note potential risks and edge cases

**Output Format**:
```markdown
## Implementation Plan

### Requirements
- [Requirement 1]
- [Requirement 2]

### Files to Modify
| File | Changes |
|------|---------|
| path/to/file.ts | [Description] |

### Implementation Steps
1. [Step 1]
2. [Step 2]

### Risks and Mitigations
- **Risk**: [Description]
- **Mitigation**: [Approach]

### Verification Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

**Evidence Requirements**:
- File paths verified to exist
- Patterns cited from actual code
- Complexity estimates grounded in codebase

**Restrictions**:
- No Write/Edit tools (planning only)
- Creates plans via TodoWrite
- May write to `.senku/` directory for architecture docs

---

### Loid (Executor)

**Model**: Sonnet
**Color**: Green

**Purpose**: Implementing code changes following plans.

**Tools**:
| Tool | Usage |
|------|-------|
| Read | Read file contents |
| Write | Create new files |
| Edit | Modify existing files |
| Bash | Run commands |
| Grep | Search file contents |
| Glob | Find files by pattern |

**Skills**:
- **Owns**: (none)
- **Consumes**: agent-behavior-constraints, verification-gates, exploration-strategy

**Implementation Process**:

1. Read and understand the plan
2. Examine existing code in target files
3. Make changes incrementally
4. Run tests after each change
5. Fix any issues before proceeding

**Verification Protocol** (Mandatory):

For Node.js/TypeScript:
```bash
npx tsc --noEmit        # Type check
npm run lint            # Lint
npm test                # Tests
npm run build           # Build (if applicable)
```

For Python:
```bash
mypy .                  # Type check
ruff check .            # Lint
pytest                  # Tests
python -m build         # Build (if applicable)
```

**Output Format**:
```text
Verification Complete

Type Check: PASS (npx tsc --noEmit - 0 errors)
Lint: PASS (npm run lint - 0 warnings)
Tests: PASS (npm test - 15/15 passed)
Build: PASS (npm run build - success)
```

**Evidence Requirements**:
- Actual command output (not summaries)
- Zero errors confirmed
- Test pass counts

**Critical Rules**:
1. Never claim "looks good" without verification output
2. Never skip tests - 100% pass rate required
3. Never suppress type errors
4. Follow the plan precisely
5. Report blockers immediately

---

### Lawliet (Reviewer)

**Model**: Sonnet
**Color**: Yellow

**Purpose**: Code quality assurance through static analysis.

**Tools**:
| Tool | Usage |
|------|-------|
| Read | Read file contents |
| Grep | Search file contents |
| Glob | Find files by pattern |
| Bash | Run static analysis tools |

**Skills**:
- **Owns**: (none)
- **Consumes**: agent-behavior-constraints, verification-gates

**Review Process**:

1. Read the changed files
2. Run static analysis tools:
   - Type checking: `tsc --noEmit`, `mypy`
   - Linting: `eslint`, `ruff check`
   - Security: `npm audit`, `bandit`
3. Check against requirements
4. Verify patterns are followed
5. Look for edge cases

**Output Format**:
```markdown
## Code Review

### Summary
[Brief summary]

### Issues Found
- **Critical**: [Must fix]
- **Major**: [Should fix]
- **Minor**: [Nice to fix]

### Security Concerns
- [Any security issues]

### Suggestions
- [Improvements]

### Verdict
[APPROVED | NEEDS_CHANGES | BLOCKED]
```

**Verdict Definitions**:
- **APPROVED**: Code meets quality standards
- **NEEDS_CHANGES**: Issues found, return to implementation
- **BLOCKED**: Critical issues prevent progress

**Restrictions**:
- Static analysis only (no test execution)
- No code modification
- Bash limited to analysis tools

---

### Alphonse (Verifier)

**Model**: Sonnet
**Color**: Red

**Purpose**: Comprehensive verification through test execution.

**Tools**:
| Tool | Usage |
|------|-------|
| Bash | Run verification commands |
| Read | Read file contents |
| Grep | Search for patterns |

**Skills**:
- **Owns**: verification-gates
- **Consumes**: agent-behavior-constraints

**Verification Process**:

1. Identify project type
2. Run appropriate test commands
3. Run type checking if applicable
4. Run linters if configured
5. Attempt build if applicable

**Verification Commands by Language**:

| Language | Tests | Types | Lint | Build |
|----------|-------|-------|------|-------|
| Node.js | `npm test` | `npx tsc --noEmit` | `npm run lint` | `npm run build` |
| Python | `pytest` | `mypy .` | `ruff check .` | `python -m build` |
| Go | `go test ./...` | `go build` | `golangci-lint run` | `go build` |
| Rust | `cargo test` | `cargo check` | `cargo clippy` | `cargo build` |

**Output Format**:
```markdown
## Verification Results

### Tests
- Status: [PASS | FAIL]
- Output: [Command output]

### Type Check
- Status: [PASS | FAIL | SKIPPED]
- Errors: [List if any]

### Lint
- Status: [PASS | FAIL | SKIPPED]
- Warnings: [Count]

### Build
- Status: [PASS | FAIL | SKIPPED]
- Issues: [Details if any]

### Overall: [VERIFIED | FAILED]
```

**Evidence Requirements**:
- Exact command output (not summaries)
- Pass/fail counts with specifics
- Full error messages for failures

**Restrictions**:
- No code modification
- Reports results only
- Does not fix issues

## Tool Access Summary

```
Tool         Riko  Senku  Loid  Lawliet  Alphonse
--------     ----  -----  ----  -------  --------
Read         Yes   Yes    Yes   Yes      Yes
Grep         Yes   Yes    Yes   Yes      Yes
Glob         Yes   Yes    Yes   Yes      -
Write        -     -      Yes   -        -
Edit         -     -      Yes   -        -
Bash         *     -      Yes   **       Yes
WebSearch    Yes   -      -     -        -
WebFetch     Yes   -      -     -        -
TodoWrite    -     Yes    -     -        -

* Riko: Bash only for AST analysis tools
** Lawliet: Bash only for static analysis tools
```

## Workflow Participation

| Phase | Primary Agent | Support |
|-------|---------------|---------|
| Exploration | Riko | - |
| Planning | Senku | Riko's findings |
| Implementation | Loid | Senku's plan |
| Review | Lawliet | Loid's changes |
| Verification | Alphonse | All changes |

## Related Documentation

- [Agent Specialization](../concepts/agent-specialization.md) - Why specialization matters
- [Model Selection Guide](../concepts/agent-specialization.md#model-selection-strategy) - Opus vs Sonnet
- [Adding Agents](../guides/adding-agents.md) - How to add new agents
- [Skills Reference](skills.md) - Skill system details
