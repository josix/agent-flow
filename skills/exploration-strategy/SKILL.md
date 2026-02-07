---
name: exploration-strategy
description: This skill should be used when exploring codebases, finding patterns, searching for code, gathering context, or understanding code structure before planning or implementation.
---

# Exploration Strategy

Use fast, parallel exploration to gather context before planning.

## Overview

Effective exploration minimizes wasted effort by quickly identifying relevant code, patterns, and conventions. This skill defines exploration patterns, tool selection, and convergence criteria.

### Key Principles

1. **Parallel over sequential** - Run multiple searches simultaneously when possible
2. **Targeted over exhaustive** - Start with likely locations, expand if needed
3. **Converge quickly** - Stop when results stabilize or context is sufficient
4. **Summarize for handoff** - Produce actionable summaries for downstream agents

---

## Exploration Patterns

Choose the appropriate pattern based on task characteristics.

### Breadth-First Exploration

**Use when:** Structure is unclear or unfamiliar codebase

**Approach:**
1. Start with high-level structure (directories, entry points)
2. Identify major components and their relationships
3. Narrow focus based on initial findings
4. Deep dive into relevant areas

**Example:**
```
Initial: Glob for package.json, setup.py, main entry points
Then:    List top-level directories
Then:    Read README and key configs
Finally: Focus on relevant subsystems
```

### Depth-First Exploration

**Use when:** Target is known but details are needed

**Approach:**
1. Start at known entry point
2. Follow imports and references
3. Map the call chain
4. Document dependencies

**Example:**
```
Start:   Read specific file mentioned in task
Then:    Follow imports in that file
Then:    Read imported modules
Finally: Document the dependency tree
```

### Targeted Exploration

**Use when:** Looking for specific patterns or implementations

**Approach:**
1. Search for specific terms, patterns, or signatures
2. Filter results by relevance
3. Read most promising matches
4. Expand search if needed

**Example:**
```
Search:  Grep for function name or pattern
Filter:  Exclude test files if not relevant
Read:    Top 3-5 most relevant matches
Expand:  Broaden search terms if insufficient
```

See [Search Patterns](references/search-patterns.md) for detailed pattern guidance.

---

## Search Tool Selection

Match the tool to the search goal.

### Tool Selection Matrix

| Goal | Primary Tool | When to Use |
|------|--------------|-------------|
| Find files by name | Glob | Know the filename pattern |
| Find content in files | Grep | Know what text to search for |
| Read file contents | Read | Need full file context |
| External documentation | WebSearch | Need API docs or external info |
| Fetch specific page | WebFetch | Have URL, need content |

### Glob Patterns

Use Glob for file discovery:

```
Project structure:     **/*.{ts,tsx}
Config files:          **/config.{json,yaml,yml}
Test files:            **/*.test.ts, **/*.spec.ts
Entry points:          **/index.ts, **/main.ts
Specific component:    **/components/**/Button*.tsx
```

### Grep Patterns

Use Grep for content search:

```
Function definitions:  function\s+handleSubmit
Class definitions:     class\s+UserService
Imports:               import.*from.*@company/
TODO comments:         TODO|FIXME|HACK
Type definitions:      interface\s+User|type\s+User
```

### Combining Tools

Effective exploration often chains tools:

```
1. Glob: Find all TypeScript files
2. Grep: Search for specific pattern in those files
3. Read: Examine the most relevant matches
```

---

## Parallel Search Strategies

Maximize exploration efficiency with parallel searches.

### When to Parallelize

- Multiple independent search terms
- Different file types to examine
- Separate areas of the codebase
- Complementary search angles

### Parallel Search Examples

**Finding a feature implementation:**
```
Parallel:
  - Grep: "featureName" in source files
  - Grep: "featureName" in test files
  - Glob: files with "feature" in name
  - Grep: related config/constants
```

**Understanding a module:**
```
Parallel:
  - Read: module index/main file
  - Grep: imports of this module
  - Glob: test files for this module
  - Read: README in module directory
```

### Parallel Search Limits

- Run 3-5 parallel searches maximum
- Too many parallels fragments focus
- Consolidate results before expanding

---

## Context Gathering Techniques

Gather sufficient context without over-reading.

### Essential Context Checklist

Before concluding exploration, verify:

- [ ] Entry points identified
- [ ] Key dependencies mapped
- [ ] Existing patterns documented
- [ ] Test approach understood
- [ ] Config/environment requirements noted

### Context Priorities

| Priority | Context Type | When Essential |
|----------|--------------|----------------|
| High | Direct implementation files | Always |
| High | Related test files | When modifying behavior |
| Medium | Type definitions | When working with types |
| Medium | Configuration files | When behavior is configurable |
| Low | Documentation files | When conventions unclear |
| Low | Build configuration | When build issues possible |

### Reading Strategies

**Skim for structure:**
- Read entry point files fully
- Skim supporting files for patterns
- Focus on public interfaces

**Deep read for details:**
- Implementation logic when modifying
- Test files when adding tests
- Type definitions when typing

---

## Convergence Criteria

Know when exploration is complete.

### Stop Exploring When

1. **Results stabilize** - New searches return same files
2. **Context sufficient** - Can answer key questions about implementation
3. **Patterns identified** - Understand codebase conventions
4. **Scope defined** - Know what files need modification

### Continue Exploring When

1. **Gaps remain** - Cannot answer basic questions about approach
2. **Inconsistencies found** - Different patterns in different areas
3. **Dependencies unclear** - Cannot determine what else might be affected
4. **Edge cases unknown** - Have not identified error handling patterns

### Exploration Depth Guidelines

| Task Complexity | Exploration Depth | Time Budget |
|-----------------|-------------------|-------------|
| Simple fix | 1-3 files | 2-5 minutes |
| Feature addition | 5-10 files | 5-10 minutes |
| Refactoring | 10-20 files | 10-15 minutes |
| Architecture change | 20+ files | 15-30 minutes |

See [Exploration Depth](references/exploration-depth.md) for complexity guidelines.

---

## Quick Reference

### Exploration Flow

```
1. Identify likely directories and patterns
2. Run parallel searches for patterns
3. Read most relevant files for conventions
4. Summarize findings for handoff
5. Stop when context sufficient
```

### Tool Decision Tree

```
Need files? -> Glob
Need content? -> Grep
Need detail? -> Read
Need external? -> WebSearch/WebFetch
```

### Convergence Check

```
Can I answer: What files to modify?
Can I answer: What patterns to follow?
Can I answer: What dependencies exist?
If yes to all -> Stop exploring
If no to any -> Continue with targeted search
```

---

## Resources

- [Search Patterns](references/search-patterns.md) - Detailed search pattern guidance
- [Exploration Depth](references/exploration-depth.md) - Depth guidelines by task type
- [Deep-Dive Patterns](references/deep-dive-patterns.md) - Parallel exploration for /deep-dive command
- [Exploration Scenarios](examples/exploration-scenarios.md) - Worked exploration examples

## Related Skills

- [task-classification](../task-classification/SKILL.md) - Classifies tasks before exploration
- [agent-behavior-constraints](../agent-behavior-constraints/SKILL.md) - Defines Riko's tool permissions
- [prompt-refinement](../prompt-refinement/SKILL.md) - Refines exploration queries
