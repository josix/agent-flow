# Tool Access Details

Detailed tool access matrices and permission rules for the multi-agent orchestration system.

## Per-Agent Tool Permissions

### Riko (Explorer)

**Permitted Tools:** Read, Grep, Glob, Bash (restricted), WebSearch, WebFetch

| Tool | Purpose | Usage Notes |
|------|---------|-------------|
| Read | Read file contents | Use to understand code structure and patterns |
| Grep | Search file contents | Use for pattern matching across codebase |
| Glob | Find files by pattern | Use to discover relevant files |
| Bash | AST analysis | ONLY for ast-grep, tree-sitter, language parsers |
| WebSearch | Search the web | Use for documentation and external references |
| WebFetch | Fetch web content | Use to retrieve specific documentation pages |

**Restrictions:**
- Must not use Write or Edit tools
- Bash access restricted to AST analysis tools only (ast-grep, tree-sitter, language parsers)
- Must not manage tasks directly

---

### Senku (Planner)

**Permitted Tools:** Read, Grep, Glob, TodoWrite

| Tool | Purpose | Usage Notes |
|------|---------|-------------|
| Read | Read file contents | Use to verify context before planning |
| Grep | Search file contents | Use to find patterns relevant to planning |
| Glob | Find files by pattern | Use to estimate scope |
| TodoWrite | Write TODO items | Use for task list management |

**Restrictions:**
- Must not modify code directly
- Must not execute Bash commands
- Must not access web resources

---

### Loid (Executor)

**Permitted Tools:** Read, Write, Edit, Bash, Grep, Glob

| Tool | Purpose | Usage Notes |
|------|---------|-------------|
| Read | Read file contents | Use before making edits |
| Write | Create new files | Use for new file creation |
| Edit | Modify existing files | Use for code changes |
| Bash | Execute commands | Use for tests, builds, git operations |
| Grep | Search file contents | Use to find code to modify |
| Glob | Find files by pattern | Use to locate target files |

**Restrictions:**
- Must not access web resources
- Must not manage tasks directly
- Must run tests after changes

---

### Lawliet (Reviewer)

**Permitted Tools:** Read, Grep, Glob, Bash

| Tool | Purpose | Usage Notes |
|------|---------|-------------|
| Read | Read file contents | Use to review code changes |
| Grep | Search file contents | Use to find patterns and violations |
| Glob | Find files by pattern | Use to scope review |
| Bash | Execute commands | Use for lint, type checks, security scanners (static analysis only; NOT test runs) |

**Restrictions:**
- Must not modify code directly
- Must not access web resources
- Must cite specific code in feedback

---

### Alphonse (Verifier)

**Permitted Tools:** Read, Bash, Grep

| Tool | Purpose | Usage Notes |
|------|---------|-------------|
| Read | Read file contents | Use to verify file state |
| Bash | Execute commands | Use for all verification commands |
| Grep | Search file contents | Use to check for patterns |

**Restrictions:**
- Must not modify files
- Must not access web resources
- Must report exact command output

---

---

### Speedwagon (Authoring Agent)

**Persona**: Speedwagon is the dedicated Authoring Agent for interactive codebase explainers. It transforms Riko's scope bundle and Senku's curriculum into a module brief and HTML fragment.

**Permitted Tools:** Read, Grep, Glob, Write (scoped), Edit (scoped), Bash (scoped)

| Tool | Purpose | Usage Notes |
|------|---------|-------------|
| Read | Read source files | Verify file:line refs before embedding snippets |
| Grep | Search source files | Find relevant content for authoring |
| Glob | Find files by pattern | Locate template and source files |
| Write | Author output files | SCOPED: only `explain-out/` and `.claude/explain-briefs/` |
| Edit | Revise output files | SCOPED: only `explain-out/` and `.claude/explain-briefs/` |
| Bash | Run assembler | SCOPED: only `bash scripts/compile-explain.sh` |

**Scoped Write Policy (exception to one-writer invariant):**
Speedwagon has Write/Edit access because it owns explainer artifact authoring — not because it can modify application code. The scope is narrow and deliberate: `explain-out/` (assembled HTML + status) and `.claude/explain-briefs/` (module briefs + fragments). All other paths remain off-limits. This is documented as an explicit exception to preserve the invariant's intent: no two agents write the same files.

**Restrictions:**
- Must not write outside `explain-out/` or `.claude/explain-briefs/`
- Bash limited to `bash scripts/compile-explain.sh` only — no npm, pip, make, git
- Must not call other agents directly

---

## Tool Category Matrix

| Category | Tools | Riko | Senku | Loid | Lawliet | Alphonse | Speedwagon |
|----------|-------|:----:|:-----:|:----:|:-------:|:--------:|:----------:|
| Read-Only | Read, Grep, Glob | Yes | Yes | Yes | Yes | Partial | Yes |
| Write Operations | Write, Edit | - | - | Yes | - | - | Scoped† |
| Command Execution | Bash | Restricted* | - | Yes | Yes | Yes | Scoped‡ |
| Web Access | WebSearch, WebFetch | Yes | - | - | - | - | - |
| Task Management | TodoWrite | - | Yes | - | - | - | - |

*Riko: Bash restricted to AST analysis tools only (ast-grep, tree-sitter, language parsers)
†Speedwagon: Write/Edit scoped to `explain-out/` and `.claude/explain-briefs/` only
‡Speedwagon: Bash limited to `bash scripts/compile-explain.sh` only

---

## Tool Access Violation Protocol

When an agent requires a tool outside its permissions:

### Step 1: Stop
- Immediately halt the operation that requires the forbidden tool
- Do not attempt workarounds or alternative approaches that bypass restrictions

### Step 2: Document
- Record the operation that was blocked
- Note which tool was needed and why
- Include relevant context for handoff

### Step 3: Delegate
- Identify the correct agent for the operation:
  - Write/Edit operations: Loid
  - Web searches: Riko
  - Task management: Senku
  - Verification: Alphonse
- Request handoff with complete context

### Step 4: Continue
- Proceed with operations that remain within permitted tools
- Update status to reflect partial completion
- Wait for delegated work to complete if dependent

---

## Common Tool Access Scenarios

### Scenario: Explorer finds code that needs modification
```
Riko discovers outdated import statement
  -> Document finding with file path and line number
  -> Continue exploration
  -> Include in summary for Loid to fix
```

### Scenario: Executor needs external documentation
```
Loid encounters unfamiliar API
  -> Document what information is needed
  -> Request Riko to search for documentation
  -> Wait for exploration results before proceeding
```

### Scenario: Reviewer finds failing tests
```
Lawliet identifies test failure during review
  -> Document specific test and failure message
  -> Report as blocker in review
  -> Do not attempt to fix directly
```

### Scenario: Verifier needs to modify config
```
Alphonse finds config prevents verification
  -> Document the blocking config issue
  -> Request Loid to make config change
  -> Re-run verification after change complete
```
