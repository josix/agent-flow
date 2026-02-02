# Refinement Techniques Reference

Advanced techniques for prompt refinement, including heuristics, edge cases, and integration patterns with task-classification.

---

## 1. Advanced Ambiguity Detection

### Multi-Layer Ambiguity Analysis

When simple signal detection is insufficient, apply multi-layer analysis:

**Layer 1: Lexical Analysis**
- Identify pronouns without antecedents ("it", "that", "these")
- Flag subjective adjectives ("better", "faster", "cleaner", "nicer")
- Detect action verbs without objects ("fix", "update", "change")

**Layer 2: Semantic Analysis**
- Check for domain terms with multiple meanings
- Identify implicit assumptions in the request
- Detect scope modifiers that could vary ("all", "some", "relevant")

**Layer 3: Pragmatic Analysis**
- Consider conversation context and history
- Evaluate what the user likely means vs. what they said
- Assess organizational conventions and patterns

### Ambiguity Scoring System

Calculate an ambiguity score to determine action:

| Factor | Points | Description |
|--------|--------|-------------|
| Missing target | +3 | No file, component, or feature specified |
| Vague outcome | +2 | Subjective success criteria |
| Pronoun reference | +1 | "it", "that" without clear antecedent |
| Scope ambiguity | +2 | "all", "everywhere" without bounds |
| Multiple interpretations | +3 | Genuinely different valid readings |
| Implicit assumption | +1 | Unstated but required information |

**Score Thresholds**:
- 0-2: Proceed with refinement
- 3-4: State assumption and proceed
- 5-6: Ask one clarifying question
- 7+: Ask clarifying question, consider breaking down request

### Context-Sensitive Detection

Ambiguity depends on context. Consider:

**Codebase Context**:
- Is there only one "UserService"? Less ambiguous.
- Are there multiple "config" files? More ambiguous.
- Is the error message unique? Less ambiguous.

**Conversation Context**:
- Did user just mention a specific file? Pronoun likely refers to it.
- Were we discussing a bug? "Fix it" has clear reference.
- Is this a follow-up? Previous context applies.

**User Context**:
- Experienced users may use shorthand intentionally
- New users may not know what details are needed
- Adjust clarification style accordingly

---

## 2. Clarification Question Strategies

### Question Formulation Patterns

**Pattern 1: Binary Choice**
Best for: clear either/or situations

```
Should I [option A] or [option B]?
```

Example:
```
Should I add rate limiting per IP address or per user account?
```

**Pattern 2: Multiple Choice**
Best for: 3-5 distinct options

```
What type of [X] are you looking for?

Options:
A) [option 1] - [brief description]
B) [option 2] - [brief description]
C) [option 3] - [brief description]
D) Something else (please specify)
```

**Pattern 3: Confirmation**
Best for: validating an assumption

```
I'll proceed with [assumption]. Is that correct, or did you mean something different?
```

**Pattern 4: Scope Boundary**
Best for: unclear boundaries

```
Which [components/files/areas] should this include?

A) Only [narrow scope]
B) All [medium scope]
C) Everything in [broad scope]
```

### Question Prioritization

When multiple ambiguities exist, prioritize:

1. **Blocking ambiguities**: Cannot proceed at all without answer
2. **High-impact ambiguities**: Answer significantly changes approach
3. **Scope ambiguities**: Answer affects work estimate
4. **Detail ambiguities**: Can often be resolved during implementation

Only ask about #1 and #2. Resolve #3 and #4 with assumptions.

### Avoiding Question Fatigue

**Do**:
- Combine related clarifications into one question when possible
- Use defaults liberally for low-impact choices
- State assumptions proactively

