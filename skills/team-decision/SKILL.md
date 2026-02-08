---
name: team-decision
description: This skill should be used when deciding whether to use Agent Teams for parallel execution or sequential subagent orchestration, based on task analysis, independence criteria, and cost-benefit.
---

# Team Decision

## Overview

The team decision skill guides the choice between parallel Agent Teams execution and sequential subagent orchestration. This skill analyzes task characteristics to determine whether parallel execution is safe, beneficial, and cost-effective.

**Owner Agent**: Senku (Planner Agent)

**Consumers**: Orchestrator (primary decision maker)

### Key Principles

1. **Safety First**: Only parallelize when tasks are truly independent
2. **Cost-Benefit Analysis**: Parallel overhead must be justified by time savings
3. **File Ownership**: Exclusive file ownership prevents conflicts
4. **Fail to Sequential**: When in doubt, use sequential orchestration

### When to Use This Skill

Apply team decision analysis when:
- A task naturally decomposes into multiple subtasks
- Subtasks could potentially run in parallel
- Time-to-completion is a priority
- Determining whether to spawn a team or orchestrate sequentially

---

## Decision Criteria Table

| Criterion | Use Teams (Parallel) | Use Sequential |
|-----------|---------------------|----------------|
| **Task Independence** | No shared state or files | Tasks have dependencies |
| **File Ownership** | Exclusive file sets | Overlapping file sets |
| **Parallelism Safety** | Safe or Moderate | Risky |
| **Number of Tasks** | 2-4 independent tasks | 1 task or 5+ tasks |
| **Time Sensitivity** | High (user waiting) | Low (can afford serial) |
| **Coordination Cost** | Low (simple merge) | High (complex merge) |
| **Risk Tolerance** | High (can retry) | Low (must be correct) |

### Quick Decision Flowchart

```
Task Decomposition Available?
  |
  +-- NO --> Sequential (single agent)
  |
  +-- YES
        |
        v
      Subtasks Share Files?
        |
        +-- YES --> Sequential (conflict risk)
        |
        +-- NO
              |
              v
            Subtasks Have Dependencies?
              |
              +-- YES --> Sequential (ordering required)
              |
              +-- NO
                    |
                    v
                  2-4 Subtasks?
                    |
                    +-- NO --> Sequential (too few or too many)
                    |
                    +-- YES
                          |
                          v
                        Time Savings > Overhead?
                          |
                          +-- YES --> TEAMS (Parallel)
                          |
                          +-- NO --> Sequential
```

---

## Parallelism Safety Levels

### Safe Parallelism

Tasks that are completely independent and share no resources.

**Examples**:
- Implementing 3 independent API endpoints in different route files
- Writing documentation in separate markdown files
- Creating unit tests for different modules
- Fixing bugs in isolated components

**Characteristics**:
- No shared files (each task owns exclusive files)
- No shared database tables
- No API contract dependencies
- Results can be merged with `git merge` or file concatenation

### Moderate Parallelism

Tasks that may share some context but have isolated file ownership.

**Examples**:
- Implementing related features that share type definitions (read-only)
- Refactoring separate modules that use common utilities (read-only)
- Adding tests that import the same test helpers (read-only)

**Characteristics**:
- May read shared files (but each writes to exclusive files)
- Low risk of semantic conflicts
- Requires review to ensure consistency
- May need coordination on shared patterns

**Mitigation**: Assign read-only files to coordinator, exclusive write ownership to teammates

### Risky Parallelism

Tasks with high coordination costs or conflict potential.

**Examples**:
- Modifying the same file from different tasks
- Database migrations affecting shared schema
- Refactoring with cross-cutting changes
- Security changes requiring holistic review

**Characteristics**:
- Multiple tasks write to same files
- Semantic dependencies between changes
- High merge conflict potential
- Requires deep understanding of interactions

**Decision**: Do NOT parallelize - use sequential orchestration

---

## Cost Analysis Framework

### Overhead Costs of Teams

| Overhead Type | Estimated Cost | When Significant |
|---------------|---------------|------------------|
| Team spawn/setup | 5-10 seconds | Always |
| Context duplication | 2-5 seconds per teammate | Large context |
| Result merging | 10-30 seconds | Complex merge |
| Conflict resolution | 60-300 seconds | If conflicts occur |
| Coordination overhead | 5-15 seconds | Always |

**Total Overhead**: ~30-60 seconds for 2-3 teammates with simple merge

### Time Savings Calculation

