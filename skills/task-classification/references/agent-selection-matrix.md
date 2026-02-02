# Agent Selection Matrix

Comprehensive reference for matching task characteristics to the appropriate agent(s) in the multi-agent orchestration system.

---

## 1. Agent Profiles

| Agent | Model | Specialty | Tools | Best For |
|-------|-------|-----------|-------|----------|
| Riko | Opus | Exploration | Grep, Glob, Read, WebSearch | Codebase navigation, research, impact analysis |
| Senku | Opus | Planning | TodoWrite, Read, Grep, Glob | Strategic decomposition, architecture decisions |
| Loid | Sonnet | Execution | Edit, Write, Bash, Read | Code implementation, bug fixes, feature development |
| Lawliet | Sonnet | Review | Read, Grep, Glob, Bash | Static analysis, code quality, security review |
| Alphonse | Sonnet | Verification | Bash, Read | Test execution, build verification, regression testing |

---

## 2. Task-to-Agent Routing

### Primary Routing Table

| Task Type | Primary Agent | Secondary Agent | Verification Agent |
|-----------|---------------|-----------------|-------------------|
| Code questions | Direct | - | - |
| Find usages | Riko | - | - |
| Understand architecture | Riko | Senku | - |
| Single file fix | Loid | - | - |
| Multi-file feature | Loid | - | Alphonse |
| Major refactoring | Senku | Loid | Alphonse + Lawliet |
| Security changes | Senku | Loid | Alphonse + Lawliet |
| Performance optimization | Riko | Loid | Alphonse |
| Bug investigation | Riko | Loid | Alphonse |
| External research | Riko | - | - |

### Extended Routing Scenarios

| Scenario | Agent Sequence | Rationale |
|----------|----------------|-----------|
| New API endpoint | Loid -> Alphonse | Standard implementation with verification |
| Database migration | Senku -> Loid -> Alphonse + Lawliet | High-risk, needs planning and review |
| Codebase exploration | Riko | Read-only investigation |
| Architecture design | Senku | Strategic planning |
| Security audit | Riko -> Lawliet | Investigation followed by review |
| Performance profiling | Riko -> Loid | Analysis then optimization |
| Documentation update | Direct or Loid | Minimal risk, no verification needed |

---

## 3. Model Selection Rationale

### Opus (High Reasoning)

Assigned to agents requiring deep analytical capabilities:

**Senku (Planner)**:
- Requires deep strategic thinking
- Makes architectural decisions affecting system design
- Decomposes complex problems into manageable tasks
- Balances competing concerns (speed, safety, maintainability)

**Riko (Explorer)**:
- Needs thorough analysis for complex codebase exploration
- Synthesizes information from multiple sources
- Recognizes patterns across large codebases
- Conducts external research requiring critical evaluation

### Sonnet (Balanced)

Assigned to agents requiring efficiency with adequate capability:

**Loid (Executor)**:
- Good balance of speed and capability for implementation
- Follows established patterns
- Executes well-defined plans
- Handles iterative refinement efficiently

**Lawliet (Reviewer)**:
- Fast iteration for code review feedback loops
- Pattern matching for common issues
- Security vulnerability scanning
- Style and convention checking

**Alphonse (Verifier)**:
- Fast execution of verification commands
- Test result interpretation
- Build process monitoring
- Clear pass/fail determination

---

## 4. Tool Access by Agent

### Tool Matrix

```
Agent            | Read | Write | Edit | Bash | Grep | Glob | WebSearch | WebFetch | TodoWrite
-----------------|------|-------|------|------|------|------|-----------|----------|----------
Riko (Explorer)  |  X   |       |      |      |  X   |  X   |     X     |    X     |
Senku (Planner)  |  X   |       |      |      |  X   |  X   |           |          |    X
Loid (Executor)  |  X   |   X   |  X   |  X   |  X   |  X   |           |          |
Lawliet (Reviewer)|  X   |       |      |  X   |  X   |  X   |           |          |
Alphonse (Verifier)| X   |       |      |  X   |  X   |      |           |          |
```

### Tool Rationale

| Tool | Purpose | Agents with Access |
|------|---------|-------------------|
| Read | View file contents | All agents |
| Write | Create new files | Loid only |
| Edit | Modify existing files | Loid only |
| Bash | Execute commands | Loid, Lawliet, Alphonse |
| Grep | Search file contents | All except Alphonse |
| Glob | Find files by pattern | All except Alphonse |
| WebSearch | External research | Riko only |
| WebFetch | Fetch web content | Riko only |
| TodoWrite | Task management | Senku only |

---

## 5. Handoff Protocols

### Standard Handoff Sequences

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

### Escalation Handoffs

**Loid -> Senku** (Execution back to Planning):
- When scope exceeds expectations
- When architectural decisions needed
- When blocking dependencies discovered

**Alphonse -> Loid** (Verification back to Execution):
- When tests fail
- When fixes needed
- When additional changes required

---

## 6. Agent Selection Decision Tree

```
Start
  |
  v
Is this a question (no code changes)?
  |
  +-- YES --> Direct response (no agent)
  |
  +-- NO
        |
        v
      Requires external information?
        |
        +-- YES --> Riko (Explorer)
        |
        +-- NO
              |
              v
            Is it read-only investigation?
              |
              +-- YES --> Riko (Explorer)
              |
              +-- NO
                    |
                    v
                  How many files affected?
                    |
                    +-- 0-1 files
                    |     |
                    |     v
                    |   Loid (direct, no verification)
                    |
                    +-- 2-5 files
                    |     |
                    |     v
                    |   Loid -> Alphonse
                    |
                    +-- 5+ files or high-risk
                          |
                          v
                        Full Orchestration:
                        Riko -> Senku -> Loid -> Alphonse (+ Lawliet if security)
```

---

## See Also

- [SKILL.md](../SKILL.md) - Main task classification documentation
- [classification-process.md](classification-process.md) - Detailed classification steps
- [classification-heuristics.md](classification-heuristics.md) - Edge case heuristics
