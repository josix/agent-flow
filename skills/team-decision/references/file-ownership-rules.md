# File Ownership Rules

Comprehensive rules for assigning file ownership to teammates to prevent conflicts and ensure safe parallel execution.

---

## 1. Ownership Principles

### Exclusive Write Ownership

**Rule**: Each file can be modified (written) by at most ONE teammate in a parallel team.

**Why**: Prevents merge conflicts and ensures deterministic results.

**Example**:
```
✅ VALID:
  Teammate 1 writes: src/auth/login.ts
  Teammate 2 writes: src/auth/register.ts

❌ INVALID:
  Teammate 1 writes: src/auth/auth.ts
  Teammate 2 writes: src/auth/auth.ts  ← CONFLICT!
```

### Shared Read Access

**Rule**: Multiple teammates can READ the same file, as long as only one (or zero) WRITES to it.

**Why**: Reading shared resources (types, utilities, configs) is safe and often necessary.

**Example**:
```
✅ VALID:
  Coordinator owns (read/write): src/types/common.ts
  Teammate 1 reads: src/types/common.ts, writes: src/api/endpoint1.ts
  Teammate 2 reads: src/types/common.ts, writes: src/api/endpoint2.ts
```

### Coordinator Ownership

**Rule**: The coordinator (or a single designated owner) owns shared resources that multiple teammates need to read.

**Why**: Ensures shared resources remain consistent and conflict-free.

**Example**:
```
Coordinator owns:
  - src/types/*.ts (shared types)
  - src/utils/*.ts (shared utilities)
  - config/*.ts (configuration)

Teammates own:
  - Exclusive feature files
  - Exclusive test files
```

---

## 2. Directory Partitioning

### Directory-Level Ownership

Assign entire directories to teammates for clean separation.

**Pattern**:
```
Teammate 1: src/features/auth/*
Teammate 2: src/features/billing/*
Teammate 3: src/features/notifications/*
```

**Benefits**:
- Clear boundaries
- No file conflicts
- Easy to understand
- Simple to verify

### Nested Directory Ownership

For deeper hierarchies, assign nested directories.

**Pattern**:
```
Teammate 1: src/components/Header/*
  - src/components/Header/index.tsx
  - src/components/Header/Header.tsx
  - src/components/Header/Header.test.tsx
  - src/components/Header/styles.css

Teammate 2: src/components/Footer/*
  - src/components/Footer/index.tsx
  - src/components/Footer/Footer.tsx
  - src/components/Footer/Footer.test.tsx
  - src/components/Footer/styles.css
```

---

## 3. Ownership Patterns

### Pattern 1: Feature-Based Ownership

Each teammate owns a complete feature (implementation + tests).

**Example**: Implementing authentication endpoints
```
Teammate 1:
  - src/api/auth/login.ts
  - src/api/auth/login.test.ts
  - docs/api/login.md

Teammate 2:
  - src/api/auth/register.ts
  - src/api/auth/register.test.ts
  - docs/api/register.md

Teammate 3:
  - src/api/auth/logout.ts
  - src/api/auth/logout.test.ts
  - docs/api/logout.md

Coordinator (shared):
  - src/api/auth/types.ts (read-only for teammates)
  - src/api/auth/middleware.ts (read-only for teammates)
```

### Pattern 2: Layer-Based Ownership

Each teammate owns a different layer of the same feature.

**Example**: Full-stack feature implementation
```
Teammate 1 (Backend):
  - src/api/users.ts
  - src/api/users.test.ts

Teammate 2 (Frontend):
  - src/components/UserList.tsx
  - src/components/UserList.test.tsx

Teammate 3 (Database):
  - migrations/001_create_users.sql
  - migrations/001_create_users.test.sql

Coordinator (Contracts):
  - src/types/user.ts (read-only for all)
```

**Caution**: Requires semantic independence - API contract must be stable.

### Pattern 3: Test-Based Ownership

Each teammate owns implementation + corresponding tests.

**Example**: Component testing
```
Teammate 1:
  - src/Button.tsx
  - src/Button.test.tsx

Teammate 2:
  - src/Input.tsx
  - src/Input.test.tsx

Teammate 3:
  - src/Select.tsx
  - src/Select.test.tsx
```

---

## 4. Conflict Avoidance Strategies

### Strategy 1: Pre-Create Shared Files

Create shared files (types, configs) BEFORE spawning teammates.

**Workflow**:
1. Coordinator creates `src/types/common.ts` with base types
2. Coordinator spawns teammates
3. Teammates read `common.ts` (read-only) and write to exclusive files

**Benefit**: Teammates never modify shared files, eliminating conflicts.

### Strategy 2: Directory Pre-Allocation

Create directory structure BEFORE spawning teammates.

**Workflow**:
1. Coordinator creates directories:
   - `src/features/auth/`
   - `src/features/billing/`
   - `src/features/notifications/`
2. Coordinator assigns ownership:
   - Teammate 1 → `auth/`
   - Teammate 2 → `billing/`
   - Teammate 3 → `notifications/`
3. Teammates work in their assigned directories

