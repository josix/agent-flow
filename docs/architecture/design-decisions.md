# Design Decisions

Architectural Decision Records (ADRs) documenting the key design choices in Agent Flow.

## ADR-001: Multi-Agent Architecture

### Context

When building an AI-assisted development system, we need to decide between:
1. A single general-purpose agent handling all tasks
2. Multiple specialized agents with focused responsibilities

### Decision

**Use multiple specialized agents** with distinct roles, tools, and behavioral guidelines.

### Rationale

1. **Separation of Concerns**: Each agent has a clear responsibility
   - Exploration is separate from implementation
   - Implementation is separate from verification
   - This prevents shortcuts and ensures thoroughness

2. **Tool Restriction**: Agents only have tools they need
   - Explorers can't modify files (prevents accidental changes)
   - Implementers can't skip verification (no temptation)
   - Verifiers can't fix issues (forces handback)

3. **Model Optimization**: Different tasks need different capabilities
   - Strategic planning benefits from deeper reasoning (Opus)
   - Execution benefits from speed (Sonnet)
   - Cost is optimized by matching model to task

4. **Independent Verification**: Self-verification is unreliable
   - Agents reviewing their own work have inherent bias
   - Separate verifiers provide objective assessment

### Consequences

- **Positive**: Clear responsibilities, better verification, cost optimization
- **Negative**: More complexity, context passing overhead

### Alternatives Considered

1. **Single Agent with Modes**: One agent switching between modes
   - Rejected: No clear boundaries, self-verification issues

2. **Parallel Agents with Consensus**: Multiple agents vote on decisions
   - Rejected: Overhead without clear benefit for development tasks

---

## ADR-002: Verification-First Philosophy

### Context

LLMs can generate confident claims about task completion without actual verification. We need to determine how to handle this.

### Decision

**Require evidence, not claims.** Every significant assertion must be backed by actual command output.

### Rationale

1. **LLMs Hallucinate Completion**: Models report success based on patterns, not memories
   - "Tests pass" is easy to generate without running tests
   - Confidence doesn't correlate with accuracy

2. **Evidence is Verifiable**: Command output can be checked
   - Test results show actual pass/fail
   - Type errors are explicit
   - Build failures are undeniable

3. **Prevention Over Detection**: Better to require evidence than detect lies
   - Evidence requirements prevent false claims
   - Detection is unreliable with capable models

### Consequences

- **Positive**: Reliable completion status, caught errors, user confidence
- **Negative**: Slower workflows, more verbose output

### Alternatives Considered

1. **Trust Agent Claims**: Accept completion statements at face value
   - Rejected: High false positive rate, bugs ship

2. **Sample Verification**: Randomly verify some claims
   - Rejected: Inconsistent quality, some bugs slip through

---

## ADR-003: Model Tier Strategy

### Context

Different AI models have different capabilities and costs. We need to decide how to allocate models to tasks.

### Decision

**Use two model tiers:**
- **Opus** for strategic/planning tasks (Riko, Senku)
- **Sonnet** for execution/verification tasks (Loid, Lawliet, Alphonse)

### Rationale

1. **Opus Strengths**: Deep reasoning, complex analysis
   - Valuable for unfamiliar codebase exploration
   - Important for multi-step planning
   - Worth the cost for strategic decisions

2. **Sonnet Strengths**: Speed, clear task execution
   - Sufficient for well-defined implementation
   - Fast iterations for review cycles
   - Cost-effective for command execution

3. **Cost Optimization**: Not all tasks need maximum capability
   - Running tests doesn't require deep reasoning
   - Implementing a clear plan is straightforward
   - Save expensive model for high-value decisions

### Consequences

- **Positive**: Cost efficiency, appropriate capability matching
- **Negative**: Potential capability gaps, model switching overhead

### Alternatives Considered

1. **All Opus**: Use best model everywhere
   - Rejected: Excessive cost for simple tasks

2. **All Sonnet**: Use fast model everywhere
   - Rejected: Insufficient for complex exploration/planning

3. **Dynamic Selection**: Choose model per-task
   - Rejected: Complexity without clear benefit over role-based

---

## ADR-004: Hook-Based Lifecycle

### Context

We need to inject behavior at specific points in the Claude Code lifecycle for validation and guidance.

### Decision

**Use hooks at lifecycle events:**
- UserPromptSubmit: Prompt refinement
- PreToolUse: Operation validation
- PostToolUse: Result verification
- SessionStart: Context loading
- Stop: Completion gates

### Rationale

1. **Non-Invasive**: Hooks augment without modifying core behavior
   - Claude Code remains unchanged
   - Plugin adds capabilities through hooks

2. **Targeted Intervention**: Each hook has a specific purpose
   - Validation happens before operations
   - Verification happens after operations
   - Gates happen before completion

3. **Extensible**: New behaviors can be added via hooks
   - No core changes needed
   - Multiple hooks can run at same point

### Consequences

- **Positive**: Clean integration, extensible, targeted
- **Negative**: Limited to supported hook points, execution overhead

### Alternatives Considered

1. **Core Modification**: Modify Claude Code directly
   - Rejected: Not maintainable, version coupling

2. **Wrapper Approach**: Intercept all operations
   - Rejected: Too invasive, performance impact

