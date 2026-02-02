# Evidence-Based Verification

Understanding Agent Flow's verification philosophy: what constitutes proof, why claims aren't enough, and how the system enforces evidence requirements.

## The Verification Problem

In traditional software development, developers verify their own work before claiming completion. This works because humans have:
- Memory of what they actually did
- Ability to re-run commands and observe results
- Accountability for false claims

LLM agents lack these properties. They generate responses based on patterns, not memories of actions taken. An agent can claim "all tests pass" without ever running tests, simply because that's the expected response pattern.

## What Constitutes Evidence

Evidence in Agent Flow means **actual command output** that proves the claimed result.

### Valid Evidence

```text
Type Check: PASS
$ npx tsc --noEmit
(no output - clean compilation)

Tests: PASS
$ npm test
> project@1.0.0 test
> jest

PASS src/__tests__/auth.test.ts
PASS src/__tests__/user.test.ts
Test Suites: 2 passed, 2 total
Tests:       15 passed, 15 total

Lint: PASS
$ npm run lint
> project@1.0.0 lint
> eslint .

(no output - no lint errors)
```

### Invalid "Evidence"

```text
Type Check: PASS
(TypeScript compilation successful)

Tests: PASS
(All tests pass)

Lint: PASS
(No lint errors found)
```

The second example provides no evidence - just claims. The agent may never have run these commands.

## Evidence Requirements by Agent

### Loid (Executor)

Must provide:
- Actual verification command outputs
- Pass/fail counts with specifics
- Zero errors confirmed in output

**Required format:**
```text
Verification Complete

Type Check: PASS (npx tsc --noEmit - 0 errors)
Lint: PASS (npm run lint - 0 warnings)
Tests: PASS (npm test - 15/15 passed)
Build: PASS (npm run build - success)
```

### Alphonse (Verifier)

Must provide:
- Exact command outputs (not summaries)
- Full error messages for any failures
- Clear status for each verification gate

**Required format:**
```markdown
## Verification Results

### Tests
- Status: PASS
- Command: `npm test`
- Output:
  ```
  PASS src/__tests__/auth.test.ts (2.345s)
  PASS src/__tests__/user.test.ts (1.234s)

  Test Suites: 2 passed, 2 total
  Tests:       15 passed, 15 total
  Time:        3.579s
  ```

### Type Check
- Status: PASS
- Command: `npx tsc --noEmit`
- Output: (clean - no errors)

### Lint
- Status: PASS
- Command: `npm run lint`
- Output: (clean - no warnings)

### Build
- Status: PASS
- Command: `npm run build`
- Output:
  ```
  > project@1.0.0 build
  > tsc && vite build

  vite v5.0.0 building for production...
  dist/index.js   45.2 kB
  ```

### Overall: VERIFIED
```

### Riko (Explorer)

Must provide:
- File paths with line numbers for every claim
- Actual code snippets (not paraphrased)
- Clear source attribution

**Required format:**
```markdown
### Key Files
- `src/auth/login.ts:45-67` - Login handler with JWT generation
- `src/middleware/auth.ts:12-30` - Authentication middleware

### Code Evidence
```typescript
// From src/auth/login.ts:52-58
const token = jwt.sign(
  { userId: user.id, role: user.role },
  process.env.JWT_SECRET,
  { expiresIn: '24h' }
);
```
```

## The Evidence Hierarchy

Agent Flow evaluates evidence in order of trustworthiness:

```
Level 1: Actual command output
         └── Most trustworthy - verifiable

Level 2: File contents shown
         └── Trustworthy - can be verified

Level 3: Claims about files
         └── Less trustworthy - no verification

Level 4: General assertions
         └── Least trustworthy - accept only for exploration
```

### When Each Level is Acceptable

| Task Type | Minimum Evidence Level |
|-----------|----------------------|
| Verification | Level 1 (command output) |
| Implementation | Level 1 (command output) |
| Review | Level 2 (file contents) |
| Exploration | Level 3 (claims with paths) |
| Questions | Level 4 (general assertions) |

## Verification Gate Structure

Each verification gate requires specific evidence:

### Pre-Complete Gates

| Gate | Required Evidence |
|------|-------------------|
| Tests | Test runner output with pass/fail counts |
| Types | Type checker output (or "clean" with command shown) |
| Lint | Linter output (or "clean" with command shown) |
| Build | Build tool output showing success |

### Evidence Validation Rules

1. **Command must be shown**: Know what was run
2. **Output must be included**: See the actual result
3. **Errors must be zero**: No failures, no warnings treated as errors
4. **All gates must pass**: Partial verification is still failure

## Enforcing Evidence Requirements

### Agent Definitions

Every agent has evidence requirements in their system prompt:

```markdown
**ABSOLUTE PROHIBITION - READ THIS FIRST:**
- Do NOT claim "done" without ACTUAL verification output
- Do NOT say "I believe this works" - RUN THE COMMANDS
- Do NOT summarize - SHOW THE VERIFICATION OUTPUT
```

### Post-Task Verification Hook

After delegation, the orchestrator receives guidance:

```
Agent completed. Verify based on task type:
- Loid (implementation): READ changed files, RUN tests, CHECK types
- Alphonse (verification): Check test results
Only Loid tasks require full code verification.
```

### Stop Hook

Before task completion, verification script runs:
- Detects project type
- Runs appropriate test commands
- Reports pass/fail with evidence

## What Happens Without Evidence

When an agent provides claims without evidence:

1. **Orchestrator rejects completion**
   - Requests actual verification
   - Does not proceed to next phase

2. **Iteration cycle begins**
   - Agent must re-run commands
   - Provide actual output
   - Attempt verification again

3. **Max iterations enforced**
   - If evidence cannot be provided
   - Task fails with clear reason

## Evidence Anti-Patterns

### The Summary Trap

**Bad:**
```text
I ran the tests and they all passed. The type checker found no errors
and linting completed successfully.
```

**Good:**
```text
$ npm test
PASS src/auth.test.ts
Tests: 5 passed, 5 total

$ npx tsc --noEmit
(no output)

$ npm run lint
(no output)
```

### The Assumption Trap

**Bad:**
```text
Since I followed the existing patterns, the code should work correctly.
```

**Good:**
```text
Verification output:
$ npm test -- --testPathPattern=auth
PASS src/__tests__/auth.test.ts
  Authentication
    ✓ should generate valid JWT (45ms)
    ✓ should validate token (23ms)
```

### The Partial Evidence Trap

**Bad:**
```text
Tests pass:
$ npm test
PASS (15 tests)

Type checking and linting also pass.
```

**Good:**
```text
$ npm test
PASS (15/15 tests)

$ npx tsc --noEmit
(clean)

$ npm run lint
(clean)
```

## Building a Culture of Evidence

Evidence-based verification isn't about distrust - it's about reliability. When every claim is backed by proof:

1. **Bugs are caught early** - Before they reach production
2. **Confidence is justified** - "Verified" means verified
3. **Debugging is easier** - Evidence shows what was actually tested
4. **Quality is consistent** - Same standards, every time

## Related Concepts

- [The "Subagents LIE" Principle](subagents-lie.md) - Why verification matters
- [Agent Specialization](agent-specialization.md) - Why verification is separate
- [Verification Gates](../reference/hooks.md#stop) - Hook implementation
- [Agents Reference](../reference/agents.md) - Agent evidence requirements
