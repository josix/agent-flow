# Refinement Scenarios

Worked examples demonstrating prompt refinement across common scenarios.

---

## Scenario 1: Completely Vague Request

**Input**: "Fix the app"

### Analysis

| Factor | Assessment |
|--------|------------|
| Target | Missing - no file, component, or feature |
| Outcome | Missing - no success criteria |
| Scope | Unknown |
| Ambiguity Score | 8 (Critical) |

### Refinement Process

**Step 1: Identify Primary Ambiguity**
- Cannot determine what "the app" refers to
- Cannot determine what "fix" means

**Step 2: Clarification Question**
```
Before I can help, I need to understand what issue you're experiencing:

What problem are you seeing?
A) An error or crash (please share the error message)
B) A feature not working as expected (which feature?)
C) Performance problems (what's slow?)
D) Something else (please describe)
```

**Step 3: User Response**
"B - the login button doesn't redirect properly"

**Step 4: Apply Template**

```
**Goal**: Fix the login button redirect functionality

**Description**: The login button is not redirecting users as expected after authentication. Need to investigate the redirect logic and fix the routing issue.

**Actions**:
1. Explore the login component and authentication flow
2. Identify where the redirect is triggered
3. Fix the redirect logic
4. Test the login flow end-to-end
5. Verify redirect works for all auth scenarios
```

---

## Scenario 2: Partially Clear Request

**Input**: "Add caching to the API"

### Analysis

| Factor | Assessment |
|--------|------------|
| Target | Partial - "the API" is broad |
| Outcome | Partial - "caching" is understood |
| Scope | Medium ambiguity |
| Ambiguity Score | 4 |

### Refinement Process

**Step 1: Assess Ambiguity**
- Clear intent: improve performance via caching
- Unclear: which endpoints, what cache strategy

**Step 2: Clarification Question**
```
I'll add caching to improve API performance. To proceed efficiently:

Which endpoints should have caching?
A) All GET endpoints (recommended for read-heavy APIs)
B) Specific endpoints (which ones?)
C) Only expensive/slow endpoints
D) Not sure - help me identify candidates
```

**Step 3: User Response**
"A - all GET endpoints"

**Step 4: Apply Template**

```
**Goal**: Implement response caching for all GET API endpoints

**Description**: Add a caching layer to improve response times for read operations. Will use HTTP cache headers and in-memory caching where appropriate. GET endpoints only, respecting cache invalidation on data changes.

**Actions**:
1. Explore existing API middleware and endpoint patterns
2. Plan caching strategy (TTL, invalidation, storage)
3. Implement caching middleware for GET requests
4. Add cache headers to responses
5. Test cache behavior and invalidation
```

---

## Scenario 3: Over-Specified Request

**Input**: "I need you to add validation to the email field in the signup form which is in src/components/SignupForm.tsx specifically the validateEmail function around line 45 to check for valid email format using regex like /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/ and show an error message saying 'Please enter a valid email address' and also prevent form submission if invalid"

### Analysis

| Factor | Assessment |
|--------|------------|
| Target | Over-specified - exact line numbers may be wrong |
| Outcome | Clear but verbose |
| Scope | Single field, single file |
| Ambiguity Score | 0 |

### Refinement Process

**Step 1: Assess**
- No clarification needed - intent is clear
- User provided too much implementation detail
- Refine to structured format without losing intent