**Benefit**: Physical separation prevents any file overlap.

### Strategy 3: File Naming Conventions

Use naming conventions to prevent conflicts.

**Pattern**:
```
Teammate 1 creates: *-auth.* files
  - utils-auth.ts
  - types-auth.ts
  - handlers-auth.ts

Teammate 2 creates: *-billing.* files
  - utils-billing.ts
  - types-billing.ts
  - handlers-billing.ts

Teammate 3 creates: *-notifications.* files
  - utils-notifications.ts
  - types-notifications.ts
  - handlers-notifications.ts
```

**Benefit**: File names are unique by design.

---

## 5. Ownership Declaration Format

### Explicit Ownership Assignment

When spawning a team, declare file ownership explicitly.

**Template**:
```
## Team File Ownership

### Coordinator Owns (May Read/Write):
- src/types/common.ts
- src/utils/helpers.ts
- config/constants.ts

### Teammate 1 Owns (Exclusive Write):
- src/features/auth/login.ts
- src/features/auth/login.test.ts

### Teammate 2 Owns (Exclusive Write):
- src/features/auth/register.ts
- src/features/auth/register.test.ts

### Teammate 3 Owns (Exclusive Write):
- src/features/auth/logout.ts
- src/features/auth/logout.test.ts

### Shared Read-Only (All Can Read, None Write):
- src/types/common.ts
- src/utils/helpers.ts
```

### Ownership Verification

Before merging teammate results, verify ownership was respected.

**Checklist**:
- [ ] No teammate modified files outside their ownership
- [ ] No two teammates modified the same file
- [ ] Shared read-only files were not modified by teammates
- [ ] All new files fall within assigned ownership boundaries

---

## 6. Edge Cases

### Edge Case 1: Unavoidable Shared File

**Problem**: Central router file must be updated by all teammates.

**Solution 1**: Coordinator aggregates changes
```
Teammates provide route definitions as data
Coordinator writes them to the router file
```

**Solution 2**: Sequential execution
```
Don't parallelize - run teammates sequentially
Each teammate updates router, commits, next teammate pulls
```

**Solution 3**: Post-merge fix
```
Allow conflict, resolve during merge phase
Use git merge with conflict markers
```

### Edge Case 2: Generated Files

**Problem**: Build outputs or generated files might conflict.

**Solution**: Exclude from teammate ownership
```
Teammates create source files
Coordinator runs build process once after merge
Generated files (dist/, build/) not owned by teammates
```

### Edge Case 3: Shared Test Fixtures

**Problem**: Multiple teammates need same test data.

**Solution**: Pre-create fixtures
```
Coordinator creates: tests/fixtures/common.ts
Teammates import (read-only): import { fixture } from '../fixtures/common'
Each teammate creates exclusive test files
```

---

## 7. Ownership Anti-Patterns

### Anti-Pattern 1: Optimistic Overlap

**Problematic**:
```
"Teammates 1 and 2 both edit config.ts, but different sections"
```

**Why Bad**: Merge conflicts, semantic inconsistencies, hard to review

**Fix**: Coordinator owns config.ts, teammates provide changes as data

### Anti-Pattern 2: Implicit Ownership

**Problematic**:
```
No explicit ownership declared
Teammates assume files they're working on
```

**Why Bad**: Conflicts discovered late, wasted work

**Fix**: Explicitly declare ownership before spawning team

### Anti-Pattern 3: Ownership Creep

**Problematic**:
```
Teammate 1 assigned: src/auth/login.ts
Teammate 1 also modifies: src/utils/validators.ts (not assigned)
```

**Why Bad**: Violates exclusive ownership, potential conflicts

**Fix**: Reject changes to non-owned files, escalate to coordinator

---

## 8. Ownership Verification Script

Use a verification script to check ownership compliance.

**Pseudo-code**:
```bash
# For each teammate's changes:
for teammate in teammates; do
  changed_files=$(get_changed_files $teammate)
  for file in $changed_files; do
    if ! is_owned_by($file, $teammate); then
      echo "ERROR: $teammate modified non-owned file: $file"
      exit 1
    fi
  done
done

# Check for overlapping ownership:
all_files=$(get_all_changed_files)
for file in $all_files; do
  owners=$(count_owners $file)
  if [ $owners -gt 1 ]; then
    echo "ERROR: Multiple teammates modified: $file"
    exit 1
  fi
done
```

---

## 9. Best Practices Summary

1. **Declare Ownership Explicitly**: Before spawning, document who owns what
2. **Prefer Directory Partitioning**: Cleanest separation, easiest to verify
3. **Shared Files = Read-Only**: Teammates never write to shared resources
4. **Pre-Create Shared Resources**: Coordinator creates, teammates import
5. **Verify Before Merge**: Check ownership compliance before merging results
6. **Fail-Safe**: When ownership unclear, default to sequential execution

---

## See Also

- [SKILL.md](../SKILL.md) - Main team decision documentation
- [parallelism-criteria.md](parallelism-criteria.md) - Parallelism safety analysis
- [team-scenarios.md](../examples/team-scenarios.md) - Worked ownership examples
