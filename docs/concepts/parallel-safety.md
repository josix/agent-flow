# Parallel Safety

Understanding why Review + Verification can safely execute in parallel, and when NOT to parallelize agent operations.

## The Parallel Safety Question

Not all agent operations can run concurrently. Parallel execution is only safe when operations:
1. Share no mutable state
2. Modify no overlapping resources
3. Have no order dependencies
4. Can be retried independently

Team orchestration parallelizes **Review** (Lawliet) and **Verification** (Alphonse) because these phases meet all safety criteria.

## Why Review + Verification is Safe

### Independence Analysis

| Aspect | Review (Lawliet) | Verification (Alphonse) | Shared? |
|--------|------------------|------------------------|---------|
| **Input** | Modified files (read-only) | Modified files (read-only) | Yes (read-only) |
| **Operations** | Static analysis, linting | Test execution, building | No |
| **State** | None | None | No |
| **Side effects** | None | None | No |
| **Output** | Verdict (APPROVED/NEEDS_CHANGES) | Results (VERIFIED/FAILED) | No |

**Key insight**: Both agents READ the same files but perform completely different operations with no shared state.

### Detailed Safety Analysis

#### 1. No File Modifications

Both agents operate in read-only mode:

**Lawliet (Review)**:
- Runs `tsc --noEmit` (type checking only)
- Runs `eslint .` (analysis only)
- Reads files to check patterns
- Never modifies code

**Alphonse (Verification)**:
- Runs `npm test` (executes tests)
- Runs `npm run build` (generates output)
- May create build artifacts
- Never modifies source files

**Safety guarantee**: Source files remain unchanged by both agents.

#### 2. No Shared State

Each agent maintains independent state:

**Lawliet**:
- Static analysis cache (temporary)
- Lint results (in-memory)
- Type check results (in-memory)

**Alphonse**:
- Test results (in-memory)
- Build output (separate directory)
- Verification status (in-memory)

**Safety guarantee**: No state synchronization required.

#### 3. Idempotent Operations

Both agents can be retried without side effects:

**Lawliet**:
- Re-running `tsc --noEmit` produces same results
- Re-running linters produces same results
- Multiple runs don't change outcomes

**Alphonse**:
- Re-running tests produces same results (deterministic tests)
- Re-building produces same artifacts
- Multiple runs don't change outcomes

**Safety guarantee**: Safe to retry on failure.

#### 4. No Order Dependency

Results are independent of execution order:

```
Sequential A (Review → Verification):
  Review: APPROVED
  Verification: VERIFIED

Sequential B (Verification → Review):
  Verification: VERIFIED
  Review: APPROVED

Parallel (Review || Verification):
  Review: APPROVED
  Verification: VERIFIED
```

**Safety guarantee**: Order doesn't affect correctness.

## File Ownership Principles

When parallelizing operations, establish clear ownership boundaries.

### Read-Only Shared Access

**Safe Pattern**: Multiple agents reading the same files

```
Lawliet reads src/auth.ts → Analyze patterns
Alphonse reads src/auth.ts → Run tests importing it
```

No conflicts because both are read-only.

### Write Exclusivity

**Unsafe Pattern**: Multiple agents writing to the same files

```
Loid writes src/auth.ts
Lawliet writes src/auth.ts  ← CONFLICT!
```

**Rule**: Only ONE agent may write to a file at any time.

### Ownership Assignment

| File Type | Owner | Others |
|-----------|-------|--------|
| Source code | Loid (Implementation) | Read-only |
| Test files | Loid (Implementation) | Read-only |
| Build output | Alphonse (Verification) | Read-only |
| State files | Orchestrator | Read-only |
| Planning files | Senku (Planning) | Read-only |

## Safe Parallelization Patterns

### Pattern 1: Independent Read-Only Operations

**Example**: Review + Verification

```
Lawliet: Read files → Analyze → Return verdict
Alphonse: Read files → Execute tests → Return results
```

**Safety**: No writes, no conflicts.

### Pattern 2: Disjoint File Sets

**Example**: Multi-module implementation (future extension)

```
Loid A: Write src/api/** (exclusive)
Loid B: Write src/models/** (exclusive)
```

**Safety**: No overlapping file ownership.

### Pattern 3: Different Output Targets

**Example**: Parallel report generation

```
Agent A: Generate HTML report → output/report.html
Agent B: Generate JSON report → output/report.json
```

**Safety**: Different output files.

## When NOT to Parallelize

### Anti-Pattern 1: Sequential Dependencies

**Unsafe**: Planning and Implementation in parallel

```
Senku: Create plan
Loid: Implement plan  ← Needs plan first!
```

**Why unsafe**: Loid requires Senku's output as input.

### Anti-Pattern 2: Shared Writes

**Unsafe**: Multiple agents modifying the same file

```
Agent A: Write src/config.ts
Agent B: Write src/config.ts  ← Race condition!
```

**Why unsafe**: Last write wins, changes may be lost.

### Anti-Pattern 3: Stateful Operations

**Unsafe**: Parallel database migrations

```
Agent A: Run migration 001
Agent B: Run migration 002  ← Order matters!
```

**Why unsafe**: Migrations must execute in order.

### Anti-Pattern 4: Resource Contention

