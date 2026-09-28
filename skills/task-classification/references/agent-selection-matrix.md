# Agent Selection Matrix

Comprehensive reference for matching task characteristics to the appropriate agent(s) in the multi-agent orchestration system.

---

## 1. Agent Profiles

| Agent | Model | Specialty | Tools | Best For |
|-------|-------|-----------|-------|----------|
| Riko | Sonnet | Exploration | Grep, Glob, Read, WebSearch | Codebase navigation, research, impact analysis |
| Senku | Opus | Planning | Read, Grep, Glob, Write (plan/report files only) | Strategic decomposition, architecture decisions |
| Loid | Sonnet | Execution | Edit, Write, Bash, Read | Code implementation, bug fixes, feature development |
| Lawliet | Sonnet | Review | Read, Grep, Glob, Bash | Static analysis, code quality, security review |
| Alphonse | Sonnet | Verification | Bash, Read, Grep | Test execution, build verification, regression testing |

> **Inside `/orchestrate`**, the orchestrator-chosen **Execution Profile** (fast / standard / thorough) governs which phases run; the routing below describes typical agent involvement. Lawliet and Alphonse run under every profile (in parallel); Codex co-review is optional.

---

## 2. Task-to-Agent Routing

### Primary Routing Table

| Task Type | Primary Agent | Secondary Agent | Verification Agent |
|-----------|---------------|-----------------|-------------------|
| Code questions | Direct | - | - |
| Find usages | Riko | - | - |
| Understand architecture | Riko | Senku | - |
| Single file fix | Loid | - | Lawliet + Alphonse (in `/orchestrate`) |
| Multi-file feature | Loid | - | Lawliet + Alphonse |
| Major refactoring | Senku | Loid | Lawliet + Alphonse (+ Codex) |
| Security changes | Senku | Loid | Lawliet + Alphonse (+ Codex) |
| Performance optimization | Riko | Loid | Lawliet + Alphonse |
| Bug investigation | Riko | Loid | Lawliet + Alphonse |
| External research | Riko | - | - |

### Extended Routing Scenarios

| Scenario | Agent Sequence | Rationale |
|----------|----------------|-----------|
| New API endpoint | Loid -> Lawliet + Alphonse | Standard implementation with review and verification |
| Database migration | Senku -> Loid -> Lawliet + Alphonse (+ Codex) | High-risk, needs planning and review |
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

### Sonnet (Balanced)

Assigned to agents requiring efficiency with adequate capability:

**Riko (Explorer)**:
- Fast, broad codebase exploration
- Synthesizes information from multiple sources
- Recognizes patterns across large codebases
- Conducts external research

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
Agent            | Read | Write | Edit | Bash | Grep | Glob | WebSearch | WebFetch
-----------------|------|-------|------|------|------|------|-----------|----------
Riko (Explorer)  |  X   |       |      |  X*  |  X   |  X   |     X     |    X
Senku (Planner)  |  X   |  X§   |      |      |  X   |  X   |           |
Loid (Executor)  |  X   |   X   |  X   |  X   |  X   |  X   |           |
Lawliet (Reviewer)|  X   |       |      |  X   |  X   |  X   |           |
Alphonse (Verifier)| X   |       |      |  X   |  X   |      |           |
```

\* Riko: Bash for AST analysis and writing its own report to `.claude/agent-reports/` (Lawliet and Alphonse may likewise write their own long reports there via Bash heredoc)
§ Senku: Write for plan/report files under `.claude/agent-reports/` or `.senku/` only

### Tool Rationale

| Tool | Purpose | Agents with Access |
|------|---------|-------------------|
| Read | View file contents | All agents |
| Write | Create new files | Loid (Senku: plan/report files only) |
| Edit | Modify existing files | Loid only |
| Bash | Execute commands | Loid, Lawliet, Alphonse (Riko: restricted) |
| Grep | Search file contents | All agents |
| Glob | Find files by pattern | All except Alphonse |
| WebSearch | External research | Riko only |
| WebFetch | Fetch web content | Riko only |

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

**Loid -> Lawliet + Alphonse (+ Codex)** (Execution to parallel Review and Verification):
- Include list of changed files
- Provide expected test commands
- Note any skipped tests with rationale
- Document manual verification needs
- Flag security-relevant changes
- Lawliet, Alphonse, and Codex are dispatched in parallel; none receives another's output (Alphonse reports type/lint as `COVERED (Lawliet)`)

### Escalation Handoffs

**Loid -> Senku** (Execution back to Planning):
- When scope exceeds expectations
- When architectural decisions needed
- When blocking dependencies discovered

**Lawliet / Alphonse -> Loid** (Review or Verification back to Execution):
- When review finds blocking issues
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
                    |   Loid (in /orchestrate: fast profile, Lawliet + Alphonse still run)
                    |
                    +-- 2-5 files
                    |     |
                    |     v
                    |   Loid -> Lawliet + Alphonse (parallel)
                    |
                    +-- 5+ files or high-risk
                          |
                          v
                        Full Orchestration:
                        Riko -> Senku -> Loid -> Lawliet + Alphonse (+ Codex), parallel
```

