# Search Patterns

Detailed patterns for effective codebase exploration.

## Pattern Categories

### Structural Patterns

Use these to understand codebase organization.

#### Find Entry Points

```
Glob:
  - **/index.{ts,js,tsx,jsx}
  - **/main.{ts,js,py}
  - **/app.{ts,js,py}
  - **/server.{ts,js}
  - **/__init__.py

Grep:
  - "export default"
  - "module.exports"
  - "if __name__"
```

#### Find Configuration

```
Glob:
  - **/package.json
  - **/tsconfig.json
  - **/pyproject.toml
  - **/setup.py
  - **/.env.example
  - **/config/*.{json,yaml,yml}

Grep:
  - "config\s*="
  - "settings\s*="
  - "env\." patterns
```

#### Map Directory Structure

```
Glob:
  - src/**/*
  - lib/**/*
  - packages/**/*

Priority directories:
  - src/     (main source)
  - lib/     (library code)
  - test/    (test files)
  - types/   (type definitions)
  - utils/   (utilities)
```

---

### Definition Patterns

Use these to find specific definitions.

#### Find Functions

```
Grep (TypeScript/JavaScript):
  - function\s+{name}
  - const\s+{name}\s*=.*=>
  - {name}\s*=\s*function
  - async\s+function\s+{name}

Grep (Python):
  - def\s+{name}
  - async\s+def\s+{name}
```

#### Find Classes

```
Grep (TypeScript/JavaScript):
  - class\s+{name}
  - export\s+class\s+{name}

Grep (Python):
  - class\s+{name}
  - class\s+{name}\s*\(
```

#### Find Types/Interfaces

```
Grep (TypeScript):
  - interface\s+{name}
  - type\s+{name}\s*=
  - export\s+interface\s+{name}
  - export\s+type\s+{name}
```

---

### Usage Patterns

Use these to find where something is used.

#### Find Imports

```
Grep (TypeScript/JavaScript):
  - import.*from.*{module}
  - require\(['"]{module}

Grep (Python):
  - from\s+{module}\s+import
  - import\s+{module}
```

#### Find Function Calls

```
Grep:
  - {function}\s*\(
  - \.{method}\s*\(
  - await\s+{function}
```

#### Find References

```
Grep:
  - {variable}\s*[=\.]
  - \b{name}\b (word boundary)
```

---

### Quality Patterns

Use these to assess code quality.

#### Find TODOs and FIXMEs

```
Grep:
  - TODO
  - FIXME
  - HACK
  - XXX
  - @todo
```

#### Find Error Handling

```
Grep (TypeScript/JavaScript):
  - try\s*{
  - catch\s*\(
  - \.catch\s*\(
  - throw\s+new

Grep (Python):
  - try:
  - except
  - raise\s+
```

#### Find Tests

```
Glob:
  - **/*.test.{ts,tsx,js,jsx}
  - **/*.spec.{ts,tsx,js,jsx}
  - **/test_*.py
  - **/*_test.py
  - **/tests/**/*.py

Grep:
  - describe\s*\(
  - it\s*\(
  - test\s*\(
  - def\s+test_
  - @pytest
```

---

## Language-Specific Patterns

### TypeScript/JavaScript

```
React Components:
  Glob: **/components/**/*.tsx
  Grep: export.*function|export\s+default

Hooks:
  Glob: **/hooks/**/*.ts
  Grep: use[A-Z]

API Routes:
  Glob: **/api/**/*.ts, **/routes/**/*.ts
  Grep: app\.(get|post|put|delete)

Utilities:
  Glob: **/utils/**/*.ts, **/helpers/**/*.ts
```

### Python

```
Django Views:
  Glob: **/views.py, **/views/**/*.py
  Grep: def\s+\w+\s*\(request

Django Models:
  Glob: **/models.py, **/models/**/*.py
  Grep: class.*models\.Model

FastAPI Routes:
  Glob: **/routers/**/*.py, **/api/**/*.py
  Grep: @app\.(get|post|put|delete)

Utilities:
  Glob: **/utils/**/*.py, **/helpers/**/*.py
```

---

## Search Refinement

### Narrowing Results

When too many results:
1. Add file type constraints
2. Add path constraints
3. Make pattern more specific
4. Exclude common false positives

```
Too broad:  "config"
Better:     "config\s*=" in *.ts files
Best:       "const config\s*=" in src/**/*.ts
```

### Expanding Results

When too few results:
1. Remove constraints
2. Try alternative terms
3. Use regex wildcards
4. Search for related concepts

```
Too narrow: "handleUserLogin"
Broader:    "handle.*Login"
Broadest:   "Login" or "authenticate"
```

### Combining Results

For comprehensive coverage:
```
Parallel searches:
  - Exact term: "UserService"
  - Pattern: "User.*Service"
  - Related: "AuthService|AccountService"
```

---

## Search Anti-Patterns

### Avoid These

1. **Overly broad searches**
   - Bad: Search for "a" or "the"
   - Good: Search for specific identifiers

2. **Ignoring file types**
   - Bad: Search all files for code patterns
   - Good: Limit to relevant source files

3. **Sequential when parallel is possible**
   - Bad: Search, wait, search, wait
   - Good: Multiple independent searches at once

4. **Deep reads before filtering**
   - Bad: Read every file that matches
   - Good: Scan results, prioritize, then read

5. **Searching without context**
   - Bad: Random searches hoping to find something
   - Good: Hypothesis-driven search with clear goals
