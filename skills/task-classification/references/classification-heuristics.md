# Classification Heuristics

This document provides detailed heuristics for handling edge cases and ambiguous classification scenarios.

## 1. Ambiguous Request Heuristics

### 1.1 "Simple" Language Trap

When users describe tasks as "simple", "just", "quick", or "small", do NOT automatically classify as Trivial.

**Heuristic**: Ignore minimizing language. Classify based on actual scope analysis.

| User Says | Actual Classification | Reason |
|-----------|----------------------|--------|
| "Just update the API" | Implementation or Complex | API changes have wide impact |
| "Simple refactor" | Implementation or Complex | Refactoring affects multiple files |
| "Quick database fix" | Complex | Database changes are always high-risk |
| "Just add a field" | Implementation | Requires model, API, UI, tests |

### 1.2 Scope Discovery Heuristic

When initial scope is unclear, use Riko (Explorer) to determine actual file count before final classification.

**Process**:
1. Initial classification: Exploratory (temporary)
2. Riko investigates actual scope
3. Re-classify based on discovered file count
4. Proceed with appropriate agent(s)

### 1.3 Compound Request Heuristic

When a user request contains multiple sub-tasks:

**Heuristic**: Classify based on the HIGHEST complexity component.

**Example**: "Find where we handle auth and add logging"
- Component 1: Find auth handling (Exploratory)
- Component 2: Add logging (Implementation)
- **Final Classification**: Implementation

---

## 2. Domain-Specific Heuristics

### 2.1 Authentication/Authorization Changes

**Always Complex**, regardless of apparent scope.

**Rationale**:
- Security implications affect entire system
- Bugs can expose user data
- Changes often have hidden dependencies
- Requires thorough review and testing

**Required Agents**: Senku -> Loid -> Alphonse -> Lawliet

### 2.2 Database Schema Changes

**Always Complex**, with additional caution.

**Rationale**:
- Migrations can fail and corrupt data
- Rollback may be difficult or impossible
- Affects all code that touches the schema
- Performance implications

**Additional Requirements**:
- Migration script review
- Backup verification
- Rollback plan documentation

### 2.3 API Contract Changes

**Implementation** if additive (new endpoint/field)
**Complex** if modifying existing contracts

**Breaking Change Indicators**:
- Removing fields
- Changing field types
- Modifying response structure
- Changing authentication requirements

### 2.4 Configuration Changes

| Change Type | Classification |
|-------------|----------------|
| Development config only | Trivial |
| Production config | Implementation |
| Security-related config | Complex |
| Feature flags | Implementation |

---

## 3. File Count Heuristics

### 3.1 Direct vs. Indirect Files

Count BOTH directly modified and indirectly affected files.

**Direct**: Files you will edit
**Indirect**: Files that import/use the modified code

**Example**: Renaming a utility function
- Direct: 1 file (the utility)
- Indirect: 15 files (all importers)
- **Total Impact**: 16 files -> Complex

### 3.2 Test File Considerations

Test files count toward file totals.

| Code Files | Test Files | Total | Classification |
|------------|------------|-------|----------------|
| 1 | 1 | 2 | Implementation |
| 3 | 3 | 6 | Complex |
| 5 | 0 | 5 | Implementation (but needs test review) |

### 3.3 Generated Files

Exclude generated files from count but note their existence.

**Generated files**: Build outputs, compiled assets, auto-generated types

---

## 4. Risk Assessment Heuristics

### 4.1 Blast Radius Estimation

Calculate potential impact using this formula:

```
Blast Radius = (Direct Files * 1) + (Importing Files * 0.5) + (Transitive Importers * 0.25)
```

| Blast Radius | Classification |
|--------------|----------------|
| < 2 | Trivial |
| 2-5 | Implementation |
| 5-10 | Implementation with review |
| > 10 | Complex |

### 4.2 Reversibility Assessment

| Reversibility | Risk Level |
|---------------|------------|
| Easy (git revert) | Low |
| Moderate (migration down) | Medium |
| Difficult (data mutation) | High |
| Impossible (external systems) | Critical |

### 4.3 Testing Coverage Assessment

| Existing Coverage | Classification Adjustment |
|-------------------|---------------------------|
| High (>80%) | No adjustment |
| Medium (50-80%) | +1 level |
| Low (<50%) | +1 level, require Lawliet review |
| None | +2 levels, mandatory review |

---

## 5. Verification Heuristics

### 5.1 Test Flakiness

If tests are known to be flaky:
- Run tests 3 times before declaring failure
- Document flaky tests separately
- Do not block on known flaky tests (but track them)

### 5.2 Partial Test Failure

If only some tests fail:
- Analyze if failures are related to changes
- Unrelated failures: Document and continue (with approval)
- Related failures: Must fix before completion

### 5.3 No Existing Tests

When code has no tests:
- Implementation tasks: Add tests for changed code
- Complex tasks: Add comprehensive tests
- Document test debt if unable to add tests

---

## 6. Edge Case Decision Tree

### 6.1 "Read then Write" Requests

**Example**: "Understand how X works, then improve it"

**Heuristic**: Classify as the higher of the two components.

1. Exploration phase (Riko)
2. Based on findings, re-classify for implementation
3. Never start writing before understanding

### 6.2 External Dependency Addition

**Always requires Lawliet review**, regardless of other factors.

**Review Checklist**:
- License compatibility
- Security vulnerabilities
- Maintenance status
- Bundle size impact
- Alternative options considered

### 6.3 Performance Optimization

**Classification depends on scope**:

| Optimization Type | Classification |
|-------------------|----------------|
| Single query optimization | Implementation |
| Algorithm replacement | Implementation |
| Caching layer addition | Complex |
| Architecture change | Complex |

---

## 7. Agent Selection Edge Cases

### 7.1 When Riko Finds More Than Expected

If exploration reveals scope > 5 files:
1. Stop exploration
2. Re-classify as Complex
3. Engage Senku for planning
4. Continue with full orchestration

### 7.2 When Loid Hits Unexpected Complexity

If during implementation Loid discovers:
- More files needed than planned
- Unexpected dependencies
- Security implications

**Protocol**:
1. Pause implementation
2. Report findings
3. Re-classify if needed
4. Engage additional agents as required

### 7.3 When Alphonse Tests Fail

If verification fails:
1. Analyze failure type (test bug vs. code bug)
2. If code bug: Return to Loid
3. If test bug: Fix test, re-run
4. If flaky: Document and decide

---

## 8. Quick Decision Heuristics

### 8.1 Five-Second Rule

If classification is not obvious within 5 seconds, escalate:
- Trivial -> Implementation
- Implementation -> Complex

### 8.2 "What Could Go Wrong" Test

Ask: "What's the worst that could happen if this change has a bug?"

| Worst Case | Minimum Classification |
|------------|------------------------|
| Typo in docs | Trivial |
| UI glitch | Implementation |
| Feature broken | Implementation |
| Data corruption | Complex |
| Security breach | Complex |
| Service outage | Complex |

### 8.3 Stakeholder Impact Test

| Who is affected | Classification |
|-----------------|----------------|
| Just me (developer) | Trivial |
| My team | Implementation |
| Other teams | Implementation with review |
| End users | Implementation minimum |
| External customers | Complex |

---

*See also: `../examples/classification-examples.md` for worked examples*
