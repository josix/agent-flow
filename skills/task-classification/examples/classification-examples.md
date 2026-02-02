# Classification Examples

This document provides worked examples of task classification to illustrate proper decision-making.

---

## Example 1: Trivial Task

### Request
> "What does the `calculateTotal` function in utils.ts do?"

### Analysis
- **Action**: Explain (read-only)
- **Files Affected**: 0 (no changes)
- **Risk Level**: None (no modifications)
- **Dependencies**: None

### Classification
**Trivial** - Direct response, no agent delegation

### Reasoning
This is a simple question about existing code. No files will be modified, and the answer can be provided directly by reading the file.

---

## Example 2: Exploratory Task

### Request
> "Find all places where we call the payments API and show me how error handling works"

### Analysis
- **Action**: Find, trace (read-only investigation)
- **Files Affected**: N/A (read-only)
- **Risk Level**: Low
- **Scope**: Multiple files to search

### Classification
**Exploratory** - Delegate to Riko

### Agent Assignment
- **Primary**: Riko (Explorer)
- **Tools Used**: Grep, Glob, Read
- **Verification**: Not required

### Reasoning
The user wants to understand existing code patterns. This requires searching across the codebase but does not involve any modifications.

---

## Example 3: Implementation Task

### Request
> "Add a new endpoint `/api/users/preferences` that returns user notification preferences"

### Analysis
- **Action**: Add (new code)
- **Files Affected**: ~4 files
  - Route definition (1)
  - Controller/handler (1)
  - Service layer (1)
  - Tests (1)
- **Risk Level**: Medium
- **Dependencies**: Existing user model, existing auth middleware

### Classification
**Implementation** - Loid with Alphonse verification

### Agent Assignment
- **Primary**: Loid (Executor)
- **Verification**: Alphonse (test execution)
- **Tools Used**: Edit, Write, Bash

### Verification Requirements
```bash
npm test -- --grep "preferences"
npm run lint
npx tsc --noEmit
```

### Reasoning
This is a bounded feature with clear scope. It affects multiple files but stays within one domain (user preferences). Standard implementation with test verification is appropriate.

---

## Example 4: Complex Task

### Request
> "Migrate our user authentication from session-based to JWT tokens"

### Analysis
- **Action**: Migrate (fundamental change)
- **Files Affected**: 15+ files
  - Auth middleware (2-3)
  - Login/logout handlers (2)
  - Token generation/validation (2-3)
  - All protected routes (5+)
  - Tests (3+)
  - Configuration (2)
- **Risk Level**: Critical
- **Dependencies**: All authenticated endpoints
- **Breaking Changes**: Yes (session invalidation)

### Classification
**Complex** - Full orchestration required

### Agent Assignment
1. **Riko**: Map all session usage locations
2. **Senku**: Create migration plan with phases
3. **Loid**: Implement changes incrementally
4. **Lawliet**: Security review of JWT implementation
5. **Alphonse**: Full test suite execution

### Verification Requirements
```bash
npm test                    # Full test suite
npm run test:integration    # Integration tests
npm run lint
npx tsc --noEmit
# Manual testing checklist for auth flows
```

### Reasoning
Authentication changes are always high-risk with wide blast radius. This affects every authenticated endpoint and requires careful security review.

---

## Example 5: Research Task

### Request
> "What's the best way to implement rate limiting in Node.js? Research the options and recommend one for our API"

### Analysis
- **Action**: Research (external information)
- **Files Affected**: N/A (research phase)
- **Risk Level**: Low
- **External Info Required**: Yes

### Classification
**Research** - Riko with WebSearch

### Agent Assignment
- **Primary**: Riko (Explorer) with WebSearch
- **Output**: Recommendation document

### Reasoning
The user needs external information about best practices. Riko can combine codebase knowledge (our current setup) with web research to provide recommendations.

---

## Example 6: Edge Case - "Simple" Language

