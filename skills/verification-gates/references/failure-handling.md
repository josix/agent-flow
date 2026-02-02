# Failure Handling

Comprehensive protocols for handling verification failures in the multi-agent orchestration system.

---

## 1. Failure Classification

### Failure Severity Levels

| Severity | Description | Action | Blocking |
|----------|-------------|--------|----------|
| CRITICAL | Security or data risk | Immediate stop | Yes |
| BLOCKING | Functionality broken | Stop, fix required | Yes |
| WARNING | Potential issue | Retry or document | Conditional |
| INFO | Non-critical notice | Log and continue | No |

### Failure Type Matrix

| Failure Type | Severity | Typical Cause | Primary Action |
|--------------|----------|---------------|----------------|
| Test Failure | BLOCKING | Code bug or test bug | Fix and re-run |
| Type Error | BLOCKING | Type mismatch, missing types | Resolve type issues |
| Lint Error | BLOCKING | Style violation, code smell | Auto-fix or manual |
| Build Failure | BLOCKING | Compilation error, missing dep | Fix source issue |
| Security Alert | CRITICAL | Credential exposure, vuln | Remove/rotate immediately |
| Timeout | WARNING | Slow tests, resource issue | Retry or optimize |
| Flaky Test | WARNING | Race condition, timing | Fix test stability |

---

## 2. Escalation Protocols

### Standard Escalation Path

```
Failure Detected
      |
      v
[Alphonse Reports] --> [Analyze Failure Type]
      |                       |
      +----> [Simple Fix?] ---+
             |               |
            YES              NO
             |               |
             v               v
      [Loid Fixes]    [Complex Issue?]
             |               |
             v               v
      [Re-verify]     [Escalate to Lawliet]
                             |
                             v
                      [Architecture Review]
```

### Escalation Decision Matrix

| Condition | Escalate To | Reason |
|-----------|-------------|--------|
| Single test failure | Loid | Simple code fix |
| Multiple related failures | Loid | Pattern issue |
| Type system conflicts | Loid + Lawliet | Architecture concern |
| Security vulnerability | Lawliet | Security review needed |
| Build system failure | Senku | May need redesign |
| Persistent flakiness | Lawliet | Root cause analysis |

---

## 3. Failure Response Protocols

### Test Failure Protocol

```
1. Capture full test output
2. Identify failing test(s)
3. Determine if failure is:
   a. Related to recent changes -> Fix code
   b. Pre-existing failure -> Document and investigate
   c. Test bug -> Fix test
4. Apply fix
5. Re-run verification
6. Document resolution
```

**Test Failure Checklist**:
- [ ] Full error output captured
- [ ] Failing test identified
- [ ] Root cause determined
- [ ] Fix applied
- [ ] Re-verification passed
- [ ] Resolution documented

### Type Error Protocol

```
1. Parse type error messages
2. Identify affected files and locations
3. Determine error category:
   a. Missing type definitions
   b. Type mismatch
   c. Null/undefined handling
   d. Generic type issues
4. Apply appropriate fix
5. Run type check again
6. Verify no cascading errors
```

**Type Error Categories and Fixes**:

| Error Pattern | Likely Fix |
|---------------|------------|
| "Property X does not exist" | Add property to interface |
| "Type X is not assignable to Y" | Fix type or add cast |
| "Object is possibly undefined" | Add null check |
| "Argument of type X" | Fix function signature or call |

### Lint Error Protocol

```
1. Review lint errors
2. Categorize by type:
   a. Auto-fixable -> Run auto-fix
   b. Manual fix needed -> Apply fix
   c. Rule exception needed -> Document and disable
3. Re-run lint
4. Verify no new errors introduced
```

**Auto-Fix Capabilities**:

| Issue Type | Auto-Fix Command | When Safe |
|------------|------------------|-----------|
| Formatting | `prettier --write` | Always |
| Import order | `eslint --fix` / `isort` | Always |
| Unused imports | `eslint --fix` | Usually |
| Spacing/indentation | `eslint --fix` | Always |
| Complex logic | Manual only | Never auto-fix |

### Build Failure Protocol

