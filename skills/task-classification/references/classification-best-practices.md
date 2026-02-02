# Classification Best Practices

Best practices, common pitfalls, and guidelines for effective task classification in the multi-agent orchestration system.

---

## 1. Classification Best Practices

### DO

**Classify Early**
- Classify at the start of the conversation
- Do not wait until implementation to determine complexity
- Early classification enables proper resource allocation

**Re-classify When Scope Changes**
- Monitor for scope creep during implementation
- Be willing to upgrade classification mid-task
- Document re-classification decisions

**Document Reasoning for Complex Tasks**
- Explain why a task is classified as Complex
- Note specific risk factors identified
- Record verification requirements and rationale

**Verify Estimates with Exploration**
- Use Riko before committing to Implementation classification
- Validate file count estimates before starting work
- Check for hidden dependencies

**Consider Blast Radius**
- Think about what breaks if this change has a bug
- Trace dependencies to understand impact
- Factor in indirect effects on other components

### DO NOT

**Under-classify to Save Time**
- Faster execution is not worth broken code
- Classification overhead prevents larger issues
- Rushed work creates technical debt

**Skip Verification**
- Implementation and Complex tasks always require verification
- "Tests probably pass" is not acceptable
- Verification catches issues before they reach production

**Assume Small Requests Stay Small**
- "Just add a field" often affects many files
- User language minimizes perceived complexity
- Investigate before accepting initial scope

**Classify Based Only on User Language**
- Ignore minimizing words: "just", "simple", "quick"
- Focus on actual scope analysis
- Users often underestimate complexity

---

## 2. Agent Delegation Best Practices

### Effective Delegation

**Provide Clear Context**
- Include relevant file paths
- Share pertinent code snippets
- Explain the business context

**Specify Expected Outcomes**
- Define what success looks like
- List acceptance criteria
- Note edge cases to handle

**Set Appropriate Constraints**
- Time expectations (if relevant)
- Scope boundaries
- Quality requirements

### Handoff Protocol

**Riko -> Senku** (Exploration to Planning):
- Include discovered files and patterns
- Provide complexity assessment
- Document dependencies found
- Highlight risk areas identified

**Senku -> Loid** (Planning to Execution):
- Include step-by-step plan with file targets
- Specify expected outcomes per step
- Note constraints and requirements
- Define acceptance criteria

**Loid -> Alphonse** (Execution to Verification):
- Include list of changed files
- Provide expected test commands
- Note any skipped tests with rationale
- Document manual verification needs

**Alphonse -> Lawliet** (Verification to Review):
- Include test results summary
- Highlight areas of concern
- Note coverage gaps
- Flag security-relevant changes

---

## 3. Verification Best Practices

### Pre-Verification Checklist

Before requesting verification:
- [ ] All planned files have been modified
- [ ] No unintended files were changed
- [ ] Changes align with the original request
- [ ] Error handling is in place
- [ ] Documentation updated if needed

### Verification Commands by Project Type

| Project Type | Commands |
|--------------|----------|
| Node.js/TS | `npm test`, `npm run lint`, `npx tsc --noEmit` |
| Python | `pytest`, `ruff check`, `mypy` |
| Go | `go test ./...`, `go vet ./...` |
| Rust | `cargo test`, `cargo clippy` |

### Post-Verification Actions

**If All Pass**:
- Document verification results
- Mark task complete
- Commit changes (if requested)

**If Any Fail**:
- Analyze failure cause
- Fix issues (do not suppress)
- Re-run verification
- Document resolution

---

## 4. Common Pitfalls

### Classification Pitfalls

| Pitfall | Consequence | Prevention |
|---------|-------------|------------|
| Under-classification | Bugs, regressions | When uncertain, classify higher |
| Skipping verification | Broken code shipped | Treat verification as mandatory |
| Wrong agent assignment | Inefficient execution | Use agent selection matrix |
| Ignoring dependencies | Cascade failures | Always check upstream/downstream |
| Scope creep | Never-ending tasks | Re-classify when scope changes |

### Agent-Specific Pitfalls

**Riko Pitfalls**:
- Exploring too broadly without focus
- Not documenting findings for handoff
- Missing critical dependencies

**Senku Pitfalls**:
- Over-planning simple tasks
- Creating plans without validation
- Ignoring existing patterns

**Loid Pitfalls**:
- Proceeding without clear plan
- Not testing incrementally
- Modifying unrelated code

**Alphonse Pitfalls**:
- Skipping verification steps
- Accepting partial test passes
- Not reporting full failure details

**Lawliet Pitfalls**:
- Focusing only on style issues
- Missing security concerns
- Not checking edge cases

---

## 5. Re-classification Guidelines

### When to Re-classify

Re-classify a task when:
- Initial file count estimate wrong by more than 2 files
- New dependencies discovered during work
- User adds requirements mid-task
- Risk assessment changes based on new information
- Implementation reveals hidden complexity

### Re-classification Direction

Re-classification should move UP (to higher complexity), not down:

```
Trivial -> Implementation -> Complex
   |            |              |
   v            v              v
  Never      Only if        Never
  downgrade  genuinely      downgrade
             simpler than   (safety
             expected       first)
```

### Re-classification Documentation

When re-classifying, document:
1. Original classification
2. Trigger for re-classification
3. New classification
4. Additional agents/verification now required
5. Impact on timeline (if any)

---

## 6. Edge Case Handling

### "Read Then Write" Requests

Example: "Understand how X works, then improve it"

**Handling**:
1. Start with Exploratory (Riko)
2. Based on findings, classify the write phase
3. Never start writing before understanding

### External Dependency Addition

**Always requires Lawliet review**, regardless of other factors.

**Review Checklist**:
- License compatibility
- Security vulnerabilities
- Maintenance status
- Bundle size impact
- Alternative options considered

### Performance Optimization

**Classification depends on scope**:

| Optimization Type | Classification |
|-------------------|----------------|
| Single query optimization | Implementation |
| Algorithm replacement | Implementation |
| Caching layer addition | Complex |
| Architecture change | Complex |

### Compound Requests

When a user request contains multiple sub-tasks:

**Heuristic**: Classify based on the HIGHEST complexity component.

Example: "Find where we handle auth and add logging"
- Component 1: Find auth handling (Exploratory)
- Component 2: Add logging (Implementation)
- **Final Classification**: Implementation

---

## 7. Quality Metrics

### Classification Quality Indicators

**Good Classification**:
- First classification is final (no re-classification needed)
- Verification passes on first attempt
- No unexpected files modified
- Task completed within estimated scope

**Poor Classification Signs**:
- Multiple re-classifications required
- Verification failures due to scope issues
- Discovery of major dependencies mid-implementation
- Significant time overruns

### Continuous Improvement

Track these metrics to improve classification accuracy:
- Re-classification rate
- Verification failure rate
- Scope accuracy (estimated vs. actual files)
- User-reported issues post-completion

---

## See Also

- [SKILL.md](../SKILL.md) - Main task classification documentation
- [classification-heuristics.md](classification-heuristics.md) - Detailed heuristics for edge cases
- [classification-process.md](classification-process.md) - Step-by-step process