### Request
> "Just add a `createdBy` field to the Order model"

### Initial Impression
User says "just" - sounds trivial.

### Actual Analysis
- **Action**: Add field (schema change)
- **Files Affected**: 6+ files
  - Model definition (1)
  - Migration script (1)
  - API serializers (1-2)
  - Tests (2+)
  - Possibly UI if displaying
- **Risk Level**: High (database schema change)
- **Dependencies**: All order-related code

### Classification
**Complex** - Despite "just" language

### Reasoning
Database schema changes are always high-risk. The word "just" masks the actual complexity. This requires:
- Migration planning
- Backward compatibility consideration
- All order-related code updates
- Comprehensive testing

---

## Example 7: Compound Request

### Request
> "Find where we handle payment webhooks, then add logging for failed payments"

### Analysis
- **Component 1**: Find payment webhook handlers (Exploratory)
- **Component 2**: Add logging (Implementation)
- **Combined Scope**: Implementation (higher of the two)

### Classification
**Implementation** - Two-phase execution

### Execution Plan
1. **Phase 1 (Riko)**: Locate payment webhook handlers
2. **Phase 2 (Loid)**: Add logging to identified locations
3. **Phase 3 (Alphonse)**: Verify tests pass

### Reasoning
Compound requests use the highest component classification. The implementation phase is the more complex part.

---

## Example 8: Re-classification Scenario

### Initial Request
> "Update the error message in the login form"

### Initial Classification
**Trivial** - Single file, localized change

### During Implementation
Loid discovers:
- Error messages are centralized in an i18n file
- There are 3 different login-related error messages
- The error message format is used across 8 components
- Changing format would require updating all usages

### Re-classification
**Implementation** - Scope expanded

### New Agent Assignment
- Continue with Loid
- Add Alphonse verification
- Consider if format change is needed

### Reasoning
What appeared trivial revealed broader impact. Re-classification up to Implementation ensures proper verification.

---

## Example 9: Security-Sensitive Feature

### Request
> "Add a password reset feature"

### Analysis
- **Action**: Add feature
- **Files Affected**: 5-8 files
- **Risk Level**: Critical (security-sensitive)
- **Override Condition**: Security feature = Always Complex

### Classification
**Complex** - Security override applies

### Required Verification
- Alphonse: Full test suite
- Lawliet: Security review for:
  - Token generation security
  - Token expiration handling
  - Rate limiting on reset requests
  - Email security (no user enumeration)
  - Password strength validation

### Reasoning
Even though file count suggests Implementation, the security-sensitive nature triggers the override condition forcing Complex classification.

---

## Example 10: Performance Optimization

### Request
> "The user list page is slow. Optimize the database queries."

### Analysis Phase (Riko)
Exploration reveals:
- Single N+1 query issue
- Affects 2 files (repository, service)
- Existing tests cover the functionality

### Classification
**Implementation** - Bounded optimization

### If Riko Had Found
- Multiple query issues across 10+ files
- Need for caching layer
- Index additions required

### Alternate Classification
**Complex** - Broader optimization needed

### Reasoning
Initial investigation determines final classification. Simple query fix = Implementation. Architectural changes = Complex.

---

## Quick Classification Reference

| Request Pattern | Classification | Agent(s) |
|-----------------|----------------|----------|
| "What does X do?" | Trivial | Direct |
| "Find all uses of X" | Exploratory | Riko |
| "Add feature Y" (2-5 files) | Implementation | Loid -> Alphonse |
| "Refactor X across the codebase" | Complex | Full orchestration |
| "Research best practices for X" | Research | Riko + WebSearch |
| "Fix this bug in file X" | Implementation | Loid -> Alphonse |
| "Migrate from X to Y" | Complex | Full orchestration |
| Anything with auth/security | Complex | Full + Lawliet review |
| Database schema changes | Complex | Full + migration review |

---

*See also: `../references/classification-heuristics.md` for detailed heuristics*
