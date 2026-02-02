# Exploration Scenarios

Worked examples demonstrating exploration strategies in practice.

## Scenario 1: Bug Fix in Unfamiliar Codebase

### Task
Fix a "TypeError: undefined is not a function" error in the checkout process.

### Exploration Strategy: Targeted + Breadth-First

**Phase 1: Find the error (Targeted)**
```
Grep: "checkout" in error logs or stack trace
Result: Error in src/checkout/payment.ts:45
```

**Phase 2: Understand context (Breadth-First)**
```
Parallel searches:
  - Read: src/checkout/payment.ts
  - Glob: src/checkout/**/*.ts
  - Grep: imports of payment.ts

Found:
  - payment.ts imports from src/services/stripe.ts
  - Error on line 45: stripeService.createPayment()
  - stripeService might be undefined
```

**Phase 3: Root cause (Depth-First)**
```
Read: src/services/stripe.ts
Read: src/checkout/index.ts (initialization)

Found:
  - stripeService initialized conditionally
  - Missing null check before use
```

**Summary for Handoff:**
```
Bug: stripeService used without null check
Location: src/checkout/payment.ts:45
Root cause: Conditional initialization in checkout/index.ts
Fix: Add null check or ensure initialization
Affected tests: src/checkout/__tests__/payment.test.ts
```

---

## Scenario 2: Adding a New Feature

### Task
Add email notification when order ships.

### Exploration Strategy: Breadth-First + Targeted

**Phase 1: Find similar features**
```
Parallel searches:
  - Grep: "notification" in src/
  - Grep: "email" in src/
  - Glob: **/notifications/**

Found:
  - src/notifications/email.ts (email service)
  - src/notifications/templates/ (email templates)
  - src/orders/events.ts (order events)
```

**Phase 2: Understand the pattern**
```
Read: src/notifications/email.ts
Read: src/notifications/templates/orderConfirmation.ts
Read: src/orders/events.ts

Pattern identified:
  - Email service with send() method
  - Templates as TypeScript functions
  - Events trigger notifications via listener
```

**Phase 3: Find integration points**
```
Grep: "orderShipped" or "ship" in src/orders/
Read: src/orders/shipping.ts

Found:
  - markAsShipped() function exists
  - Emits ORDER_SHIPPED event
  - No notification listener for this event
```

**Summary for Handoff:**
```
Implementation approach:
1. Create template: src/notifications/templates/orderShipped.ts
   Pattern: Follow orderConfirmation.ts structure

2. Add listener: src/orders/events.ts
   On ORDER_SHIPPED -> send shipping notification email

3. Test: src/orders/__tests__/shipping.test.ts
   Add test for notification on ship

Files to modify: 3
New files: 1
Pattern: Event-driven notification like order confirmation
```

---

## Scenario 3: Refactoring Shared Utility

### Task
Refactor date formatting utility used across the codebase.

### Exploration Strategy: Comprehensive Search

**Phase 1: Find all usages**
```
Grep: "formatDate" in src/
Grep: import.*dateUtils in src/

Found: 47 usages across 23 files
```

**Phase 2: Categorize usages**
```
Read: Sample of 5-6 files with formatDate

Categories found:
  - Display formatting: formatDate(date, 'display')
  - API formatting: formatDate(date, 'iso')
  - Relative formatting: formatDate(date, 'relative')
```

**Phase 3: Map test coverage**
```
Glob: **/dateUtils.test.ts
Read: src/utils/__tests__/dateUtils.test.ts

Found:
  - Tests cover basic cases
  - Missing edge case tests for timezone
  - No tests for relative formatting
```

**Phase 4: Identify breaking changes**
```
Grep: formatDate.*options in src/

Found:
  - 12 files pass options object
  - Options structure varies slightly
  - Need backward compatibility
```

