# Exploration Depth Guidelines

Detailed guidelines for determining appropriate exploration depth based on task complexity.

## Complexity Assessment

### Factors Affecting Depth

| Factor | Low Complexity | High Complexity |
|--------|----------------|-----------------|
| Scope | Single file | Multiple files/modules |
| Dependencies | None or few | Many interconnected |
| Familiarity | Known codebase | New codebase |
| Change Type | Bug fix | Architecture change |
| Risk | Low impact | High impact |

### Complexity Scoring

Calculate approximate complexity:

```
Base: 1 point

Add points for:
+1 if multiple files affected
+1 if unfamiliar codebase
+1 if dependencies unclear
+1 if tests need updating
+1 if configuration changes needed
+2 if architecture implications

Total:
1-2: Simple
3-4: Moderate
5-6: Complex
7+:  Highly Complex
```

---

## Depth by Task Type

### Bug Fixes

**Simple bug (1-2 files):**
```
Depth: Minimal
Files: 1-3
Time:  2-5 minutes

Exploration:
1. Read the file with the bug
2. Check for related tests
3. Verify fix location
```

**Complex bug (multiple files):**
```
Depth: Moderate
Files: 5-10
Time:  5-10 minutes

Exploration:
1. Trace error from entry point
2. Map affected call chain
3. Check related configurations
4. Identify test coverage
```

### Feature Additions

**Small feature:**
```
Depth: Moderate
Files: 5-10
Time:  5-10 minutes

Exploration:
1. Find similar existing features
2. Identify integration points
3. Check test patterns
4. Review type definitions
```

**Large feature:**
```
Depth: Extensive
Files: 10-20
Time:  10-15 minutes

Exploration:
1. Map all affected areas
2. Understand data flow
3. Identify side effects
4. Review architecture patterns
5. Check configuration needs
```

### Refactoring

**Local refactoring:**
```
Depth: Moderate
Files: 5-10
Time:  5-10 minutes

Exploration:
1. Understand current implementation
2. Find all usages of refactored code
3. Identify test coverage
4. Check for hidden dependencies
```

**Cross-cutting refactoring:**
```
Depth: Extensive
Files: 20+
Time:  15-30 minutes

Exploration:
1. Full impact analysis
2. Map all affected modules
3. Identify migration path
4. Review patterns across codebase
5. Check for version compatibility
```

### Architecture Changes

```
Depth: Maximum
Files: 20+
Time:  20-30 minutes

Exploration:
1. Comprehensive codebase review
2. Dependency graph analysis
3. Interface inventory
4. Test coverage assessment
5. Configuration audit
6. Documentation review
```

---

## File Priority by Task

### Always Read First

| Task Type | Priority Files |
|-----------|----------------|
| Any | Direct target files |
| Bug fix | Error location, stack trace files |
| Feature | Similar features, integration points |
| Refactoring | All files being refactored |

### Read Second

| Task Type | Secondary Files |
|-----------|-----------------|
| Any | Related test files |
| Bug fix | Calling code, error handlers |
| Feature | Type definitions, shared utilities |
| Refactoring | Dependent modules |

### Read If Needed

| Task Type | Optional Files |
|-----------|----------------|
| Any | Configuration, documentation |
| Bug fix | Historical context, related bugs |
| Feature | Architecture docs |
| Refactoring | Migration examples |

---

## Time Budget Allocation

### Simple Tasks (5 minutes total)

```
Search/Glob: 1 minute
Reading:     2 minutes
Analysis:    1 minute
Summary:     1 minute
```

### Moderate Tasks (10 minutes total)

```
Search/Glob: 2 minutes
Reading:     4 minutes
Analysis:    2 minutes
Summary:     2 minutes
```

### Complex Tasks (20 minutes total)

```
Search/Glob: 4 minutes
Reading:     8 minutes
Analysis:    5 minutes
Summary:     3 minutes
```

---

## Depth Adjustment Triggers

### Increase Depth When

1. **Initial searches return unexpected results**
   - More dependencies than expected
   - Unfamiliar patterns discovered

2. **Inconsistencies found**
   - Different patterns in different areas
   - Conflicting implementations

3. **Critical path identified**
   - Changes affect core functionality
   - Security implications discovered

4. **Test coverage concerns**
   - Missing tests for affected code
   - Complex test setup required

### Decrease Depth When

1. **Pattern recognition succeeds**
   - Similar to known codebase
   - Standard patterns used throughout

2. **Limited scope confirmed**
   - Changes truly isolated
   - No unexpected dependencies

3. **Good documentation exists**
   - Clear inline documentation
   - Up-to-date README files

4. **Strong type system**
   - TypeScript with strict mode
   - Comprehensive type definitions

---

## Stopping Criteria by Depth

### Minimal Exploration Complete When

- [ ] Target file(s) read
- [ ] Basic context understood
- [ ] No obvious blockers found

### Moderate Exploration Complete When

- [ ] All affected files identified
- [ ] Patterns documented
- [ ] Test approach clear
- [ ] Dependencies mapped

### Extensive Exploration Complete When

- [ ] Full impact analysis done
- [ ] All affected modules reviewed
- [ ] Edge cases identified
- [ ] Migration path clear
- [ ] Risks documented
