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

    %% Initialization
    U->>O: /orchestrate "Add auth feature"
    O->>H: UserPromptSubmit
    H->>H: Prompt refinement check
    H-->>O: Refined prompt (if needed)
    O->>ST: init-orchestration.sh
    ST-->>O: State initialized

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
        S->>S: Analyze, TodoWrite
        S-->>O: Implementation plan
        O->>ST: update-state --phase implementation
    end

    %% Phase 3: Implementation
    rect rgb(255, 255, 200)
        Note over O,L: Phase 3: Implementation
        O->>L: Task: Implement plan
        L->>H: PreToolUse (Write/Edit)
        H-->>L: Allowed
        L->>L: Write, Edit, Bash
        L->>H: PostToolUse
        H-->>L: Validation passed
        L-->>O: Changes made + sanity tests
        O->>ST: update-state --phase review
    end

    %% Phase 4: Review
    rect rgb(255, 230, 200)
        Note over O,LW: Phase 4: Review
        O->>LW: Task: Review changes
        LW->>LW: Static analysis (tsc, eslint)
        alt NEEDS_CHANGES
            LW-->>O: Issues found
            O->>L: Fix issues
            L-->>O: Fixed
            O->>LW: Re-review
        end
        LW-->>O: APPROVED
        O->>ST: update-state --phase verification
    end

    %% Phase 5: Verification
    rect rgb(255, 200, 200)
        Note over O,A: Phase 5: Verification
        O->>A: Task: Verify all
        A->>A: npm test, tsc, lint, build
        alt FAILED
            A-->>O: Failures (with output)
            O->>L: Fix failures
            L-->>O: Fixed
            O->>A: Re-verify
        end
        A-->>O: VERIFIED (with evidence)
        O->>ST: update-state --complete
    end

    %% Completion
    O->>H: Stop hook
    H->>H: verify-completion.sh
    H-->>O: Gates passed
    O->>U: TASK VERIFIED
```

### Data Passed Between Phases

| From | To | Data |
|------|-----|------|
| User | Orchestrator | Task description |
| Hooks | Orchestrator | Refined prompt |
| Orchestrator | State | Phase transitions, gate results |
| Riko | Orchestrator | Files, patterns, architecture |
| Orchestrator | Senku | Task + Riko's findings |
| Senku | Orchestrator | Implementation plan |
| Orchestrator | Loid | Plan + context |
| Loid | Orchestrator | Changed files + test results |
| Orchestrator | Lawliet | Changed files list |
| Lawliet | Orchestrator | Review verdict + issues |
| Orchestrator | Alphonse | Full codebase |
| Alphonse | Orchestrator | Verification evidence |

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
    participant S as Senku

    %% Initialization
    U->>O: /deep-dive
    O->>ST: init-deep-dive.sh
    ST-->>O: State initialized

    %% Phase 1: Parallel Exploration
    rect rgb(200, 230, 255)
        Note over O,R6: Phase 1: Parallel Exploration
        par Fire all agents simultaneously
            O->>R1: Explore structure
            O->>R2: Explore conventions
            O->>R3: Find anti-patterns
            O->>R4: Analyze build/CI
            O->>R5: Map architecture
            O->>R6: Examine testing
        end
        par Agents return findings
            R1-->>O: Directory structure
            R2-->>O: Config files, patterns
            R3-->>O: DO NOT list
            R4-->>O: Build commands, CI
            R5-->>O: Component map
            R6-->>O: Test patterns
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

## State File Data Flow

### Orchestration State Updates

```mermaid
flowchart TB
    subgraph Init["Initialization"]
        I1[init-orchestration.sh]
        I2["active: true<br/>phase: exploration<br/>iteration: 1"]
    end

    subgraph Phase1["Phase 1"]
        P1[Exploration complete]
        S1["phase: planning<br/>gates.exploration: passed"]
    end

    subgraph Phase2["Phase 2"]
        P2[Planning complete]
        S2["phase: implementation<br/>gates.planning: passed"]
    end

    subgraph Phase3["Phase 3"]
        P3[Implementation complete]
        S3["phase: review<br/>gates.implementation: passed"]
    end

    subgraph Phase4["Phase 4"]
        P4[Review complete]
        S4["phase: verification<br/>gates.review: passed"]
    end

    subgraph Phase5["Phase 5"]
        P5[Verification complete]
        S5["phase: complete<br/>gates.verification: passed"]
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
        I2["scope: full<br/>phase: exploring"]
    end

    subgraph Explore["Exploration"]
        E1[Agents complete]
        E2["phase: synthesizing"]
    end

    subgraph Synth["Synthesis"]
        S1[Senku complete]
        S2["phase: compiling"]
    end

    subgraph Output["Output"]
        O1[compile-deep-dive.sh]
        O2["phase: complete"]
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
        H1[enforce-delegation.sh]
        H2[validate-changes.sh]
    end

    subgraph Decision["Decision"]
        D1{Path valid?}
        D2[Block operation]
        D3[Allow operation]
    end

    A1 --> H1
    H1 --> H2
    H2 --> D1
    D1 -->|No| D2
    D1 -->|Yes| D3
```

### PostToolUse Flow

```mermaid
flowchart LR
    subgraph Tool["Tool Execution"]
        T1[Task tool completes]
    end

    subgraph PostHook["PostToolUse Hook"]
        H1[Prompt hook]
        H2[Verify based on agent type]
    end

    subgraph Guidance["Verification Guidance"]
        G1[Riko: Accept findings]
        G2[Senku: Review plan]
        G3[Loid: Full verification]
        G4[Lawliet: Consider feedback]
        G5[Alphonse: Check results]
    end

    T1 --> H1
    H1 --> H2
    H2 --> G1 & G2 & G3 & G4 & G5
```

### Stop Hook Flow

```mermaid
flowchart TB
    subgraph Trigger["Task Completion"]
        T1[User sees response]
    end

    subgraph Hook["Stop Hook"]
        H1[verify-completion.sh]
    end

    subgraph Detect["Project Detection"]
        D1{package.json?}
        D2{pyproject.toml?}
        D3{Cargo.toml?}
        D4{go.mod?}
    end

    subgraph Verify["Verification"]
        V1[npm test]
        V2[pytest]
        V3[cargo test]
        V4[go test]
    end

    subgraph Result["Result"]
        R1[Pass: Allow completion]
        R2[Fail: Block completion]
    end

    T1 --> H1
    H1 --> D1
    D1 -->|Yes| V1
    D1 -->|No| D2
    D2 -->|Yes| V2
    D2 -->|No| D3
    D3 -->|Yes| V3
    D3 -->|No| D4
    D4 -->|Yes| V4

    V1 & V2 & V3 & V4 --> R1 & R2
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

    subgraph Iteration["Iteration Loop"]
        I1{Review passed?}
        I2{Verification passed?}
        I3[Increment iteration]
        I4{Max iterations?}
        I5[Fail task]
    end

    M1 --> M2 --> I1
    I1 -->|Yes| M3 --> I2
    I1 -->|No| I3
    I2 -->|Yes| M4
    I2 -->|No| I3
    I3 --> I4
    I4 -->|No| M1
    I4 -->|Yes| I5
```

## Related Documentation

- [Architecture Overview](overview.md) - System design
- [Commands Reference](../reference/commands.md) - Command specifications
- [Hooks Reference](../reference/hooks.md) - Hook system details
- [State Files Reference](../reference/state-files.md) - State file formats
