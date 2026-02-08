# Team Decision Scenarios

Worked examples demonstrating team vs sequential decisions with detailed analysis.

---

## Scenario 1: Three Independent API Endpoints

### Task Description

User requests: "Implement three new API endpoints: GET /api/users, POST /api/users, and DELETE /api/users/:id"

### Analysis

**Decomposition**:
- Subtask 1: Implement GET /api/users endpoint
- Subtask 2: Implement POST /api/users endpoint
- Subtask 3: Implement DELETE /api/users/:id endpoint

**Independence Check**:
- Shared files: None (each endpoint in separate file)
- Dependencies: None (endpoints are independent operations)
- File ownership: Exclusive (each teammate owns their endpoint file + tests)

**File Ownership Plan**:
```
Coordinator owns (read-only for teammates):
  - src/types/user.ts (shared types)
  - src/middleware/auth.ts (shared middleware)

Teammate 1 owns:
  - src/api/users/get.ts
  - src/api/users/get.test.ts

Teammate 2 owns:
  - src/api/users/post.ts
  - src/api/users/post.test.ts

Teammate 3 owns:
  - src/api/users/delete.ts
  - src/api/users/delete.test.ts
```

**Cost-Benefit**:
- Sequential time: ~60 seconds (3 × 20s)
- Parallel time: ~35 seconds (max 20s + 15s overhead)
- Net savings: ~25 seconds

**Safety Level**: Safe

### Decision: USE TEAMS (Parallel)

**Rationale**:
- Perfect independence (no shared files to modify)
- Clear directory partitioning
- Significant time savings (25s)
- Low merge complexity (simple file concatenation)

---

## Scenario 2: Refactoring a Single Large File

### Task Description

User requests: "Refactor src/app.ts to split into smaller modules"

### Analysis

**Decomposition**:
- Subtask 1: Extract authentication logic to auth.ts
- Subtask 2: Extract routing logic to routes.ts
- Subtask 3: Extract middleware logic to middleware.ts

**Independence Check**:
- Shared files: src/app.ts (ALL subtasks modify same file)
- Dependencies: Circular (each extraction affects the others)
- File ownership: Overlapping (CONFLICT)

**Conflict Risk**:
```
Teammate 1 extracts lines 1-100 from app.ts
Teammate 2 extracts lines 50-150 from app.ts  ❌ OVERLAP
Teammate 3 extracts lines 120-200 from app.ts  ❌ OVERLAP
```

**Safety Level**: Risky

### Decision: USE SEQUENTIAL

**Rationale**:
- High file conflict risk (all modify same file)
- Semantic dependencies (extractions affect each other)
- Merge complexity would be very high
- Sequential execution ensures clean refactoring

**Alternative**: Single agent (Loid) handles entire refactoring

---

## Scenario 3: Bug Fixes in Isolated Components

### Task Description

User requests: "Fix three unrelated bugs: login validation, dashboard rendering, and report calculation"

### Analysis

**Decomposition**:
- Subtask 1: Fix login validation bug in src/auth/login.ts
- Subtask 2: Fix dashboard rendering bug in src/components/Dashboard.tsx
- Subtask 3: Fix report calculation bug in src/reports/calculator.ts

**Independence Check**:
- Shared files: None (completely different subsystems)
- Dependencies: None (bugs are unrelated)
- File ownership: Exclusive (no file overlap possible)

**File Ownership Plan**:
```
Teammate 1 owns:
  - src/auth/login.ts
  - src/auth/login.test.ts

Teammate 2 owns:
  - src/components/Dashboard.tsx
  - src/components/Dashboard.test.tsx

Teammate 3 owns:
  - src/reports/calculator.ts
  - src/reports/calculator.test.ts
```

**Cost-Benefit**:
- Sequential time: ~90 seconds (3 × 30s)
- Parallel time: ~50 seconds (max 30s + 20s overhead)
- Net savings: ~40 seconds

**Safety Level**: Safe

### Decision: USE TEAMS (Parallel)

**Rationale**:
- Complete independence (different subsystems)
- Zero file conflict risk
- Excellent time savings (40s)
- Simple merge (git merge handles cleanly)

---

