# Clarification Strategies

Strategies and patterns for effectively gathering clarification from users in the multi-agent orchestration system.

---

## 1. Clarification Question Format

Standard format for clarification questions:

```
Before I proceed, I need to clarify:

<single focused question>

Options:
A) <most likely option based on context>
B) <second most likely option>
C) <third option if applicable>
D) Something else (please specify)
```

---

## 2. Clarification Rules

| Rule | Description | Rationale |
|------|-------------|-----------|
| Single question | Ask only ONE question at a time | Reduces cognitive load |
| Concrete options | Provide specific choices | Speeds up response |
| Ranked options | Order most to least likely | Guides decision-making |
| Escape hatch | Always include "Something else" | Prevents forcing incorrect choice |
| Max two rounds | Never ask more than 2 questions | Avoids frustration |
| Default behavior | State default if no response | Enables progress |

---

## 3. Question Formulation Patterns

### Pattern 1: Binary Choice

Best for clear either/or situations.

```
Should I [option A] or [option B]?
```

**Example**:
```
Should I add rate limiting per IP address or per user account?
```

### Pattern 2: Multiple Choice

Best for 3-5 distinct options.

```
What type of [X] are you looking for?

Options:
A) [option 1] - [brief description]
B) [option 2] - [brief description]
C) [option 3] - [brief description]
D) Something else (please specify)
```

**Example**:
```
What type of caching should I implement?

Options:
A) In-memory cache - fast, local to process
B) Redis cache - shared across instances
C) HTTP cache headers - client-side
D) Something else (please specify)
```

### Pattern 3: Confirmation

Best for validating an assumption.

```
I'll proceed with [assumption]. Is that correct, or did you mean something different?
```

**Example**:
```
I'll add rate limiting to the /api/users endpoint with a limit of 100 requests per minute per IP. Is that correct, or did you have different parameters in mind?
```

### Pattern 4: Scope Boundary

Best for unclear boundaries.

```
Which [components/files/areas] should this include?

A) Only [narrow scope]
B) All [medium scope]
C) Everything in [broad scope]
```

**Example**:
```
Which endpoints should have caching?

A) Only the /api/products endpoint
B) All GET endpoints in /api/
C) All public API endpoints
```

---

## 4. Question Prioritization

When multiple ambiguities exist, prioritize:

| Priority | Ambiguity Type | Action |
|----------|---------------|--------|
| 1 | Blocking | Must ask - cannot proceed |
| 2 | High-impact | Should ask - significantly changes approach |
| 3 | Scope | May ask or assume |
| 4 | Detail | Resolve during implementation |

**Rule**: Only ask about priority 1 and 2. Resolve 3 and 4 with assumptions.

---

## 5. When to Clarify vs. Assume

### Always Clarify

- Request could cause data loss (DELETE, overwrite)
- Request affects security (auth, permissions, encryption)
- Request has mutually exclusive interpretations
- Request could affect production systems
- Cost or resource implications unclear

### Safe to Assume (with Statement)

- Obvious default exists (e.g., "add tests" = unit tests)
- Context strongly suggests intent
- Low-risk reversible operations
- Standard patterns apply
- Conversation history provides clarity

### Assumption Statement Format

```
I'll proceed with [assumption] since [reasoning]. Let me know if you meant something different.
```

**Example**:
```
I'll proceed with adding unit tests using Jest since that's the test framework configured in your project. Let me know if you meant a different type of tests.
```

---

## 6. Clarification Anti-Patterns

### Avoid These Mistakes

| Anti-Pattern | Problem | Better Approach |
|--------------|---------|-----------------|
| Multiple questions | Overwhelms user | One question at a time |
| Too many options | Decision paralysis | Max 4-5 options |
| Technical jargon | Confuses non-experts | Use plain language |
| Implementation details | Not user's concern | Decide yourself |
| Re-asking | Frustrating | Accept and proceed |
| Over-clarifying | Wastes time | Infer when possible |

---

## 7. No-Response Handling

When user does not respond to clarification:

### Timeout Strategy

```
1. Wait reasonable time (context-dependent)
2. State default assumption clearly
3. Proceed with most likely interpretation
4. Note that alternative is available
```

### Default Statement Format

```
Since I haven't heard back, I'll proceed with [default assumption] as the most common case. Let me know if you'd prefer a different approach.
```

---

## 8. Progressive Clarification

For complex requests requiring multiple clarifications:

### Round Limits

- Maximum 2 clarification rounds
- After 2 rounds, state assumptions and proceed
- Document any remaining uncertainty

### Progressive Example

**Round 1**: What data to export?
**Response**: Transaction history

**Round 2**: What format?
**Response**: CSV

**Proceed**: With full context to refine

---

## 9. Contextual Adaptation

### New User

- More explicit options
- Explain implications
- Provide examples

### Experienced User

- Shorter questions
- Technical options acceptable
- Assume domain knowledge

### Follow-up Questions

- Reference previous context
- Build on prior answers
- Avoid repetition

---

## 10. Response Handling

### Clear Response

Accept and proceed with refinement.

### Partial Response

Fill in gaps with reasonable assumptions, state them.

### Conflicting Response

Seek clarification on the conflict specifically.

### Non-Answer

Restate the question more simply, or provide a default.

---

## See Also

- [SKILL.md](../SKILL.md) - Main prompt refinement documentation
- [ambiguity-detection.md](ambiguity-detection.md) - How to detect ambiguity
- [orchestration-detection.md](orchestration-detection.md) - When to refine for orchestration
