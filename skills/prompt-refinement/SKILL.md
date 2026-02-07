---
name: prompt-refinement
description: This skill should be used when the user provides a vague request, asks to clarify requirements, structure a task, or refine a prompt for multi-agent orchestration.
---

# Prompt Refinement

## Overview

Prompt refinement transforms ambiguous or incomplete user requests into clear, structured task specifications suitable for multi-agent orchestration. This skill bridges natural language input and the precise specifications required by downstream agents.

### Purpose

Ensure tasks entering the orchestration pipeline have:

- **Clear Objectives**: A single, well-defined goal that can be verified
- **Actionable Steps**: Concrete actions that agents can execute
- **Measurable Outcomes**: Success criteria that verification agents can check
- **Appropriate Scope**: Boundaries that prevent scope creep

### When to Use This Skill

Apply prompt refinement when:
- User input contains ambiguous terms ("fix it", "make it better")
- The request lacks specific targets (files, components, systems)
- Multiple interpretations of the request are possible
- Pre-processing is required for `/orchestrate` or `/plan` commands

### Key Principles

1. **Ask First, Act Second**: When genuinely ambiguous, clarify before proceeding
2. **One Question at a Time**: Never overwhelm users with multiple clarification requests
3. **Provide Options**: Give concrete choices to speed up clarification
4. **Default Gracefully**: Make reasonable assumptions when users don't respond
5. **Preserve Intent**: Refinement should clarify, not change the user's goal

---

## Refinement Template

### Standard Format

```
**Goal**: <one-sentence objective stating what will be accomplished>

**Description**: <2-3 sentences providing context, constraints, and scope>

**Actions**:
1. <specific, atomic action with clear target>
2. <specific, atomic action with clear target>
3. ...
```

### Template Guidelines

| Field | Requirements | Example |
|-------|--------------|---------|
| Goal | Single sentence, verb-first, specific outcome | "Implement rate limiting on /api/users endpoint" |
| Description | Context, scope boundaries, constraints | "Add rate limiting to prevent API abuse. Limit to 100 req/min per IP." |
| Actions | Numbered, ordered, atomic steps | "1. Explore existing middleware patterns" |

### Action Step Pattern

1. **Explore**: Investigate existing code, patterns, dependencies
2. **Plan**: Design approach based on exploration
3. **Implement**: Execute the core changes
4. **Test**: Add or update tests
5. **Verify**: Confirm implementation meets requirements

---

## Ambiguity Detection

### Quick Detection Checklist

A prompt likely needs clarification if:
- [ ] No identifiable action (what to do)
- [ ] No specific target (where to do it)
- [ ] No expected outcome (success criteria)
- [ ] Insufficient context (constraints, environment)

### Ambiguity Signals

| Signal | Example | Issue |
|--------|---------|-------|
| Missing scope | "fix the bug" | Which bug? Where? |
| Vague outcome | "make it better" | Better how? |
| Multiple meanings | "update the API" | Which endpoint? What change? |
| Implicit assumptions | "deploy it" | Where? How? |

For detailed ambiguity detection, see [references/ambiguity-detection.md](references/ambiguity-detection.md).

---

## Clarification Strategy

### Question Format

```
Before I proceed, I need to clarify:

<single focused question>

Options:
A) <most likely option>
B) <second most likely>
C) <third option if applicable>
D) Something else (please specify)
```

### Clarification Rules

| Rule | Rationale |
|------|-----------|
| Single question | Reduces cognitive load |
| Concrete options | Speeds up response |
| Max two rounds | Avoids frustration |
| Include escape hatch | Prevents forced incorrect choice |

### When to Clarify vs. Assume

**Always Clarify**:
- Could cause data loss
- Affects security
- Mutually exclusive interpretations
- Production system impact

**Safe to Assume**:
- Obvious default exists
- Context suggests intent
- Low-risk, reversible operations

For detailed clarification strategies, see [references/clarification-strategies.md](references/clarification-strategies.md).

---

## Orchestration Detection

### Prompts Requiring Orchestration

| Category | Example |
|----------|---------|
| Multi-file changes | "Add authentication to all routes" |
| Feature implementations | "Implement dark mode" |
| Bug investigation | "Fix the login issue" |
| Refactoring | "Refactor user service" |
| Integration | "Integrate Stripe" |

### Pass-Through Prompts

| Category | Example |
|----------|---------|
| Questions | "What does this function do?" |
| Single-file edits | "Add comment to line 42" |
| Git operations | "Commit these changes" |
| Documentation lookups | "Show API endpoints" |

### Quick Decision

```
Is it a question about existing code? -> Pass through
Does it require code changes? -> If no, pass through
Is target explicit AND single file? -> Pass through
Otherwise -> Refine for orchestration
```

For detailed orchestration detection, see [references/orchestration-detection.md](references/orchestration-detection.md).

---

## Refinement Process

### Step 1: Classify Prompt

```
Is it orchestration-related?
├── NO -> Pass through unchanged
└── YES -> Continue to Step 2
```

### Step 2: Detect Ambiguity

```
Check ambiguity signals
├── High ambiguity -> Go to Step 3 (Clarify)
└── Low ambiguity -> Go to Step 4 (Refine)
```

### Step 3: Request Clarification

1. Identify primary ambiguity
2. Formulate single focused question
3. Provide 3-4 concrete options
4. Wait for response (max 2 rounds)

### Step 4: Apply Template

1. Extract Goal (single sentence, specific)
2. Build Description (context, scope, constraints)
3. Decompose Actions (atomic, ordered steps)
4. Validate completeness

---

## Quick Reference

### Ambiguity Score Quick Guide

| Score | Action |
|-------|--------|
| 0-2 | Proceed with refinement |
| 3-4 | State assumption and proceed |
| 5+ | Ask clarifying question |

### Refinement Decision Matrix

| Prompt Type | Action |
|-------------|--------|
| Clear + orchestration | Refine to template |
| Ambiguous + orchestration | Clarify then refine |
| Clear + non-orchestration | Pass through |
| Ambiguous + non-orchestration | Minimal clarification |

---

## Additional Resources

### Reference Files

- [references/ambiguity-detection.md](references/ambiguity-detection.md) - Detecting ambiguous prompts
- [references/clarification-strategies.md](references/clarification-strategies.md) - Clarification question strategies
- [references/orchestration-detection.md](references/orchestration-detection.md) - Orchestration eligibility detection
- [references/refinement-techniques.md](references/refinement-techniques.md) - Advanced refinement techniques

### Examples

- [examples/refinement-scenarios.md](examples/refinement-scenarios.md) - Worked refinement examples

### Related Skills

- **task-classification**: Receives refined prompts for complexity assessment
- **agent-behavior-constraints**: Ensures refinement stays within agent boundaries
- **verification-gates**: Uses refined specifications for verification criteria
