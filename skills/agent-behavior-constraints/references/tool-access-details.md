# Tool Access Details

Detailed tool access matrices and permission rules for the multi-agent orchestration system.

## Per-Agent Tool Permissions

### Riko (Explorer)

**Permitted Tools:** Read, Grep, Glob, WebSearch, WebFetch

| Tool | Purpose | Usage Notes |
|------|---------|-------------|
| Read | Read file contents | Use to understand code structure and patterns |
| Grep | Search file contents | Use for pattern matching across codebase |
| Glob | Find files by pattern | Use to discover relevant files |
| WebSearch | Search the web | Use for documentation and external references |
| WebFetch | Fetch web content | Use to retrieve specific documentation pages |

**Restrictions:**
- Must not use Write or Edit tools
- Must not execute Bash commands
- Must not manage tasks directly

---

### Senku (Planner)

**Permitted Tools:** Read, Grep, Glob, TodoWrite, TaskCreate, TaskUpdate

| Tool | Purpose | Usage Notes |
|------|---------|-------------|
| Read | Read file contents | Use to verify context before planning |
| Grep | Search file contents | Use to find patterns relevant to planning |
| Glob | Find files by pattern | Use to estimate scope |
| TodoWrite | Write TODO items | Use for task list management |
| TaskCreate | Create tasks | Use for creating structured task plans |
| TaskUpdate | Update tasks | Use to modify task status and details |

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
| Bash | Execute commands | Use for lint, type checks, test runs |

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

## Tool Category Matrix

| Category | Tools | Riko | Senku | Loid | Lawliet | Alphonse |
|----------|-------|:----:|:-----:|:----:|:-------:|:--------:|
| Read-Only | Read, Grep, Glob | Yes | Yes | Yes | Yes | Partial |
| Write Operations | Write, Edit | - | - | Yes | - | - |
| Command Execution | Bash | - | - | Yes | Yes | Yes |
| Web Access | WebSearch, WebFetch | Yes | - | - | - | - |
| Task Management | TodoWrite, TaskCreate, TaskUpdate | - | Yes | - | - | - |

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
