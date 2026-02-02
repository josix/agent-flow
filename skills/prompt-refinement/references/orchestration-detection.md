# Orchestration Detection

Reference for identifying which prompts require refinement for multi-agent orchestration versus those that should pass through unchanged.

---

## 1. Orchestration-Related Prompts

Prompts that SHOULD be refined for orchestration:

| Category | Indicators | Example |
|----------|------------|---------|
| Multi-file changes | Multiple components affected | "Add authentication to all API routes" |
| Feature implementations | New capability creation | "Implement dark mode toggle" |
| Bug fixes requiring investigation | Unknown root cause | "Fix the login issue users are reporting" |
| Refactoring tasks | Code structure changes | "Refactor the user service for better testability" |
| Integration work | Connecting systems | "Integrate Stripe for payments" |
| Performance optimization | Requires profiling and changes | "Optimize the dashboard load time" |
| Architecture changes | Structural modifications | "Convert to microservices" |
| Security implementations | Auth, permissions, encryption | "Add role-based access control" |
| Database changes | Schema, migrations | "Add a new field to the user table" |
| Cross-service coordination | Multiple services affected | "Update API to support v2 clients" |

---

## 2. Non-Orchestration Prompts

Prompts that should PASS THROUGH unchanged:

| Category | Indicators | Example |
|----------|------------|---------|
| Simple questions | "What", "Why", "How" | "What does the calculateTotal function do?" |
| Information requests | Asking about existing code | "Show me the User model" |
| Single-file explicit edits | File path specified, small scope | "Add a comment to line 42 in app.ts" |
| Git operations | Version control commands | "Commit these changes" |
| Documentation lookups | Reference queries | "What are the API endpoints?" |
| Configuration reads | Checking settings | "What's the current rate limit?" |
| Explanation requests | Understanding code | "Explain this regex" |
| Direct commands | Clear, bounded operations | "Run the tests" |
| Status checks | Current state queries | "Is the build passing?" |

---

## 3. Detection Decision Tree

```
Is this a question about existing code?
├── YES -> Pass through (non-orchestration)
└── NO -> Continue
         |
         Does it require code changes?
         ├── NO -> Pass through (non-orchestration)
         └── YES -> Continue
                   |
                   Is target file explicitly specified AND scope is single file?
                   ├── YES -> Pass through (simple edit)
                   └── NO -> Refine for orchestration
```

---

## 4. Question Word Analysis

### Non-Orchestration Triggers

| Question Word | Usually Means | Orchestration |
|---------------|---------------|---------------|
| What | Information request | No |
| Why | Explanation request | No |
| How | Understanding request | No |
| Where | Location query | No |
| Show | Display request | No |
| Explain | Clarification | No |

### Orchestration Triggers

| Action Word | Usually Means | Orchestration |
|-------------|---------------|---------------|
| Add | New functionality | Yes |
| Fix | Bug resolution | Usually yes |
| Implement | Feature creation | Yes |
| Refactor | Code restructuring | Yes |
| Update | Modification | Context-dependent |
| Change | Modification | Context-dependent |
| Migrate | System change | Yes |
| Integrate | Connection | Yes |
| Optimize | Performance work | Usually yes |

---

## 5. Scope Assessment

### Single-File Indicators

- Explicit file path mentioned
- Line number specified
- Single function/class named
- "Only in X" language
- Localized change description

### Multi-File Indicators

- "All", "every", "across"
- System component names
- Feature names (not file names)
- "Throughout the codebase"
- No specific location given

---

## 6. Boundary Cases

| Prompt | Classification | Reasoning |
|--------|---------------|-----------|
| "Fix typo in README" | Non-orchestration | Single file, explicit, trivial |
| "Fix typos across the codebase" | Orchestration | Multi-file, needs exploration |
| "Add a log statement" | Non-orchestration | Simple, localized |
| "Add logging throughout the service" | Orchestration | Multi-file, pattern-based |
| "Update the constant value" | Non-orchestration | Single change |
| "Update all constants for new config" | Orchestration | Multi-file coordination |
| "Fix the bug in user.ts" | Context-dependent | May be simple or complex |
| "Fix the login bug" | Orchestration | Needs investigation |

---

## 7. Context Modifiers

### Recent Activity Context

If recent conversation involved:
- Specific files -> May inform scope
- Error messages -> May clarify target
- Feature discussion -> May specify area

### Codebase Context

If codebase has:
- Single file matching name -> Less orchestration needed
- Multiple matches -> Orchestration for disambiguation
- Clear patterns -> May simplify approach

---

## 8. Explicit Orchestration Commands

These always trigger orchestration:

| Command | Action |
|---------|--------|
| `/orchestrate` | Full orchestration pipeline |
| `/plan` | Planning phase, implies orchestration |
| `/delegate` | Agent delegation, implies orchestration |

---

## 9. Pass-Through Verification

Before passing through unchanged, verify:

- [ ] Request is truly read-only OR
- [ ] Target is explicitly specified AND
- [ ] Scope is clearly single-file AND
- [ ] No investigation required

If any check fails, consider orchestration refinement.

---

## 10. Orchestration Refinement Output

When orchestration is needed, refine prompt to:

```
**Goal**: <one-sentence objective>

**Description**: <context and scope>

**Actions**:
1. <exploration step if needed>
2. <planning step if complex>
3. <implementation steps>
4. <verification step>
```

This structured format enables:
- Task classification
- Agent assignment
- Verification planning

---

## See Also

- [SKILL.md](../SKILL.md) - Main prompt refinement documentation
- [ambiguity-detection.md](ambiguity-detection.md) - Detecting ambiguous prompts
- [clarification-strategies.md](clarification-strategies.md) - Getting user clarification
