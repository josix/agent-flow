# Classification Process

Detailed step-by-step process for accurately classifying incoming tasks in the multi-agent orchestration system.

---

## 1. Parse the Request

Extract key information from the user's request:

### Information Extraction Checklist

| Element | Question | Example |
|---------|----------|---------|
| Action Verb | What is being asked? | find, fix, add, refactor, explain, research |
| Target | What code/feature is affected? | specific files, modules, systems |
| Scope Indicators | Any hints about size? | all, every, entire, just, only, simple |
| Constraints | Time pressure, quality requirements? | urgent, production, must work with X |
| Dependencies | Connections mentioned? | API, database, external service |

### Action Verb Classification Signals

| Verb Category | Examples | Typical Classification |
|---------------|----------|------------------------|
| Question verbs | what, why, how, explain | Trivial or Exploratory |
| Search verbs | find, search, where, trace | Exploratory |
| Modification verbs | fix, update, add, change | Implementation |
| Restructure verbs | refactor, redesign, migrate | Complex |
| Research verbs | research, compare, evaluate | Research |

---

## 2. Assess Scope

Determine the breadth of impact:

### Scope Levels

| Scope Level | File Count | Description | Classification Signal |
|-------------|------------|-------------|----------------------|
| Minimal | 0-1 | Single file or no file changes | Trivial |
| Bounded | 2-5 | Related files in same module | Implementation |
| Moderate | 5-10 | Multiple modules affected | Implementation/Complex |
| Extensive | 10+ | System-wide changes | Complex |

### Scope Amplifiers

These factors increase scope classification:

| Amplifier | Adjustment | Reason |
|-----------|------------|--------|
| Database schema changes | +2 levels | Migration risk, data integrity |
| API contract changes | +1 level | Consumer impact |
| Authentication/authorization | +2 levels | Security implications |
| Shared utility modifications | +1 level | Wide blast radius |
| Configuration changes with runtime impact | +1 level | Production risk |

### Scope Estimation Techniques

**Direct Count**: Files explicitly mentioned or obviously affected

**Dependency Tracing**:
- What imports the changed file?
- What does the changed file import?
- What shared state is modified?

**Pattern Matching**:
- "all endpoints" = count all route files
- "the service" = service + tests + types
- "user flow" = frontend + backend + API

---

## 3. Evaluate Risk

Assess potential negative outcomes:

### Risk Factor Matrix

| Risk Factor | Weight | Examples | Mitigation |
|-------------|--------|----------|------------|
| Data loss potential | Critical | DELETE operations, migrations | Backup, dry-run |
| Security implications | Critical | Auth, encryption, user data | Security review |
| Breaking changes | High | API changes, interface mods | Version, deprecation |
| Performance impact | High | Core path changes, DB queries | Profiling, load test |
| User-facing changes | Medium | UI modifications, error msgs | QA, user testing |
| Internal refactoring | Low | Code organization, naming | Standard testing |
| Documentation only | Minimal | Comments, README updates | None required |

### Risk Escalation Rules

Certain conditions force higher risk classification:

**Always Critical Risk**:
- Payment or billing system changes
- Personal data handling modifications
- Encryption key or certificate changes
- Production database operations

**Always High Risk**:
- External API integration changes
- Authentication flow modifications
- Rate limiting or access control changes
- Session management updates

---

## 4. Check Dependencies

Identify interconnections affecting classification:

### Dependency Categories

**Upstream Dependencies** (What calls this code?):
- Direct callers (imports, function calls)
- Event subscribers
- API consumers
- Scheduled job triggers

**Downstream Dependencies** (What does this code call?):
- Database connections
- External APIs
- File system operations
- Message queues

**Shared State** (What state is accessed?):
- Configuration files
- Environment variables
- Caches
- Session stores

**External Systems** (What outside systems interact?):
- Third-party APIs
- Payment processors
- Email services
- Monitoring systems

### Dependency Impact Assessment

| Dependency Type | File Count Impact | Risk Impact |
|-----------------|-------------------|-------------|
| No dependencies | +0 | Low |
| Single module deps | +1-2 files | Medium |
| Cross-module deps | +3-5 files | Medium-High |
| External system deps | Variable | High |
| Shared state deps | +all consumers | High |

---

## 5. Determine Verification Needs

Based on scope and risk, assign verification requirements:

### Verification Matrix

| Classification | Verification Required | Verification Type |
|----------------|----------------------|-------------------|
| Trivial | No | None |
| Exploratory | No | None |
| Implementation | Yes | Alphonse (tests) |
| Complex | Yes | Alphonse (tests) + Lawliet (review) |
| Research | No | None |

### Verification Requirements by Domain

| Domain | Required Checks | Additional Checks |
|--------|-----------------|-------------------|
| Standard code | Unit tests, lint | - |
| API changes | + Integration tests | Contract validation |
| Database changes | + Migration tests | Rollback verification |
| Security changes | + Security scan | Manual security review |
| UI changes | + E2E tests | Visual regression |

---

## 6. Classification Decision Formula

### Primary Decision Tree

```
IF scope = minimal AND risk = low AND no_dependencies:
    -> Trivial

ELSE IF request_is_read_only:
    -> Exploratory (Riko)

ELSE IF requires_external_info:
    -> Research (Riko + WebSearch)

ELSE IF scope <= bounded AND risk <= medium:
    -> Implementation (Loid -> Alphonse)

ELSE:
    -> Complex (Full Orchestration)
```

### Override Conditions

These conditions force higher classification regardless of other factors:

**Always Complex**:
- Security-sensitive changes (authentication, authorization, encryption)
- Database migrations or schema changes
- Changes to payment or billing systems
- Multi-service coordination required
- Breaking API changes

**Always Requires Review (Lawliet)**:
- New external dependencies added
- Changes to error handling patterns
- Modifications to logging or monitoring
- Updates to security-related code

---

## 7. Re-classification Protocol

### When to Re-classify

Re-classify a task when:
- Initial file count estimate wrong by more than 2 files
- New dependencies discovered during work
- User adds requirements mid-task
- Risk assessment changes based on new information
- Implementation reveals hidden complexity

### Re-classification Rules

1. Re-classification should move UP (to higher complexity), not down
2. Document reason for re-classification
3. Notify user of scope change
4. Engage additional agents as needed
5. Reset verification requirements

### Re-classification Workflow

```
Discovery of New Information
         |
         v
    Assess Impact
         |
         +-- Minor (< 2 files) --> Continue current classification
         |
         +-- Moderate (2-4 files) --> Consider re-classification
         |
         +-- Major (5+ files or new risk) --> Re-classify immediately
                   |
                   v
             Document Change
                   |
                   v
             Notify User
                   |
                   v
             Engage Additional Agents
```

---

## See Also

- [SKILL.md](../SKILL.md) - Main task classification documentation
- [agent-selection-matrix.md](agent-selection-matrix.md) - Agent routing details
- [decision-flowchart.md](decision-flowchart.md) - Visual decision guide
- [classification-heuristics.md](classification-heuristics.md) - Edge case handling