## Scenario 4: Database Migration + Code Update

### Task Description

User requests: "Add 'email' field to users table and update all code to use it"

### Analysis

**Decomposition**:
- Subtask 1: Create database migration for new field
- Subtask 2: Update API endpoints to accept email
- Subtask 3: Update UI components to display email

**Independence Check**:
- Shared files: Type definitions (all subtasks need User type)
- Dependencies: SEQUENTIAL (migration must run before code can use new field)
- File ownership: Exclusive write, but semantic dependency

**Dependency Chain**:
```
Step 1: Migration creates 'email' column
  ↓
Step 2: API can now read/write 'email'
  ↓
Step 3: UI can now display 'email'
```

**Safety Level**: Risky (semantic dependencies)

### Decision: USE SEQUENTIAL

**Rationale**:
- Clear sequential dependency (migration → API → UI)
- Type changes affect all subtasks
- Risk of runtime errors if executed in wrong order
- Coordination overhead would be high

**Execution Plan**:
```
1. Senku creates plan
2. Loid executes migration
3. Loid updates types
4. Loid updates API
5. Loid updates UI
6. Alphonse verifies
```

---

## Scenario 5: Documentation Updates

### Task Description

User requests: "Update documentation for authentication, billing, and notifications features"

### Analysis

**Decomposition**:
- Subtask 1: Update docs/auth.md
- Subtask 2: Update docs/billing.md
- Subtask 3: Update docs/notifications.md

**Independence Check**:
- Shared files: None (separate markdown files)
- Dependencies: None (documentation is independent)
- File ownership: Exclusive (each teammate owns one doc file)

**File Ownership Plan**:
```
Teammate 1 owns:
  - docs/features/auth.md

Teammate 2 owns:
  - docs/features/billing.md

Teammate 3 owns:
  - docs/features/notifications.md
```

**Cost-Benefit**:
- Sequential time: ~60 seconds (3 × 20s)
- Parallel time: ~40 seconds (max 20s + 20s overhead)
- Net savings: ~20 seconds

**Safety Level**: Safe

### Decision: USE TEAMS (Parallel) or DIRECT

**Rationale**:
- Perfect independence (separate files)
- Zero conflict risk
- Moderate time savings

**Alternative**: Documentation updates are often trivial enough for direct execution without agents, depending on complexity.

---

## Scenario 6: Shared Utility Refactoring

### Task Description

User requests: "Extract three helper functions from utils.ts to separate files: validators.ts, formatters.ts, parsers.ts"

### Analysis

**Decomposition**:
- Subtask 1: Extract validators from utils.ts → validators.ts
- Subtask 2: Extract formatters from utils.ts → formatters.ts
- Subtask 3: Extract parsers from utils.ts → parsers.ts

**Independence Check**:
- Shared files: utils.ts (all subtasks remove code from same file)
- Dependencies: None (extractions are independent)
- File ownership: OVERLAPPING (all modify utils.ts)

**Conflict Analysis**:
```
Teammate 1: Remove lines 1-50 from utils.ts
Teammate 2: Remove lines 51-100 from utils.ts
Teammate 3: Remove lines 101-150 from utils.ts

Problem: Line numbers shift after each removal → CONFLICTS
```

**Safety Level**: Risky

### Decision: USE SEQUENTIAL

**Rationale**:
- All teammates modify same source file (utils.ts)
- Extraction order affects line numbers
- High merge conflict probability
- Sequential execution ensures clean refactoring

**Alternative Parallel Approach** (if feasible):
```
1. Coordinator copies utils.ts three times:
   - utils-validators.ts (lines 1-50)
   - utils-formatters.ts (lines 51-100)
   - utils-parsers.ts (lines 101-150)

2. Spawn team:
   Teammate 1: Refactor utils-validators.ts → validators.ts
   Teammate 2: Refactor utils-formatters.ts → formatters.ts
   Teammate 3: Refactor utils-parsers.ts → parsers.ts

3. Coordinator deletes utils.ts and combines results

Benefit: Parallelizable with pre-processing
Risk: More complex coordination
```

---

## Scenario 7: Feature Implementation with Shared Types

### Task Description

User requests: "Implement three related features: user profiles, user settings, and user preferences"

