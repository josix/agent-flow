---
name: verification-gates
description: This skill should be used when handling verification steps, quality gates, pre-commit checks, test failures, lint errors, build verification, or mandatory validation before task completion.
---

# Verification Gates

## Overview

Verification gates are mandatory quality checkpoints that must pass before any implementation work is considered complete. These gates prevent broken code from being committed, ensure type safety, maintain code style consistency, and validate that all tests pass.

**Owner Agent**: Alphonse (Verifier Agent)

### Key Principles

1. **Non-Negotiable Quality**: Every code change must pass all applicable gates
2. **Automated Enforcement**: Gates are triggered automatically via hooks
3. **Clear Feedback**: Failures provide actionable error messages
4. **Project-Aware**: Commands adapt to detected project type and tooling
5. **Fail-Fast, Fix-First**: When any gate fails, work stops until resolved

### Verification Hierarchy

```
Loid (Executor)          Alphonse (Verifier)
     |                         |
Quick sanity tests       Full verification gate
during implementation    before completion
     |                         |
     +----------> Handoff >----+
```

---

## Gate Types

### Pre-Commit Gates

| Check | Example Command | Timeout |
|-------|-----------------|---------|
| Lint | `npm run lint` / `ruff check` | 30s |
| Format | `npm run format:check` / `black --check` | 15s |
| Quick Tests | Changed file tests only | 60s |

### Pre-Complete Gates

| Check | Example Command | Timeout |
|-------|-----------------|---------|
| Full Test Suite | `npm test` / `pytest` | 300s |
| Type Checking | `npx tsc --noEmit` / `mypy .` | 120s |
| Linting | Full codebase lint | 60s |
| Build | `npm run build` / `python -m build` | 180s |

### Security Gates

Triggered by changes to sensitive files or security-critical code:

| Check | Trigger | Action |
|-------|---------|--------|
| Credential Scan | `*.env`, `*secret*`, `*.key` | Block + Alert |
| Permission Check | Auth/ACL code | Require review |
| Dependency Audit | Package files | `npm audit` / `pip-audit` |

---

## Verification Commands

### Quick Reference by Language

| Action | Node.js | Python | Go | Rust |
|--------|---------|--------|----|----|
| Test | `npm test` | `pytest` | `go test ./...` | `cargo test` |
| Types | `npx tsc --noEmit` | `mypy .` | `go build` | `cargo check` |
| Lint | `npm run lint` | `ruff check .` | `golangci-lint run` | `cargo clippy` |
| Build | `npm run build` | `python -m build` | `go build` | `cargo build` |

For complete command reference, see [references/verification-commands.md](references/verification-commands.md).

---

## Verification Process

### Alphonse Verification Steps

1. Identify project type (Node.js, Python, Go, Rust, Java)
2. Run test suite with appropriate framework
3. Execute type checking if configured
4. Run linters if present
5. Attempt production build
6. Report structured results

### Standard Output Format

```
## Verification Results

### Tests
- Status: [PASS | FAIL]
- Output: [Summary of test execution]

### Type Check
- Status: [PASS | FAIL | SKIPPED]
- Errors: [List of type errors if any]

### Lint
- Status: [PASS | FAIL | SKIPPED]
- Warnings: [Count and summary]

### Build
- Status: [PASS | FAIL | SKIPPED]
- Issues: [Build errors if any]

### Overall: [VERIFIED | FAILED]
```

---

## Failure Handling

### Failure Severity

| Type | Severity | Action |
|------|----------|--------|
| Test Failure | BLOCKING | Fix and re-run |
| Type Error | BLOCKING | Resolve types |
| Lint Error | BLOCKING | Auto-fix or manual |
| Build Failure | BLOCKING | Fix compilation |
| Security Alert | CRITICAL | Immediate remediation |
| Timeout | WARNING | Retry once |
| Flaky Test | WARNING | Retry 3x, then fix |

### Escalation Path

```
Alphonse Reports -> Loid Reviews
     |                   |
Simple Fix?         Complex Issue?
     |                   |
    YES                  NO
     |                   |
Loid Fixes      Escalate to Lawliet
     |                   |
Re-verify       Architecture Review
```

For detailed failure protocols, see [references/failure-handling.md](references/failure-handling.md).

---

## Best Practices

### DO

- Run verification after every significant change
- Fix failures immediately
- Trust Alphonse's verdict
- Add tests for new features
- Run full suite before PR

### DON'T

- Skip verification to save time
- Suppress type errors with `any`
- Disable lint rules without justification
- Commit with failing tests
- Use `--no-verify` flag
- Mark tasks complete without verification

---

## Gate Selection Guide

| Scenario | Gate Type | Checks Run |
|----------|-----------|------------|
| Small code fix | Pre-Commit | Lint, format, affected tests |
| New feature complete | Pre-Complete | Full suite, types, lint, build |
| Security-related change | Security | Credential scan, audit, permissions |
| Cross-service change | Integration | E2E, contracts, compatibility |

---

## Override Rules

Verification gates can ONLY be skipped when:

1. **User explicitly requests skip** - Must be documented
2. **No code changes were made** - Documentation-only tasks
3. **Task is purely exploratory** - No production impact

**Override Documentation Required**:
```
## Verification Override

Reason: [Explicit reason for skipping]
Requested by: [User or escalation source]
Risk Assessment: [Low/Medium/High]
Compensating Controls: [What will catch issues later]
```

---

## Additional Resources

### Reference Files

- [references/verification-commands.md](references/verification-commands.md) - Complete command reference
- [references/project-detection.md](references/project-detection.md) - Project type detection details
- [references/failure-handling.md](references/failure-handling.md) - Failure handling protocols

### Examples

- [examples/verification-scenarios.md](examples/verification-scenarios.md) - Worked verification examples

### Related Files

| File | Purpose |
|------|---------|
| `scripts/load-project-context.sh` | Project type detection |
| `hooks/scripts/verify-completion.sh` | Pre-complete gate implementation |
| `hooks/scripts/validate-changes.sh` | Security validation |
| `agents/Alphonse.md` | Verifier agent definition |

### Related Skills

- **task-classification**: Determines when verification is required
- **agent-behavior-constraints**: Model routing and tool access