**Don't**:
- Ask about implementation details (that's your job)
- Request information you can discover from code
- Ask about preferences that don't affect outcome

---

## 3. Refinement Heuristics

### Goal Extraction Heuristics

**Heuristic 1: Verb-Object-Purpose**
Structure goals as: [Verb] [Object] [Purpose]

- Input: "Add caching to speed up the API"
- Goal: "Implement caching for API responses to improve response times"

**Heuristic 2: Success State Description**
Ask: "What will be true when this is done?"

- Input: "Fix the login bug"
- Think: "When done, users will be able to log in successfully"
- Goal: "Resolve the login failure preventing user authentication"

**Heuristic 3: Behavior Change**
Focus on what behavior changes:

- Input: "Refactor the user service"
- Think: What behavior should be different? (None - it's internal)
- Goal: "Restructure UserService for improved maintainability while preserving existing behavior"

### Action Decomposition Heuristics

**Heuristic 1: Explore-Plan-Implement-Verify**
Standard decomposition pattern:

1. Explore existing code/patterns
2. Plan implementation approach
3. Implement core changes
4. Add/update tests
5. Verify behavior

**Heuristic 2: Dependency Order**
Order actions by dependencies:

- What must exist before this action can start?
- What will this action produce that others need?
- Are there parallel tracks possible?

**Heuristic 3: Risk-First Order**
High-risk changes early, low-risk late:

- Validate assumptions early
- Make breaking changes before additive changes
- Test core functionality before edge cases

### Scope Boundary Heuristics

**Heuristic 1: Natural Boundaries**
Look for natural scope limits:

- Single module/package
- One API endpoint
- One user flow
- One data type

**Heuristic 2: Change Propagation**
Trace how changes propagate:

- If I change X, what else must change?
- Where does the ripple effect stop?
- Are there interface boundaries?

**Heuristic 3: Test Boundaries**
Use test coverage as scope indicator:

- What would existing tests catch?
- What new tests are needed?
- Where are the test seams?

---

## 4. Edge Cases and Special Patterns

### Compound Requests

When users combine multiple tasks:

**Detection**: Multiple verbs, "and", "also", "then"

**Handling**:
1. Identify if tasks are related or independent
2. If related: treat as single complex task
3. If independent: clarify priority or split

Example:
- Related: "Add validation and error handling to the form"
- Independent: "Fix the login bug and add a new settings page"

For independent tasks:
```
I see two separate tasks here:
1. Fix the login bug
2. Add settings page

Should I address these in order, or is one more urgent?
```

### Implicit Context Requests

When users reference prior conversation:

**Detection**: "that", "it", "the one we discussed", minimal context

**Handling**:
1. Scan conversation history for antecedent
2. If found and unambiguous, proceed
3. If ambiguous, confirm interpretation

```
You mentioned "fix that error" - I believe you're referring to the
authentication timeout we discussed earlier. Proceeding with that fix.
```

### Negation Requests

When users describe what NOT to do:

**Detection**: "don't", "without", "except", "but not"

**Handling**:
1. Identify the excluded behavior/scope
2. Explicitly state what WILL be done
3. Confirm the boundary

Example:
- Input: "Refactor the API but don't change the endpoints"
- Refinement: "Restructure API internals while preserving all existing endpoint signatures"

### Open-Ended Requests

When requests have no natural boundary:

**Detection**: "improve", "optimize", "clean up", open-ended verbs

**Handling**:
1. Propose a concrete scope
2. Define stopping criteria
3. Set expectations

```
"Clean up the codebase" is quite broad. I'll focus on:
- Removing unused imports
- Fixing lint errors
- Updating deprecated patterns

This will affect approximately [X] files. Should I proceed, or did you have specific areas in mind?
```

---

## 5. Integration with Task Classification

### Pre-Classification Refinement

Prompt refinement prepares tasks for classification by:

1. **Removing ambiguity** that would confuse classification
2. **Extracting scope indicators** (file count, components affected)
3. **Identifying risk factors** mentioned in the request
4. **Structuring actions** in a classifiable format

### Information Handoff

Refined prompts should provide task-classification with:

| Information | Purpose | Example |
|-------------|---------|---------|
| Clear objective | Determine task category | "Implement rate limiting" |
| Scope hints | Estimate file count | "on all API endpoints" |
| Risk indicators | Assess verification needs | "for security" |
| Action list | Verify completeness | "explore, implement, test" |

### Classification Feedback Loop

When task-classification reveals scope issues:

1. Classification finds more files than expected
2. Prompts re-refinement with new scope information
3. Updated specification returned to user
4. User confirms or adjusts

```
After exploring the codebase, I found this affects 12 files rather than
the 3 I initially estimated. The task scope should be updated to:

[Updated specification]

Should I proceed with this expanded scope?
```

### Model Selection Influence

Refinement output affects model routing:

| Refinement Characteristic | Classification Signal | Likely Model |
|---------------------------|----------------------|--------------|
| Single clear goal | Implementation task | Sonnet |
| Multiple interconnected goals | Complex task | Opus |
| Exploration required | Exploratory task | Opus |
| Straightforward changes | Implementation task | Sonnet |

---

## 6. Quality Checklist

### Pre-Refinement Checklist

Before starting refinement:

- [ ] Read full user message (don't skim)
- [ ] Check conversation history for context
- [ ] Identify explicit vs. implicit requirements
- [ ] Note any constraints mentioned

### Post-Refinement Checklist

After generating specification:

- [ ] Goal is single-sentence and specific
- [ ] Goal starts with action verb
- [ ] Description provides necessary context
- [ ] Actions are ordered logically
- [ ] Actions are atomic (one thing each)
- [ ] No ambiguous terms remain
- [ ] Scope boundaries are clear
- [ ] Success criteria are inferable

### Handoff Checklist

Before passing to task-classification:

- [ ] Specification follows standard template
- [ ] All required fields populated
- [ ] Scope indicators present for classification
- [ ] Risk factors explicitly noted
- [ ] Ready for agent assignment

---

*This reference document complements the main SKILL.md. For worked examples, see `examples/refinement-scenarios.md`.*
