# Data Flows

Detailed sequence diagrams showing how data flows through Agent Flow during orchestration and deep-dive workflows.

## Orchestration Data Flow

### Complete Workflow Sequence

```mermaid
sequenceDiagram
    participant U as User
    participant H as Hooks
    participant O as Orchestrator
    participant ST as State File
    participant R as Riko
    participant S as Senku
    participant L as Loid
    participant LW as Lawliet
    participant A as Alphonse
    participant CX as Codex (optional)

    %% Initialization
    U->>O: /orchestrate "Add auth feature"
    O->>H: UserPromptSubmit
    H->>H: Deterministic gate (skip / nudge)
    H-->>O: additionalContext nudge (only for new unscoped prompts)
    O->>ST: init-orchestration.sh
    Note over O,ST: init-orchestration.sh calls detect-graph-context.sh,<br/>detect-personal-kb.sh, and detect-agentsview-context.sh,<br/>writing graph + personal_kb + agentsview blocks into state
    ST-->>O: State initialized (with graph/personal_kb/agentsview context blocks)

    Note over O: Execution profile chosen (fast / standard / thorough).<br/>Phases 1-2 are skipped under fast, and for trivial under standard

    %% Phase 1: Exploration
    rect rgb(200, 230, 255)
        Note over O,R: Phase 1: Exploration
        O->>R: Task: Explore codebase
        R->>R: Glob, Grep, Read
        R-->>O: Findings (files, patterns)
        O->>ST: update-state --phase planning
    end

    %% Phase 2: Planning
    rect rgb(200, 255, 200)
        Note over O,S: Phase 2: Planning
        O->>S: Task: Create plan<br/>(includes Riko findings)
        S->>S: Analyze, write numbered checklist plan
        S-->>O: Implementation plan
        O->>ST: update-state --phase implementation
    end

    %% Phases 3-5 as a workflow
    rect rgb(255, 245, 220)
        Note over O,A: Phases 3-5: implement-review-verify workflow
        O->>L: Task: Implement plan
        L->>H: PreToolUse (Write/Edit)
        H-->>L: Allowed
        L->>L: Write, Edit, targeted checks
        L-->>O: Changes made
        par Phase 4: Review
            O->>LW: Review (type check, lint, patterns, intent)
            LW-->>O: APPROVED or NEEDS_CHANGES
        and Codex (optional)
            O->>CX: dispatch-codex-review.sh
            CX-->>O: Verdict + file:line findings
        and Phase 5: Verification
            O->>A: Tests and build
            A-->>O: VERIFIED, FAILED or ENVIRONMENT_BLOCKED
        end
        alt blocking findings and round < cap
            O->>L: One batch of all ERROR/WARNING findings
            L-->>O: Fixed
            Note over O,A: Lawliet and Codex re-review the fix diff; Alphonse re-runs
        end
        Note over O: Returns status: complete, capped, escalation, divergence or blocked
    end

    O->>ST: update-state --complete

    %% Completion
    O->>H: Stop hook
    H->>H: verify-completion.sh
    H-->>O: Gates passed
    O->>U: TASK VERIFIED (a capped run lists Open findings instead)
```

### Data Passed Between Phases

| From | To | Data |
|------|-----|------|
| User | Orchestrator | Task description |
| Hooks | Orchestrator | additionalContext nudge (optional) |
| Orchestrator | State | Phase transitions, gate results |
| init-orchestration.sh | State | `task_complexity: "unclassified"` + `intent:` object (seeded at init) |
| Phase 0 (Prompt Refinement) | State | `task_complexity` tier + `intent` fields persisted via `--set-task-complexity` / `--set-intent-*` |
| detect-graph-context.sh | State | `graph:` block (available, path, nodes, edges, communities) |
| detect-personal-kb.sh | State | `personal_kb:` block (available, path, graph_path, nodes) |
| detect-agentsview-context.sh | State | `agentsview:` block (available, binary, archive_reachable) |
| detect-codex-context.sh | State | `codex:` block (available, binary, auth_present); init runs it alongside the other detectors |
| Riko | Orchestrator | Files, patterns, architecture |
| Orchestrator | Senku | Task + Riko's findings + **intent payload (verbatim, no re-summarization)** |
| Senku | Orchestrator | Implementation plan + `<plan-interpretation>` block |
| Orchestrator | Workflow | `intent`, `plan`, `profile`, `codex`, `codex_available`, `state_file`, `plugin_root`, optional `prior_findings` / `start_round` / `preambles` (`workflows/implement-review-verify.js`) |
| Workflow | Loid | Plan (or intent when Phases 1-2 were skipped) + **intent payload (verbatim)** |
| Loid | Workflow | Changed files + targeted check results |
| Workflow | Orchestrator | `status` (`complete`/`capped`/`escalation`/`divergence`/`blocked`), `open_findings`, `rounds_used` |
| Workflow | Lawliet | Changed files list (fix diff on re-review) + **intent Goal + Constraints** |
| Lawliet | Workflow | Review verdict + issues (including `intent-mismatch` if applicable) |
| Workflow | Codex | Diff + rubric via `dispatch-codex-review.sh` |
| Codex | Workflow | Verdict + `file:line` findings |
| Workflow | Alphonse | Full codebase |
| Alphonse | Workflow | Verification evidence (tests, build) |