### Analysis

**Decomposition**:
- Subtask 1: Implement user profiles (read-only user data)
- Subtask 2: Implement user settings (account configuration)
- Subtask 3: Implement user preferences (UI preferences)

**Independence Check**:
- Shared files: src/types/user.ts (read-only for all)
- Dependencies: None (features are independent)
- File ownership: Exclusive write, shared read

**File Ownership Plan**:
```
Coordinator owns (read/write):
  - src/types/user.ts (may extend if needed)

Teammate 1 owns (exclusive write, reads user.ts):
  - src/features/profile/Profile.tsx
  - src/features/profile/Profile.test.tsx
  - src/api/profile.ts

Teammate 2 owns (exclusive write, reads user.ts):
  - src/features/settings/Settings.tsx
  - src/features/settings/Settings.test.tsx
  - src/api/settings.ts

Teammate 3 owns (exclusive write, reads user.ts):
  - src/features/preferences/Preferences.tsx
  - src/features/preferences/Preferences.test.tsx
  - src/api/preferences.ts
```

**Cost-Benefit**:
- Sequential time: ~120 seconds (3 × 40s)
- Parallel time: ~60 seconds (max 40s + 20s overhead)
- Net savings: ~60 seconds

**Safety Level**: Moderate (shared read-only types)

### Decision: USE TEAMS (Parallel)

**Rationale**:
- Exclusive write ownership maintained
- Shared types are read-only (safe)
- Significant time savings (60s)
- Coordinator can review type consistency after merge

**Post-Merge Review**: Coordinator verifies type usage is consistent across all features

---

## Scenario 8: Security Audit Across Modules

### Task Description

User requests: "Audit authentication, authorization, and encryption modules for security vulnerabilities"

### Analysis

**Decomposition**:
- Subtask 1: Audit authentication module
- Subtask 2: Audit authorization module
- Subtask 3: Audit encryption module

**Independence Check**:
- Shared files: None (separate modules)
- Dependencies: Semantic (auth and authz interact, encryption used by both)
- File ownership: Exclusive (read-only analysis)

**Semantic Dependencies**:
```
Authentication uses encryption
Authorization checks authentication
Vulnerabilities may span multiple modules
```

**Safety Level**: Moderate (read-only, but requires holistic view)

### Decision: USE SEQUENTIAL or SINGLE AGENT

**Rationale**:
- Security requires holistic analysis
- Vulnerabilities may span modules (need full context)
- Coordination overhead high (consolidating security findings)
- Lawliet (Reviewer) should see full picture

**Execution Plan**:
```
Option 1: Single Lawliet review (holistic)
Option 2: Riko explores → Lawliet reviews (comprehensive)
```

---

## Summary Table

| Scenario | Independence | File Conflicts | Decision | Time Savings |
|----------|--------------|----------------|----------|--------------|
| 1. Three API endpoints | Full | None | TEAMS | 25s |
| 2. Refactor single file | None | High | SEQUENTIAL | N/A |
| 3. Isolated bug fixes | Full | None | TEAMS | 40s |
| 4. Migration + code | Sequential | Semantic | SEQUENTIAL | N/A |
| 5. Documentation updates | Full | None | TEAMS or DIRECT | 20s |
| 6. Shared utility refactor | None | High | SEQUENTIAL | N/A |
| 7. Related features | Moderate | Read-only shared | TEAMS | 60s |
| 8. Security audit | Semantic | None | SEQUENTIAL | N/A |

---

## Key Takeaways

1. **File ownership is king**: If teammates must modify same files, use sequential
2. **Semantic dependencies matter**: Even with exclusive files, dependencies force sequential
3. **Time savings must justify overhead**: Only parallelize if each task takes 20+ seconds
4. **Security and critical changes**: Default to sequential for comprehensive review
5. **Read-only sharing is safe**: Multiple teammates can read shared resources safely

---

## See Also

- [SKILL.md](../SKILL.md) - Main team decision documentation
- [parallelism-criteria.md](../references/parallelism-criteria.md) - Detailed safety criteria
- [file-ownership-rules.md](../references/file-ownership-rules.md) - Ownership patterns