**Unsafe**: Parallel processes using the same port

```
Agent A: Start server on port 3000
Agent B: Start server on port 3000  ← Port conflict!
```

**Why unsafe**: Shared resource (port) causes conflict.

## Verification of Safety Properties

Before parallelizing, verify these properties:

### Safety Checklist

```
For operations A and B to run in parallel:

[ ] Input independence
    - A's output is not B's input
    - B's output is not A's input

[ ] No shared writes
    - A and B don't write to the same files
    - A and B don't modify shared state

[ ] Idempotency
    - A can be retried without side effects
    - B can be retried without side effects

[ ] Order independence
    - A then B produces same result as B then A
    - Parallel execution produces consistent results

[ ] Resource isolation
    - A and B don't compete for exclusive resources
    - No port conflicts, lock conflicts, etc.
```

**Only parallelize if ALL checks pass.**

## Parallel Execution Contracts

When spawning parallel agents, establish contracts:

### Review Contract (Lawliet)

**Inputs**:
- List of modified files (read-only)
- Codebase context (read-only)

**Operations**:
- Static analysis (read-only)
- Linting (read-only)
- Pattern checking (read-only)

**Outputs**:
- Verdict: APPROVED or NEEDS_CHANGES
- Issues list (if NEEDS_CHANGES)

**Guarantees**:
- No file modifications
- No side effects
- Idempotent

### Verification Contract (Alphonse)

**Inputs**:
- Full codebase (read-only for source)
- Test suite (executable)

**Operations**:
- Run tests (may write to test outputs)
- Run build (may write to build directory)
- Type checking (read-only)

**Outputs**:
- Results: VERIFIED or FAILED
- Failure details (if FAILED)

**Guarantees**:
- No source file modifications
- Build artifacts in separate directory
- Idempotent

## Failure Handling in Parallel Execution

When parallel operations fail, ensure consistent recovery.

### Independent Failure Modes

```
Scenario 1: Both succeed
  Review: APPROVED
  Verification: VERIFIED
  → Proceed to completion

Scenario 2: Review fails
  Review: NEEDS_CHANGES
  Verification: VERIFIED  ← Still valuable
  → Iterate (address review issues)

Scenario 3: Verification fails
  Review: APPROVED  ← Still valuable
  Verification: FAILED
  → Iterate (fix test failures)

Scenario 4: Both fail
  Review: NEEDS_CHANGES
  Verification: FAILED
  → Iterate (address all issues)
```

**Safety guarantee**: Failures are independent and can be handled separately.

### Retry Safety

Parallel operations must support independent retries:

```
Initial attempt:
  Review: NEEDS_CHANGES
  Verification: VERIFIED

After fixes:
  Review: Retry only
  Verification: No retry needed (already passed)
```

**Safety guarantee**: Idempotent operations enable selective retries.

## Real-World Safety Violations

Learn from common mistakes in parallel execution.

### Case Study: Parallel Writes

**Attempted**: Two agents implementing different features

```
Agent A: Add login feature → Modify src/auth.ts
Agent B: Add logout feature → Modify src/auth.ts
```

**Result**: Last write wins, one feature lost

**Fix**: Sequential implementation or disjoint file sets

### Case Study: Shared Test Database

**Attempted**: Parallel test execution

```
Agent A: Run tests using test DB
Agent B: Run tests using test DB  ← Shared state!
```

**Result**: Test interference, flaky results

**Fix**: Isolated test databases or sequential execution

### Case Study: Build Artifact Conflicts

**Attempted**: Parallel builds

```
Agent A: Build frontend → dist/
Agent B: Build backend → dist/  ← Same directory!
```

**Result**: Artifacts overwrite each other

**Fix**: Separate output directories (dist/frontend/, dist/backend/)

## Future Parallelization Opportunities

When considering new parallel patterns, apply safety principles.

### Safe Future Extensions

#### Multi-Module Implementation
```
parallel_groups:
  implementation:
    module_a:
      files: ["src/module-a/**"]
      agent: "Loid"
    module_b:
      files: ["src/module-b/**"]
      agent: "Loid"
```

**Safety**: Disjoint file sets ensure no conflicts.

#### Layered Verification
```
parallel_groups:
  fast_checks:
    types: "Alphonse"
    lint: "Alphonse"
  slow_checks:  # Only if fast checks pass
    tests: "Alphonse"
    integration: "Alphonse"
```

**Safety**: Independent checks, sequential stages.

### Unsafe Extensions (Avoid)

#### Parallel Planning
```
parallel_groups:
  planning:
    api_plan: "Senku"  ← May conflict
    db_plan: "Senku"   ← with integrated design
```

**Why unsafe**: Plans may need coordination.

#### Parallel Refactoring
```
parallel_groups:
  refactor:
    rename_variables: "Loid"  ← May conflict
    extract_functions: "Loid" ← with same code
```

**Why unsafe**: Refactorings may interfere.

## Related Documentation

- [Team Orchestration Architecture](../architecture/team-orchestration.md) - Parallel execution design
- [Evidence-Based Verification](evidence-based-verification.md) - Verification principles
- [Agent Specialization](agent-specialization.md) - Agent role boundaries
- [Using Team Orchestrate](../guides/using-team-orchestrate.md) - Practical usage
