# Verification Scenarios

Worked examples demonstrating verification gate application in common development situations.

---

## Scenario 1: Simple Bug Fix (Pre-Commit Only)

**Task:** Fix a typo in an error message in `src/utils/validator.ts`

**Change Scope:** 1 file, 1 line changed

### Verification Applied

```
Gate Type: Pre-Commit
Checks Run:
  - Lint (affected file): PASS
  - Format check: PASS
  - Related tests: PASS (validator.test.ts)

Full Pre-Complete: SKIPPED (trivial change)
```

### Alphonse Output

```
## Verification Results

### Tests
- Status: PASS
- Output: 3 tests passed (validator.test.ts)

### Lint
- Status: PASS
- Warnings: 0

### Overall: VERIFIED
```

**Verdict:** Task complete. Single-file typo fix requires only pre-commit gates.

---

## Scenario 2: New Feature (Full Verification)

**Task:** Add user authentication endpoint with JWT token generation

**Change Scope:** 5 files (route, service, middleware, types, tests)

### Verification Applied

```
Gate Type: Pre-Complete (Full Suite)
Checks Run:
  - All tests: 142 passed, 0 failed
  - Type check: 0 errors
  - Lint: 0 errors, 2 warnings (allowed)
  - Build: Successful
```

### Alphonse Output

```
## Verification Results

### Tests
- Status: PASS
- Output: 142 tests passed (8 new tests for auth module)

### Type Check
- Status: PASS
- Errors: None

### Lint
- Status: PASS
- Warnings: 2 (line length in comments - allowed)

### Build
- Status: PASS
- Issues: None

### Overall: VERIFIED
```

**Verdict:** Task complete. New feature requires full verification suite.

---

## Scenario 3: Security-Sensitive Change

**Task:** Update password hashing algorithm from bcrypt rounds 10 to 12

**Change Scope:** 2 files (auth service, config)

### Verification Applied

```
Gate Type: Security Gate + Pre-Complete
Checks Run:
  - Credential scan: PASS (no secrets in code)
  - Permission check: PASS (auth code reviewed)
  - Dependency audit: PASS (npm audit clean)
  - Full test suite: PASS
  - Type check: PASS
```

### Security Gate Details

```
Security Scan Results:
  - Scanned files: 2
  - Patterns checked: *.env, *secret*, *key*, *password*
  - Hardcoded credentials: None found
  - Sensitive data exposure: None detected
```

### Alphonse Output

```
## Verification Results

### Security
- Status: PASS
- Audit: No vulnerabilities found

### Tests
- Status: PASS
- Output: Auth tests passed, timing verified

### Overall: VERIFIED
```

**Verdict:** Task complete with security gate approval.

---

## Scenario 4: Flaky Test Handling

**Task:** Add retry logic to API client

**Initial Verification:** Test failed intermittently

### First Attempt

```
## Verification Results

### Tests
- Status: FAIL
- Output: api-client.test.ts - "should retry on 503" failed
  - Expected: 3 retries
  - Received: 2 retries (timing issue)

### Overall: FAILED
```

### Resolution Process

1. **Alphonse identifies flakiness:** Test passed on retry (2/3 runs)
2. **Escalate to Loid:** Review test implementation
3. **Fix applied:** Added proper async waiting in test
4. **Re-verification:** 3/3 passes

### Final Output

```
## Verification Results

### Tests
- Status: PASS
- Output: 45 tests passed (flaky test fixed)
- Notes: api-client.test.ts now stable

### Overall: VERIFIED
```

**Verdict:** Task complete after flaky test fix.

---

## Scenario 5: Type Error Resolution

**Task:** Refactor user service to use new UserDTO type

**Initial Verification:** Type check failed

### First Attempt

```
## Verification Results

### Type Check
- Status: FAIL
- Errors:
  src/services/user.service.ts:45 - Property 'email' is missing in type 'UserDTO'
  src/services/user.service.ts:52 - Type 'string | undefined' not assignable to 'string'

### Overall: FAILED
```

### Resolution Process

1. **Loid reviews errors:** Missing required property, undefined handling
2. **Fix applied:**
   - Added `email` to UserDTO interface
   - Added null coalescing for optional fields
3. **Re-verification requested**

### Final Output

```
## Verification Results

### Type Check
- Status: PASS
- Errors: None

### Tests
- Status: PASS
- Output: All 89 tests passed

### Overall: VERIFIED
```

**Verdict:** Task complete after type fixes.

---

## Scenario 6: Build Failure Recovery

**Task:** Upgrade React from 17 to 18

**Initial Verification:** Build failed

### First Attempt

```
## Verification Results

### Build
- Status: FAIL
- Issues:
  - Module not found: 'react-dom/client'
  - 15 TypeScript errors in component files
  - Deprecated API usage warnings

### Overall: FAILED
```

### Resolution Process

1. **Alphonse provides full error log**
2. **Loid identifies issues:**
   - Missing `@types/react@18`
   - createRoot API change
   - StrictMode children type change
3. **Fixes applied in stages:**
   - Update type definitions
   - Migrate createRoot calls
   - Fix component type signatures
4. **Incremental verification after each stage**

### Final Output

```
## Verification Results

### Build
- Status: PASS
- Issues: None

### Type Check
- Status: PASS
- Errors: None (after type definition update)

### Tests
- Status: PASS
- Output: 234 tests passed

### Overall: VERIFIED
```

**Verdict:** Task complete after systematic build fixes.

---

## Scenario 7: Override Documentation Example

**Task:** Update README with new API documentation

**Change Scope:** Documentation only (README.md)

### Verification Override

```
## Verification Override

Reason: Documentation-only change with no code modifications
Requested by: Task classification identified as non-code task
Risk Assessment: Low - no production code affected
Compensating Controls: Manual review of markdown rendering
```

### Alphonse Output

```
## Verification Results

### Code Verification
- Status: SKIPPED
- Reason: Documentation-only task (override applied)

### Checks Performed
- File type: Markdown (.md)
- Code blocks: Syntax validated
- Links: Not checked (manual review)

### Overall: VERIFIED (with override)
```

**Verdict:** Task complete with documented override.

---

## Quick Classification Reference

| Scenario | Gate Type | Key Checks | Typical Duration |
|----------|-----------|------------|-----------------|
| Typo fix | Pre-Commit | Lint, related tests | 30s |
| New feature | Pre-Complete | Full suite, types, build | 5-10min |
| Security change | Security + Pre-Complete | Audit, scan, full suite | 10-15min |
| Flaky test | Pre-Complete + Retry | Tests with retry logic | 5-15min |
| Type refactor | Pre-Complete | Type check focus | 2-5min |
| Build upgrade | Pre-Complete | Build, types, tests | 10-20min |
| Docs only | Override | Markdown validation | 10s |

---

## See Also

- [SKILL.md](../SKILL.md) - Main verification gates documentation
- [verification-commands.md](../references/verification-commands.md) - Complete command reference