**Summary for Handoff:**
```
Refactoring scope:
- 23 files use formatDate
- 47 total usages
- 3 usage patterns (display, iso, relative)

Breaking change risk: Medium
- 12 files use options object
- Need to maintain backward compatibility

Test gaps:
- Missing timezone tests
- Missing relative format tests

Recommended approach:
1. Add new function with clean API
2. Deprecate old function (keep working)
3. Migrate usages incrementally
4. Add missing tests first

Files requiring changes: 23
New files: 0
Estimated complexity: High (cross-cutting)
```

---

## Scenario 4: Understanding New Codebase

### Task
Understand how authentication works in this project.

### Exploration Strategy: Pure Breadth-First

**Phase 1: Find auth-related files**
```
Parallel searches:
  - Glob: **/*auth*/**
  - Glob: **/*login*/**
  - Grep: "authenticate" in src/
  - Grep: "session" in src/

Found structure:
  - src/auth/ (main auth module)
  - src/middleware/auth.ts
  - src/api/auth/ (auth endpoints)
```

**Phase 2: Read entry points**
```
Read: src/auth/index.ts
Read: src/middleware/auth.ts
Read: src/api/auth/login.ts

Architecture found:
  - JWT-based authentication
  - Middleware validates tokens
  - Refresh token rotation
  - Sessions stored in Redis
```

**Phase 3: Map dependencies**
```
Grep: import.*from.*auth in src/

Dependencies:
  - 34 files import from auth module
  - Critical in: api/, middleware/, components/
```

**Summary for Handoff:**
```
Authentication architecture:
- Type: JWT with refresh tokens
- Storage: Redis for sessions
- Entry: src/auth/index.ts
- Middleware: src/middleware/auth.ts
- Endpoints: src/api/auth/

Key files to read for full understanding:
1. src/auth/jwt.ts - Token generation/validation
2. src/auth/session.ts - Session management
3. src/middleware/auth.ts - Request authentication
4. src/api/auth/login.ts - Login flow
5. src/api/auth/refresh.ts - Token refresh

Dependencies: 34 files depend on auth module
```

---

## Scenario 5: Quick Fix with Known Location

### Task
Update error message in src/components/Form.tsx line 23.

### Exploration Strategy: Minimal (Depth-First only)

**Phase 1: Read target file**
```
Read: src/components/Form.tsx

Found:
  - Line 23: error message "Invalid input"
  - Used in validation function
  - No translations (hardcoded string)
```

**Phase 2: Check for related**
```
Grep: "Invalid input" in src/

Found:
  - Only occurrence is in Form.tsx
  - No i18n to update
```

**Phase 3: Check tests**
```
Read: src/components/__tests__/Form.test.tsx

Found:
  - Test on line 45 checks for "Invalid input"
  - Will need to update test too
```

**Summary for Handoff:**
```
Simple change:
- File: src/components/Form.tsx:23
- Also: src/components/__tests__/Form.test.tsx:45

No other occurrences.
No i18n needed.
Two files to update.
```

---

## Exploration Anti-Pattern Examples

### Anti-Pattern 1: Reading Without Direction

**Bad:**
```
Read: package.json
Read: tsconfig.json
Read: README.md
Read: src/index.ts
Read: src/app.ts
... (continues reading randomly)
```

**Good:**
```
Task: Fix login bug
Grep: "login" in src/
Read: Most relevant results first
Stop: When understand login flow
```

### Anti-Pattern 2: Sequential When Parallel Possible

**Bad:**
```
Grep: "UserService"
[wait for result]
Grep: "AuthService"
[wait for result]
Grep: "SessionService"
[wait for result]
```

**Good:**
```
Parallel:
  - Grep: "UserService"
  - Grep: "AuthService"
  - Grep: "SessionService"
[receive all results together]
```

### Anti-Pattern 3: Exploring Beyond Task Scope

**Bad:**
```
Task: Update button color
Explored: Entire component library
Explored: CSS architecture
Explored: Theme system
Explored: Design tokens
... (30 minutes later, still exploring)
```

**Good:**
```
Task: Update button color
Read: src/components/Button.tsx
Grep: buttonColor or primaryColor
Read: src/styles/theme.ts
Done: Found where to change (3 minutes)
```