---

## ADR-005: State File Design

### Context

Workflows span multiple agent interactions and need persistent state tracking.

### Decision

**Use YAML-frontmatter Markdown files** in `.claude/` directory:
- Human readable
- Machine parseable
- Git-ignorable
- Session-scoped

### Rationale

1. **Dual-Purpose Format**: YAML for structured data, Markdown for logs
   - Frontmatter holds machine-parseable state
   - Body holds human-readable history

2. **Local Storage**: Files in `.claude/` directory
   - No external dependencies
   - Easy to inspect and debug
   - Can be safely deleted

3. **Session Scope**: Files are ephemeral
   - Not committed to git
   - Fresh state each session
   - No stale state issues

### Consequences

- **Positive**: Simple, debuggable, no dependencies
- **Negative**: No persistence across sessions (by design), file I/O overhead

### Alternatives Considered

1. **In-Memory State**: Keep state in conversation context
   - Rejected: Lost on context overflow, hard to debug

2. **Database Storage**: Use SQLite or similar
   - Rejected: Overkill for session-scoped state

---

## ADR-006: Skill System Architecture

### Context

Domain expertise needs to be encoded and shared across agents.

### Decision

**Create skill modules** with:
- Owner agent (maintains the skill)
- Consumer agents (reference the skill)
- Reference materials (detailed documentation)
- Examples (worked scenarios)

### Rationale

1. **Ownership Model**: Clear responsibility for each skill
   - One agent owns each skill
   - Consumers reference but don't modify
   - Prevents conflicting guidance

2. **Documentation as Code**: Skills are markdown files
   - Version controlled
   - Easy to update
   - Human readable

3. **Hierarchical Structure**: SKILL.md + references + examples
   - Quick reference in main file
   - Deep dive in references
   - Practical guidance in examples

### Consequences

- **Positive**: Clear ownership, extensible, documented
- **Negative**: Potential inconsistency, maintenance burden

### Alternatives Considered

1. **Inline Prompts**: Embed all guidance in agent prompts
   - Rejected: Duplication, hard to maintain

2. **Shared Knowledge Base**: Single document for all agents
   - Rejected: No ownership, conflicting guidance

---

## ADR-007: Tool Access Control

### Context

Agents need different capabilities for their roles. Unrestricted access enables shortcuts.

### Decision

**Restrict tools per agent role:**
- Only Loid can Write/Edit
- Only Riko can WebSearch/WebFetch
- Only Senku can TodoWrite

### Rationale

1. **Prevents Shortcuts**: Agents can't do others' jobs
   - Explorer can't "just fix it" while exploring
   - Verifier can't modify code to make tests pass
   - Planner can't skip to implementation

2. **Clear Boundaries**: Role is enforced by capability
   - Not just guidance but actual restriction
   - Agents don't need to resist temptation

3. **Audit Trail**: Actions map to responsible agents
   - File modifications came from Loid
   - Web research came from Riko
   - Plans came from Senku

### Consequences

- **Positive**: Clear boundaries, enforced specialization, accountability
- **Negative**: Requires handoffs, potential delays

### Alternatives Considered

1. **All Tools for All Agents**: Trust agents to use appropriately
   - Rejected: Temptation too strong, boundaries blur

2. **Request-Based Access**: Agents request tools as needed
   - Rejected: Overhead without clear benefit

---

## ADR-008: Iteration and Failure Handling

### Context

Verification may fail, requiring iteration. We need to handle this gracefully.

### Decision

**Implement iteration loops with maximum bounds:**
- Failed verification returns to implementation
- Iteration counter tracks attempts
- Maximum iterations prevent infinite loops
- State tracks iteration history

### Rationale

1. **Reality of Development**: Not all implementations pass first try
   - Tests may reveal bugs
   - Review may find issues
   - Iteration is normal

2. **Bounded Iteration**: Maximum prevents runaway
   - Default 10 iterations
   - Configurable per task
   - Fails cleanly at limit

3. **State Tracking**: History enables debugging
   - Each iteration logged
   - Failure reasons recorded
   - Pattern analysis possible

### Consequences

- **Positive**: Handles reality, bounded, debuggable
- **Negative**: May hit limit on complex tasks, overhead

### Alternatives Considered

1. **No Iteration**: Fail on first error
   - Rejected: Too strict, wastes progress

2. **Unbounded Iteration**: Keep trying until success
   - Rejected: Potential infinite loops, cost concerns

---

## Summary

These decisions collectively create a system that:

1. **Specializes agents** for clear responsibilities
2. **Requires evidence** for reliable verification
3. **Optimizes costs** with model tiers
4. **Integrates cleanly** through hooks
5. **Tracks state** with simple files
6. **Shares expertise** through skills
7. **Enforces boundaries** with tool restrictions
8. **Handles failure** with bounded iteration

The overall philosophy: **build in constraints that prevent problems rather than detecting them after the fact**.

## Related Documentation

- [Architecture Overview](overview.md) - System design
- [Data Flows](data-flows.md) - Information flow
- [The "Subagents LIE" Principle](../concepts/subagents-lie.md) - Core problem
- [Agent Specialization](../concepts/agent-specialization.md) - Agent design
