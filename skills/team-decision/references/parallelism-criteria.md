# Parallelism Criteria

Detailed reference for assessing parallelism safety across phase-level, task-level, and file-level dimensions.

---

## 1. Phase-Level Parallelism

Parallelism at the entire project phase level.

### When Safe

- Multiple independent features in separate modules
- Documentation updates across different sections
- Test creation for unrelated components
- Bug fixes in isolated subsystems

### When Risky

- Major refactoring affecting shared code
- API contract changes across services
- Database migrations with schema changes
- Security updates requiring holistic review

---

## 2. Task-Level Parallelism

Parallelism within a single logical task decomposed into subtasks.

### Independence Criteria

**Data Independence**:
- Subtasks operate on different data structures
- No shared mutable state
- Read-only access to shared resources acceptable

**Control Independence**:
- Execution order doesn't matter
- No sequential dependencies (A must complete before B)
- Failures are isolated (one subtask failing doesn't block others)

**Resource Independence**:
- Exclusive file ownership
- No database table conflicts
- No API endpoint overlaps

### Dependency Patterns

**Acceptable**:
```
Task A: Implement feature → Tests pass
Task B: Implement feature → Tests pass
Task C: Implement feature → Tests pass
Merge: Combine all changes
```

**Problematic**:
```
Task A: Define types → Task B depends on types → Task C uses Task B output
(Sequential dependency chain - NOT parallelizable)
```

---

## 3. File-Level Parallelism

Parallelism based on file ownership patterns.

### Exclusive Ownership (Safe)

Each teammate owns distinct files with no overlap.

**Example 1**: Feature implementation
```
Teammate 1:
  - src/features/auth/login.ts
  - src/features/auth/login.test.ts

Teammate 2:
  - src/features/auth/register.ts
  - src/features/auth/register.test.ts

Teammate 3:
  - src/features/auth/logout.ts
  - src/features/auth/logout.test.ts
```

**Conflict Risk**: ZERO (no file overlap)

### Shared Read-Only (Moderate)

Teammates read common files but write to exclusive files.

**Example 2**: Related features with shared types
```
Coordinator owns (read/write):
  - src/types/user.ts
  - src/utils/validators.ts

Teammate 1 (read shared, write exclusive):
  - Reads: user.ts, validators.ts
  - Writes: src/api/user-create.ts

Teammate 2 (read shared, write exclusive):
  - Reads: user.ts, validators.ts
  - Writes: src/api/user-update.ts
```

**Conflict Risk**: LOW (semantic consistency may need review)

**Mitigation**: Coordinator reviews for consistency after merge

### Overlapping Write Ownership (Risky)

Multiple teammates write to same files.

**Example 3**: Concurrent modification (AVOID)
```
Teammate 1:
  - src/app.ts (adds route A)

Teammate 2:
  - src/app.ts (adds route B)  ❌ CONFLICT

Teammate 3:
  - src/app.ts (adds route C)  ❌ CONFLICT
```

**Conflict Risk**: HIGH (merge conflicts guaranteed)

**Solution**: Sequential execution or restructure to avoid overlap

---

## 4. Semantic Independence

Beyond file ownership, ensure semantic independence.

### Examples of Semantic Dependencies

**API Contracts**:
```
Task A: Change response format of /api/users endpoint
Task B: Update client code to consume /api/users

→ Task B depends on Task A completing first (NOT parallel)
```

**Type Changes**:
```
Task A: Rename User type to Account
Task B: Update components using User type

→ Task B depends on Task A (NOT parallel)
```

**Configuration Changes**:
```
Task A: Add new environment variable
Task B: Use new environment variable

→ Task B depends on Task A (NOT parallel)
```

### Safe Semantic Independence

**Independent Features**:
```
Task A: Implement pagination
Task B: Implement sorting
Task C: Implement filtering

→ All independent, can be combined (PARALLEL)
```

**Isolated Bug Fixes**:
```
Task A: Fix validation bug in login
Task B: Fix rendering bug in dashboard
Task C: Fix calculation bug in reports

→ No interaction, safe to parallelize (PARALLEL)
```

---

## 5. Anti-Patterns

### Anti-Pattern 1: Same File, Different Sections

**Problematic**:
```
Teammate 1: Edit lines 1-100 of config.ts
Teammate 2: Edit lines 101-200 of config.ts
```

**Why Risky**: Merge conflicts, semantic dependencies, testing complexity

**Solution**: Sequential execution or split into separate files

### Anti-Pattern 2: Shared Database Table

**Problematic**:
```
Teammate 1: Add column 'email' to users table
Teammate 2: Add column 'phone' to users table
```

**Why Risky**: Migration conflicts, schema version conflicts

**Solution**: Single teammate handles all schema changes

### Anti-Pattern 3: Circular Dependencies

**Problematic**:
```
Task A: Create utility function
Task B: Use utility in feature
Task C: Extend utility based on Task B needs
```

**Why Risky**: Circular dependency, unclear execution order

**Solution**: Sequential with clear phases: A → B → C

### Anti-Pattern 4: Over-Parallelization

**Problematic**:
```
5 teammates each implementing tiny 5-second tasks
Overhead: 60 seconds
Net result: Slower than sequential
```

**Why Risky**: Coordination overhead exceeds time savings

**Solution**: Batch into fewer, larger tasks or run sequentially

---

## 6. Safety Checklist

Before approving parallel execution, verify:

### File Safety
- [ ] Each teammate has exclusive write ownership of their files
- [ ] Shared resources are read-only for teammates
- [ ] No file conflicts are possible

### Task Safety
- [ ] Tasks are logically independent
- [ ] No sequential dependencies exist
- [ ] Failures are isolated (one task failing doesn't block others)

### Semantic Safety
- [ ] No API contract dependencies
- [ ] No type definition dependencies
- [ ] No configuration dependencies
- [ ] No database schema conflicts

### Cost-Benefit Safety
- [ ] Each task takes 20+ seconds (overhead justified)
- [ ] Total team size is 2-4 teammates (not over-parallelized)
- [ ] Merge complexity is low (simple concatenation or git merge)

### Risk Tolerance
- [ ] Can afford retries if conflicts arise
- [ ] User is present to resolve issues if needed
- [ ] Not security-critical (prefer sequential for security)

---

## 7. Parallelism Decision Matrix

| Scenario | File Overlap | Dependencies | Safety | Decision |
|----------|-------------|--------------|--------|----------|
| 3 independent API endpoints | None | None | Safe | PARALLEL |
| 3 related features, shared types | Read-only shared | None | Moderate | PARALLEL (with review) |
| Refactoring single large file | Full overlap | Sequential | Risky | SEQUENTIAL |
| Database migration + code update | Semantic | Sequential | Risky | SEQUENTIAL |
| Bug fixes in isolated components | None | None | Safe | PARALLEL |
| Feature + tests for same feature | Semantic | Sequential | Risky | SEQUENTIAL |

---

## See Also

- [SKILL.md](../SKILL.md) - Main team decision documentation
- [file-ownership-rules.md](file-ownership-rules.md) - Detailed ownership patterns
- [team-scenarios.md](../examples/team-scenarios.md) - Worked examples