```
Sequential Time = Task1 + Task2 + Task3
Parallel Time = max(Task1, Task2, Task3) + Overhead

Net Savings = Sequential Time - Parallel Time
```

**Break-Even Analysis**:
- **2 tasks, 30s each**: Parallel = 30s + overhead (~40s) vs Sequential = 60s → **Save 20s**
- **3 tasks, 20s each**: Parallel = 20s + overhead (~35s) vs Sequential = 60s → **Save 25s**
- **2 tasks, 10s each**: Parallel = 10s + overhead (~40s) vs Sequential = 20s → **Lose 20s**

**Rule of Thumb**: Parallelize only if each task takes 20+ seconds and tasks are independent

---

## File Ownership Rules

### Exclusive Ownership Principle

Each teammate in a team MUST have exclusive write ownership of their files.

**Valid Assignment**:
```
Teammate 1: src/auth/login.ts, src/auth/login.test.ts
Teammate 2: src/auth/register.ts, src/auth/register.test.ts
Teammate 3: src/auth/logout.ts, src/auth/logout.test.ts
Coordinator: src/auth/types.ts (read-only for teammates)
```

**Invalid Assignment** (conflict risk):
```
Teammate 1: src/auth/auth.ts (lines 1-50)
Teammate 2: src/auth/auth.ts (lines 51-100)  ❌ Same file!
```

### Directory Partitioning

When tasks can be partitioned by directory, use directory-level ownership.

**Example**:
```
Teammate 1: src/components/Header/*
Teammate 2: src/components/Footer/*
Teammate 3: src/components/Sidebar/*
```

**Benefits**:
- Clear ownership boundaries
- No file conflicts possible
- Easy to verify in review

### Shared Read-Only Resources

Common resources (types, utilities, configs) can be read by all teammates but owned by coordinator.

**Pattern**:
```
Coordinator owns (may modify):
  - src/types/common.ts
  - src/utils/helpers.ts
  - config/constants.ts

Teammates read (do NOT modify):
  - Import types from common.ts
  - Use helpers from helpers.ts
  - Read constants from constants.ts
```

For detailed ownership rules, see [references/file-ownership-rules.md](references/file-ownership-rules.md).

---

## Team Size Guidelines

| Team Size | When Appropriate | Coordination Overhead |
|-----------|-----------------|----------------------|
| 2 teammates | Simple decomposition, clear separation | Low |
| 3 teammates | Moderate complexity, 3-way split | Medium |
| 4 teammates | Complex task, highly parallelizable | High |
| 5+ teammates | Rarely beneficial - overhead dominates | Very High |

**Optimal**: 2-3 teammates for most parallel tasks

---

## Quick Reference

### Parallel Eligibility Checklist

Before deciding to use teams, verify:

- [ ] Task naturally decomposes into 2-4 subtasks
- [ ] Each subtask is genuinely independent (no sequential dependencies)
- [ ] File ownership is exclusive (no file conflicts possible)
- [ ] Each subtask takes 20+ seconds (parallelism overhead justified)
- [ ] Merge complexity is low (simple file concatenation or git merge)
- [ ] Risk tolerance is appropriate (can afford retries if issues arise)

If ALL checks pass → **Consider Teams**

If ANY check fails → **Use Sequential Orchestration**

### Decision Template

```
## Team vs Sequential Decision

Task: [Brief description]

Decomposition:
  - Subtask 1: [description]
  - Subtask 2: [description]
  - Subtask 3: [description]

Independence Analysis:
  - Shared files: [None / List files]
  - Dependencies: [None / List dependencies]
  - Safety level: [Safe / Moderate / Risky]

Cost-Benefit:
  - Sequential time: ~[X] seconds
  - Parallel time: ~[Y] seconds (including overhead)
  - Net savings: ~[Z] seconds

Decision: [TEAMS / SEQUENTIAL]
Rationale: [1-2 sentence justification]
```

---

## Related Skills

- **task-classification**: Determines task complexity before team decision
- **agent-behavior-constraints**: Defines which agents can be teammates
- **verification-gates**: Ensures quality regardless of execution mode

## Additional Resources

### Reference Files

- [references/parallelism-criteria.md](references/parallelism-criteria.md) - Detailed parallelism safety analysis
- [references/file-ownership-rules.md](references/file-ownership-rules.md) - File ownership patterns

### Examples

- [examples/team-scenarios.md](examples/team-scenarios.md) - Worked decision examples