**Step 2: Apply Template (synthesize, don't constrain)**

```
**Goal**: Add email validation to the signup form

**Description**: Implement email format validation for the SignupForm component. Display user-friendly error message for invalid emails and prevent submission until corrected.

**Actions**:
1. Locate email validation logic in SignupForm.tsx
2. Implement or enhance email format validation
3. Add appropriate error message display
4. Ensure form submission is blocked for invalid input
5. Test validation with valid and invalid email formats
```

**Note**: Implementation details (regex, exact wording) left to executor's judgment based on codebase patterns.

---

## Scenario 4: Compound Request

**Input**: "Review the auth module for security issues and then refactor it to use the new encryption library"

### Analysis

| Factor | Assessment |
|--------|------------|
| Tasks | Two distinct tasks: review + refactor |
| Dependency | Refactor depends on review findings |
| Scope | Single module, but two phases |
| Ambiguity Score | 3 |

### Refinement Process

**Step 1: Identify Task Relationship**
- Tasks are related (both affect auth module)
- Review should inform refactor decisions
- Treat as single phased task, not separate tasks

**Step 2: Apply Template**

```
**Goal**: Secure and modernize the authentication module

**Description**: First review the auth module for security vulnerabilities, then refactor to use the new encryption library. Review findings will guide refactoring priorities.

**Actions**:
1. Explore auth module structure and dependencies
2. Review for common security vulnerabilities (injection, weak crypto, etc.)
3. Document findings and prioritize issues
4. Plan encryption library migration
5. Implement refactoring with new encryption library
6. Re-verify security after changes
7. Test authentication flows end-to-end
```

---

## Scenario 5: Implicit Requirements

**Input**: "Make the login secure"

### Analysis

| Factor | Assessment |
|--------|------------|
| Target | Login - reasonably clear |
| Outcome | "Secure" - highly subjective |
| Implicit | What does "secure" mean to user? |
| Ambiguity Score | 5 |

### Refinement Process

**Step 1: Identify Implicit Requirements**
"Secure" could mean:
- Password hashing
- HTTPS enforcement
- Rate limiting
- CSRF protection
- Session management
- 2FA implementation

**Step 2: Clarification Question**
```
I'll improve login security. What's the primary concern?

A) Password security (hashing, requirements) - recommended baseline
B) Attack prevention (rate limiting, CSRF, brute force)
C) Session security (timeouts, token handling)
D) Add multi-factor authentication (2FA)
E) Full security audit (all of the above)
```

**Step 3: User Response**
"B - we're getting hit with brute force attempts"

**Step 4: Apply Template**

```
**Goal**: Implement brute force protection for the login system

**Description**: Add rate limiting and attack prevention measures to stop brute force login attempts. Focus on practical protections that don't impact legitimate users.

**Actions**:
1. Explore current login implementation and existing protections
2. Implement rate limiting (per IP and per account)
3. Add account lockout after failed attempts
4. Add CAPTCHA trigger after suspicious activity
5. Implement logging for failed attempts
6. Test protection effectiveness
```

---

## Scenario 6: Domain-Specific Refinement

**Input**: "Optimize the DAG execution"

### Analysis

| Factor | Assessment |
|--------|------------|
| Domain | Data pipeline / workflow (DAG = Directed Acyclic Graph) |
| Target | "The DAG" - need to identify which |
| Outcome | "Optimize" - need metric |
| Ambiguity Score | 5 |

### Refinement Process

**Step 1: Domain Context Check**
- Codebase appears to use Airflow for scheduling
- Multiple DAGs exist in `dags/` directory

**Step 2: Clarification Question**
```
I see several DAGs in the codebase. To optimize effectively:

Which DAG and what metric should I focus on?
A) data_pipeline DAG - reduce execution time
B) etl_daily DAG - reduce resource usage
C) reporting DAG - improve reliability
D) Specific DAG (please name it and the optimization goal)
```

**Step 3: User Response**
"A - data_pipeline is taking 3 hours and should take 1"

**Step 4: Apply Template**

```
**Goal**: Reduce data_pipeline DAG execution time from 3 hours to 1 hour

**Description**: Optimize the data_pipeline DAG to achieve 3x performance improvement. Analyze bottlenecks, identify parallelization opportunities, and optimize slow tasks.

**Actions**:
1. Profile current DAG execution to identify bottlenecks
2. Analyze task dependencies for parallelization opportunities
3. Optimize slowest tasks (query optimization, chunking)
4. Adjust resource allocation for compute-heavy tasks
5. Test optimizations with representative data
6. Verify execution time meets target
```

---

## Scenario 7: Non-Orchestration Detection

**Input**: "What does the calculateTotal function do?"

### Analysis

| Factor | Assessment |
|--------|------------|
| Type | Question, not task |
| Requires code change | No |
| Classification | Non-orchestration |

### Refinement Process

**Step 1: Detect Non-Orchestration**
- Starts with "What" (question word)
- Asking about existing code
- No code changes requested

**Step 2: Pass Through**
No refinement needed. Respond directly with explanation.

```
[Pass through - non-orchestration prompt]

Direct response: Read the function and explain its purpose.
```

---

## Scenario 8: Failed Clarification Recovery

**Input**: "Update the config"

### Analysis

| Factor | Assessment |
|--------|------------|
| Target | "The config" - which one? |
| Action | "Update" - to what values? |
| Ambiguity Score | 7 (High) |

### Refinement Process

**Step 1: Clarification Attempt**
```
There are several config files in this project. Which configuration do you need to update?

A) Application settings (config/app.json)
B) Database configuration (config/database.yml)
C) Environment variables (.env)
D) Build configuration (webpack.config.js)
```

**Step 2: No Response Received**
(User didn't respond after reasonable wait)

**Step 3: Default Behavior**
```
Since I haven't heard back, I'll examine the most commonly updated configuration.

Proceeding with assumption: You want to update application settings in config/app.json.

Let me know if you meant a different configuration file.
```

**Step 4: Apply Template with Assumption**

```
**Goal**: Update application configuration settings

**Description**: Modify config/app.json based on requirements. Assuming this is the target unless user specifies otherwise.

**Assumption**: Target is config/app.json (most common update target)

**Actions**:
1. Read current config/app.json contents
2. Identify what settings need updating (will ask user)
3. Make requested changes
4. Validate configuration format
5. Test application with new config
```

---

## Scenario 9: Progressive Refinement

**Input**: "Add a feature to export data"

### Analysis

| Factor | Assessment |
|--------|------------|
| Target | "Data" - which data? |
| Format | Export to what format? |
| Location | Where should export be triggered? |
| Ambiguity Score | 6 |

### Refinement Process

**Round 1: Data Type Clarification**
```
What data should the export include?

A) User data (profiles, settings)
B) Transaction/order history
C) Report data (analytics, metrics)
D) All user-related data (GDPR-style export)
```

Response: "B - transaction history"

**Round 2: Format Clarification**
```
What export format do you need?

A) CSV (spreadsheet-compatible) - recommended
B) JSON (developer-friendly)
C) PDF (formatted report)
D) Excel (.xlsx)
```

Response: "A - CSV"

**Step 3: Apply Template (after 2 rounds)**

```
**Goal**: Add transaction history CSV export feature

**Description**: Enable users to export their transaction history as a CSV file. Should include relevant transaction fields with proper formatting for spreadsheet use.

**Actions**:
1. Explore transaction data model and existing export patterns
2. Design CSV schema (columns, formatting)
3. Implement export endpoint/function
4. Add UI trigger for export (button/menu item)
5. Handle large exports (pagination/streaming)
6. Test export with various data volumes
```

---

## Scenario 10: Refinement-to-Classification Handoff

**Input**: "Add user notifications when their order ships"

### Analysis

| Factor | Assessment |
|--------|------------|
| Target | Clear - shipping notifications |
| Scope | Cross-cutting (orders, notifications, possibly email) |
| Ambiguity Score | 2 (Low) |

### Refinement Process

**Step 1: Minimal Clarification Needed**
- Intent is clear
- May benefit from one detail

**Step 2: Quick Confirmation**
```
I'll add shipping notifications for orders. Should these be:

A) Email notifications (recommended)
B) In-app notifications only
C) Both email and in-app
```

Response: "C - both"

**Step 3: Apply Template**

```
**Goal**: Implement order shipping notifications via email and in-app

**Description**: Notify users when their order ships through both email and in-app notification channels. Should trigger automatically when order status changes to "shipped".

**Actions**:
1. Explore order status change hooks and notification systems
2. Design notification content (email template, in-app message)
3. Implement shipping event listener
4. Add email notification trigger
5. Add in-app notification trigger
6. Test notification delivery for shipped orders
```

### Handoff to Task Classification

The refined specification is now ready for classification:

| Classification Signal | Value |
|----------------------|-------|
| Estimated files | 5-8 (orders, notifications, email, UI) |
| Complexity | Implementation (multi-component) |
| Risk level | Medium (affects user communication) |
| Verification | Required (email delivery, UI display) |

**Expected Classification**: Implementation task requiring full orchestration with Loid + Alphonse verification.

---

## Quick Classification Reference

| Scenario | Initial Ambiguity | Clarification Rounds | Final Output |
|----------|------------------|---------------------|--------------|
| Completely Vague | Critical (8) | 1 | Full specification |
| Partially Clear | Medium (4) | 1 | Full specification |
| Over-Specified | None (0) | 0 | Synthesized specification |
| Compound Request | Low (3) | 0 | Phased specification |
| Implicit Requirements | Medium (5) | 1 | Focused specification |
| Domain-Specific | Medium (5) | 1 | Domain-aware specification |
| Non-Orchestration | N/A | 0 | Pass through |
| Failed Clarification | High (7) | 1 (no response) | Default assumption |
| Progressive | Medium (6) | 2 | Detailed specification |
| Ready for Handoff | Low (2) | 1 (quick) | Classification-ready |

---

## See Also

- [SKILL.md](../SKILL.md) - Main prompt refinement documentation
- [refinement-techniques.md](../references/refinement-techniques.md) - Advanced techniques reference
