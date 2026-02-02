# Model Selection Guide

Comprehensive guide for selecting appropriate AI models for agent tasks.

## Model Overview

### Available Models

| Model | Strengths | Cost | Speed |
|-------|-----------|------|-------|
| Opus | Deep reasoning, complex analysis, strategic planning | Higher | Slower |
| Sonnet | Fast execution, repetitive tasks, quick iterations | Lower | Faster |

---

## Agent Model Assignments

### Default Assignments

| Agent | Model | Primary Reason |
|-------|-------|----------------|
| Senku (Planner) | Opus | Strategic planning requires deep reasoning for task decomposition |
| Riko (Explorer) | Opus | Complex exploration needs thorough analysis of unfamiliar code |
| Loid (Executor) | Sonnet | Implementation benefits from speed with sufficient capability |
| Lawliet (Reviewer) | Sonnet | Review cycles need fast iteration for feedback loops |
| Alphonse (Verifier) | Sonnet | Verification is command-focused with clear pass/fail criteria |

---

## Model Selection Criteria

### When to Use Opus

Select Opus for tasks requiring:

1. **Deep Strategic Reasoning**
   - Multi-step planning with dependencies
   - Architectural decision-making
   - Trade-off analysis across multiple dimensions

2. **Complex Analysis**
   - Unfamiliar codebase exploration
   - Pattern recognition across large codebases
   - Root cause analysis of complex bugs

3. **Nuanced Understanding**
   - Ambiguous requirements interpretation
   - Context-heavy decision making
   - Subtle code quality assessments

4. **Creative Problem Solving**
   - Novel architectural approaches
   - Refactoring strategies for legacy code
   - Integration design for disparate systems

### When to Use Sonnet

Select Sonnet for tasks requiring:

1. **Fast Execution**
   - Well-defined implementation tasks
   - Straightforward code modifications
   - Command execution and verification

2. **Quick Iterations**
   - Review feedback cycles
   - Test-fix-verify loops
   - Build and deployment checks

3. **Repetitive Operations**
   - Bulk file modifications
   - Pattern-based refactoring
   - Consistent style enforcement

4. **Clear Criteria**
   - Pass/fail verification
   - Lint and type checking
   - Test execution

---

## Decision Framework

### Task Complexity Assessment

```
Low Complexity -> Sonnet
  - Clear inputs and outputs
  - Well-documented patterns to follow
  - Minimal decision points

Medium Complexity -> Context-Dependent
  - Some ambiguity in requirements
  - Multiple valid approaches
  - Moderate decision points

High Complexity -> Opus
  - Significant ambiguity
  - Novel solutions required
  - Many interconnected decisions
```

### Speed vs Quality Trade-off

```
Speed Priority -> Sonnet
  - Tight deadlines
  - Iterative refinement possible
  - Clear rollback path

Quality Priority -> Opus
  - Critical decisions
  - Limited iteration opportunity
  - High impact of errors
```

---

## Model Routing Rules

### Rule 1: Match Model to Role

- Planning and exploration use Opus by default
- Execution and verification use Sonnet by default
- Document any deviation with reasoning

### Rule 2: Consider Task Specifics

- Simple exploration task: May use Sonnet
- Complex implementation task: May use Opus
- The agent role is a guideline, not a rigid constraint

### Rule 3: Document Deviations

When routing differs from default:
```
Model Deviation Log:
- Task: [Description]
- Default Model: [Expected]
- Actual Model: [Used]
- Reason: [Justification]
```

---

## Cost Optimization

### Strategies

1. **Use Sonnet for bulk operations**
   - Multiple file reads
   - Repetitive searches
   - Straightforward edits

2. **Reserve Opus for key decisions**
   - Initial planning
   - Complex problem solving
   - Final architectural review

3. **Batch similar tasks**
   - Group file modifications
   - Combine related searches
   - Consolidate verification steps

### Anti-Patterns to Avoid

1. **Using Opus for simple commands**
   - Running tests does not require deep reasoning
   - File reads with clear purpose suit Sonnet

2. **Using Sonnet for ambiguous tasks**
   - Unclear requirements need Opus analysis
   - Novel problems require deeper reasoning

3. **Frequent model switching**
   - Context loss with each switch
   - Better to complete related tasks with same model