---

## 7. Parallel Routing Scenarios

> **Deprecated:** Agent Teams and `/team-orchestrate` are deprecated. Inside `/orchestrate`, parallelism is achieved with **parallel background dispatch** that the orchestrator decides itself. The criteria below still describe when splitting work across parallel Loid dispatches is worthwhile.

When a task can be decomposed into multiple independent subtasks, consider **parallel background dispatch within `/orchestrate`**.

### Parallel Eligibility Criteria

- **Task Independence**: Subtasks have no dependencies on each other
- **File Ownership**: Each parallel dispatch has exclusive write access to distinct files
- **Fan-out**: 2-4 parallel dispatches (optimal for coordination)
- **Time Savings**: Each subtask takes 20+ seconds (overhead justified)

### Parallel vs Sequential Decision

| Scenario | Routing | Rationale |
|----------|---------|-----------|
| 3 independent API endpoints | Parallel (3 Loid dispatches) | Exclusive files, no dependencies, time savings |
| 3 bug fixes in isolated modules | Parallel (3 Loid dispatches) | Complete independence, different subsystems |
| Refactor single large file | Sequential (single Loid) | File conflict risk, semantic dependencies |
| Database migration + code update | Sequential (Senku → Loid) | Sequential dependency chain |
| 3 documentation updates | Parallel (3 Loid dispatches) or Direct | Independent files, simple merge |

### Parallel Routing Pattern

```
User Request (decomposable)
  ↓
Senku analyzes parallelism eligibility
  ↓
Decision: Parallel?
  ↓
YES: Parallel background dispatch within /orchestrate
  - Coordinator: Orchestrator
  - Workers: 2-4 Loid dispatches
  - File Ownership: Exclusive per dispatch
  - Merge: Coordinator combines results
  ↓
NO: Sequential implementation
  - Riko → Senku → Loid
  ↓
Either way: Lawliet + Alphonse (+ Codex) in parallel
```

### Example Parallel Composition (illustrative)

**Task**: Implement 3 independent API endpoints

**Dispatch Structure**:
```
Coordinator (Orchestrator):
  - Defines shared types (read-only for workers)
  - Assigns file ownership
  - Merges results after completion

Worker 1 (Loid):
  - Owns: src/api/users/get.ts, src/api/users/get.test.ts
  - Reads: src/types/user.ts (shared, read-only)

Worker 2 (Loid):
  - Owns: src/api/users/post.ts, src/api/users/post.test.ts
  - Reads: src/types/user.ts (shared, read-only)

Worker 3 (Loid):
  - Owns: src/api/users/delete.ts, src/api/users/delete.test.ts
  - Reads: src/types/user.ts (shared, read-only)

Review + Verification (Lawliet + Alphonse, parallel):
  - Run after merge
```

For detailed team decision criteria, see [team-decision skill](../../team-decision/SKILL.md).

---

## See Also

- [SKILL.md](../SKILL.md) - Main task classification documentation
- [classification-process.md](classification-process.md) - Detailed classification steps
- [classification-heuristics.md](classification-heuristics.md) - Edge case heuristics
- [../../team-decision/SKILL.md](../../team-decision/SKILL.md) - Parallel vs sequential decision criteria