```
1. Capture full build output
2. Identify failure point
3. Common causes:
   a. Missing dependencies -> Install
   b. Syntax errors -> Fix source
   c. Configuration issues -> Fix config
   d. Version conflicts -> Resolve deps
4. Apply fix
5. Clean and rebuild
6. Verify build artifacts
```

---

## 4. Security Alert Handling

### Immediate Actions

When security alert detected:

```
CRITICAL: Security Alert Detected
      |
      v
1. STOP all other verification
      |
      v
2. Assess exposure risk
   - What was exposed?
   - Is it in version control?
   - Was it pushed to remote?
      |
      v
3. Remediate immediately
   - Remove sensitive data
   - Rotate credentials if needed
   - Update .gitignore
      |
      v
4. Document incident
      |
      v
5. Resume verification
```

### Sensitive File Patterns

Files that trigger security gate:

```
*.env
*.env.*
*credentials*
*secret*
*.pem
*.key
*id_rsa*
*id_ed25519*
*.p12
*.pfx
*password*
*token*
```

### Blocked Operations

Operations blocked without explicit approval:

- Committing files matching sensitive patterns
- Writing to system paths (`/etc/`, `/usr/`, `/var/`)
- Modifying authentication/authorization code
- Adding new external dependencies without review

---

## 5. Retry Strategies

### Automatic Retry Conditions

| Condition | Max Retries | Delay | Action |
|-----------|-------------|-------|--------|
| Timeout | 2 | 30s | Retry with extended timeout |
| Flaky test | 3 | 5s | Retry immediately |
| Network error | 3 | 10s | Retry with backoff |
| Resource limit | 1 | 60s | Wait and retry |

### Retry Decision Logic

```
function shouldRetry(failure):
    if failure.type == SECURITY:
        return false  # Never retry security failures

    if failure.retryCount >= failure.maxRetries:
        return false  # Exhausted retries

    if failure.type in [TIMEOUT, FLAKY, NETWORK]:
        return true   # Retriable failures

    return false      # Other failures need fixing
```

### Flaky Test Handling

```
1. Run test 3 times
2. Track pass/fail pattern
3. If inconsistent (some pass, some fail):
   a. Mark as flaky
   b. Report to user
   c. Suggest fix approaches
4. If consistently fails:
   a. Treat as real failure
   b. Require fix
```

---

## 6. Recovery Procedures

### After Test Fix

```
1. Run failing test in isolation
2. Run related test file
3. Run full test suite
4. Verify no regressions
```

### After Type Fix

```
1. Run type check on changed files
2. Run full type check
3. Verify no new type errors
4. Check for runtime implications
```

### After Build Fix

```
1. Clean build artifacts
2. Fresh install dependencies
3. Run full build
4. Verify build outputs
5. Run tests against build
```

---

## 7. Documentation Requirements

### Failure Documentation Format

```
## Verification Failure Report

### Failure Details
- Type: [Test/Type/Lint/Build/Security]
- Severity: [CRITICAL/BLOCKING/WARNING]
- Time: [timestamp]
- Command: [command that failed]

### Error Output
[Full error message]

### Root Cause
[Analysis of why it failed]

### Resolution
[What was done to fix it]

### Prevention
[How to prevent similar failures]
```

### When Documentation Required

- All CRITICAL failures
- BLOCKING failures taking > 30 minutes to resolve
- Recurring failures (3+ times)
- Failures requiring architecture changes

---

## 8. Override Procedures

### When Overrides Are Permitted

Verification can ONLY be skipped when:

1. **User explicitly requests skip** - Must be documented
2. **No code changes were made** - Documentation-only tasks
3. **Task is purely exploratory** - No production impact

### Override Documentation Required

```
## Verification Override

Reason: [Explicit reason for skipping]
Requested by: [User or escalation source]
Risk Assessment: [Low/Medium/High]
Compensating Controls: [What will catch issues later]
Approval: [Who approved the override]
```

### Override Audit Trail

All overrides must be:
- Logged with timestamp
- Associated with task/commit
- Reviewable by team leads
- Subject to periodic audit

---

## See Also

- [SKILL.md](../SKILL.md) - Main verification gates documentation
- [verification-commands.md](verification-commands.md) - Complete command reference
- [project-detection.md](project-detection.md) - Project type detection