## Deep-Dive Data Flow

### Parallel Exploration Sequence

```mermaid
sequenceDiagram
    participant U as User
    participant O as Orchestrator
    participant ST as State File
    participant R1 as Riko: Structure
    participant R2 as Riko: Conventions
    participant R3 as Riko: Anti-patterns
    participant R4 as Riko: Build/CI
    participant R5 as Riko: Architecture
    participant R6 as Riko: Testing
    participant R7 as Riko: Purpose
    participant R8 as Riko: Key Flows
    participant S as Senku

    %% Initialization
    U->>O: /deep-dive
    O->>ST: init-deep-dive.sh
    ST-->>O: State initialized

    %% Phase 1: Parallel Exploration
    rect rgb(200, 230, 255)
        Note over O,R8: Phase 1: Parallel Exploration (8 explorers)
        par Fire all agents simultaneously
            O->>R1: Explore structure
            O->>R2: Explore conventions
            O->>R3: Find anti-patterns
            O->>R4: Analyze build/CI
            O->>R5: Map architecture
            O->>R6: Examine testing
            O->>R7: Purpose & use cases
            O->>R8: Trace key flows
        end
        par Agents return findings
            R1-->>O: Directory structure
            R2-->>O: Config files, patterns
            R3-->>O: DO NOT list
            R4-->>O: Build commands, CI
            R5-->>O: Component map
            R6-->>O: Test patterns
            R7-->>O: What it is, problems solved
            R8-->>O: file:line flow hops
        end
    end

    %% Phase 2: Synthesis
    rect rgb(200, 255, 200)
        Note over O,S: Phase 2: Synthesis
        O->>S: Merge all findings
        S->>S: Analyze, organize, deduplicate
        S-->>O: Unified context document
    end

    %% Phase 3: Compile
    rect rgb(255, 255, 200)
        Note over O,ST: Phase 3: Compile Output
        O->>ST: compile-deep-dive.sh
        ST-->>O: Context saved
    end

    O->>U: Deep-dive complete
```

### Data Gathered by Each Agent

| Agent | Explores | Output |
|-------|----------|--------|
| Structure | Directory layout | Entry points, packages, organization |
| Conventions | Config files | Naming patterns, style rules |
| Anti-patterns | Comments, docs | DO NOT list, warnings |
| Build/CI | Scripts, workflows | Test commands, CI pipeline |
| Architecture | Source code | Component map, dependencies |
| Testing | Test files | Framework, patterns, utilities |
| Purpose & Use Cases | README, docs, examples | What it is, problems solved, adoption modes |
| Key Flows | Source code | Numbered `file:line` hops per flow, failure notes |

## State File Data Flow

### Orchestration State Updates

```mermaid
flowchart TB
    subgraph Init["Initialization"]
        I1[init-orchestration.sh]
        I2["active: true<br/>current_phase: exploration<br/>iteration: 1"]
    end

    subgraph Phase1["Phase 1"]
        P1[Exploration complete]
        S1["current_phase: planning<br/>gates.exploration.status: passed"]
    end

    subgraph Phase2["Phase 2"]
        P2[Planning complete]
        S2["current_phase: implementation<br/>gates.planning.status: passed"]
    end

    subgraph Phase3["Phase 3"]
        P3[Implementation complete]
        S3["current_phase: review<br/>gates.implementation.status: passed"]
    end

    subgraph Phase4["Phase 4"]
        P4[Review complete]
        S4["current_phase: verification<br/>gates.review.status: passed"]
    end

    subgraph Phase5["Phase 5"]
        P5[Verification complete]
        S5["current_phase: complete<br/>active: false<br/>gates.verification.status: passed"]
    end

    I1 --> I2
    I2 --> P1 --> S1
    S1 --> P2 --> S2
    S2 --> P3 --> S3
    S3 --> P4 --> S4
    S4 --> P5 --> S5
```

### Deep-Dive State Updates

```mermaid
flowchart TB
    subgraph Init["Initialization"]
        I1[init-deep-dive.sh]
        I2["scope: full<br/>phase: initializing"]
    end

    subgraph Explore["Exploration"]
        E1[Agents complete]
        E2["(no state write)"]
    end

    subgraph Synth["Synthesis"]
        S1[Senku complete]
        S2["(no state write)"]
    end

    subgraph Output["Output"]
        O1[compile-deep-dive.sh]
        O2["phase: compilation, then complete<br/>(compile-deep-dive.sh --mark-complete)"]
    end

    I1 --> I2
    I2 --> E1 --> E2
    E2 --> S1 --> S2
    S2 --> O1 --> O2
```

## Hook Data Flow

### PreToolUse Flow

```mermaid
flowchart LR
    subgraph Agent["Agent Action"]
        A1[Write/Edit tool called]
    end

    subgraph PreHook["PreToolUse Hook"]
        H2[validate-changes.sh]
    end

    subgraph Decision["Decision"]
        D1{Path valid?}
        D2["Deny this tool call<br/>(permissionDecision: deny)"]
        D3[Allow silently]
    end

    A1 --> H2
    H2 --> D1
    D1 -->|No| D2
    D1 -->|Yes| D3
```

### PostToolUse Flow

```mermaid
flowchart LR
    subgraph Tool["Tool Execution"]
        T1[Any tool completes]
    end

    subgraph PostHook["PostToolUse Hook"]
        H1["log-event.sh postToolUse<br/>(matcherless)"]
    end

    subgraph Sink["Observability Sink"]
        S1[".claude/observability/events.db<br/>(tool_response truncated to 4000 chars)"]
    end

    T1 --> H1
    H1 --> S1
```

PostToolUse (like SubagentStop and SessionEnd) only logs events for observability; it does not verify or block anything. The former `Agent|Task` prompt hook was removed because it cost a Haiku call per subagent and falsely blocked background agents.

### Stop Hook Flow

```mermaid
flowchart TB
    subgraph Trigger["Task Completion"]
        T1[User sees response]
    end

    subgraph Hook["Stop Hook"]
        H1[verify-completion.sh]
        B1{"skip-test-verification<br/>file exists?"}
    end

    subgraph Gate["Change Gate"]
        G1{"Uncommitted non-doc<br/>changes?"}
        G2{"Fingerprint matches<br/>.verify-completion-pass?"}
    end

    subgraph Detect["Project Detection"]
        D0{Project dir<br/>accessible?}
        D1{package.json?}
        D2{"pyproject.toml<br/>or setup.py?"}
    end

    subgraph Verify["Verification (independent blocks)"]
        V1["npm test; tsc if tsconfig.json<br/>and local node_modules/.bin/tsc"]
        V2[".claude/test-command > uv run pytest > pytest;<br/>mypy if mypy.ini"]
    end

    subgraph Result["Result"]
        R0[Skip: exit silently]
        R1[Pass: cache fingerprint, allow silently]
        R2["Fail: Block completion<br/>(last 15 lines of output)"]
    end

    T1 --> H1
    H1 --> B1
    B1 -->|Yes| R0
    B1 -->|No| D0
    D0 -->|No| R2
    D0 -->|Yes| G1
    G1 -->|No| R0
    G1 -->|Yes| G2
    G2 -->|Yes| R0
    G2 -->|No| D1
    D1 -->|Yes| V1
    D1 --> D2
    D2 -->|Yes| V2
    D2 -->|No| R1

    V1 & V2 --> R1 & R2
```

## Integration Points

### Deep-Dive to Orchestrate

```mermaid
flowchart LR
    subgraph DeepDive["Deep-Dive"]
        DD1["/deep-dive"]
        DD2["deep-dive.local.md<br/>(phase: complete)"]
    end

    subgraph Orchestrate["Orchestrate"]
        O1["/orchestrate --use-deep-dive"]
        O2["Check deep-dive exists"]
        O3["Load context"]
        O4["Targeted exploration"]
    end

    DD1 --> DD2
    DD2 -.-> O1
    O1 --> O2
    O2 --> O3
    O3 --> O4
```

### Iteration Loop

```mermaid
flowchart TB
    subgraph Main["Main Flow"]
        M1[Implementation]
        M2[Review]
        M3[Verification]
        M4[Complete]
    end

    subgraph Iteration["Review-fix rounds (capped 1 / 2 / 3)"]
        I1{Blocking findings?}
        I3[One batched Loid fix]
        I4{Round < cap?}
        I6{Last round reduced open ERRORs?}
        I5["Stop: status capped<br/>Open findings, no promise"]
    end

    M1 --> M2 & M3
    M2 & M3 --> I1
    I1 -->|No| M4
    I1 -->|Yes| I4
    I4 -->|Yes| I3
    I4 -->|No| I6
    I6 -->|Yes: one extra round| I3
    I6 -->|No| I5
    I3 -->|Re-review fix diff, Alphonse re-runs| I1
```

## Related Documentation

- [Architecture Overview](overview.md) - System design
- [Commands Reference](../reference/commands.md) - Command specifications
- [Hooks Reference](../reference/hooks.md) - Hook system details
- [State Files Reference](../reference/state-files.md) - State file formats
