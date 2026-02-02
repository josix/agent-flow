# Ambiguity Detection

Comprehensive reference for detecting and scoring ambiguity in user prompts for the multi-agent orchestration system.

---

## 1. Ambiguity Signal Table

A prompt requires clarification if ANY of the following signals are detected:

| Signal | Pattern | Example | Clarification Needed |
|--------|---------|---------|---------------------|
| Missing scope | No target specified | "fix the bug" | Which bug? Where? |
| Unclear target | Vague component reference | "update the API" | Which endpoint? What change? |
| Vague outcome | Subjective success criteria | "make it better" | Better how? Faster? Cleaner? |
| No context | Missing environment info | "add authentication" | What type? OAuth? JWT? Basic? |
| Multiple interpretations | Ambiguous action | "change the login" | UI change? Logic change? Flow change? |
| Implicit assumptions | Unstated dependencies | "deploy it" | Where? How? With what config? |
| Compound requests | Multiple unrelated goals | "fix login and add search" | Which first? Related? |
| Domain-specific terms | Jargon without context | "optimize the DAG" | Which DAG? What metric? |

---

## 2. Ambiguity Severity Levels

| Level | Description | Action |
|-------|-------------|--------|
| Critical | Cannot proceed without clarification | Must ask clarifying question |
| High | Multiple likely interpretations | Should ask clarifying question |
| Medium | Minor ambiguity, reasonable default exists | May proceed with stated assumption |
| Low | Very minor ambiguity | Proceed with reasonable interpretation |

---

## 3. Detection Heuristics

### Definitely Ambiguous (Must Clarify)

- No files, components, or features mentioned
- Only subjective descriptors ("better", "faster", "cleaner")
- Action verb with no object ("fix", "change", "update" alone)
- Pronouns without clear antecedents ("it", "that", "them")
- Open-ended scope ("all", "everything", "everywhere")

### Possibly Ambiguous (Assess Context)

- Generic terms with multiple meanings ("the service", "the handler")
- Scope modifiers that could vary ("all", "some", "the relevant")
- Time-sensitive terms ("latest", "current", "recent")
- Industry jargon without definition

### Likely Clear (Proceed Cautiously)

- Specific file paths mentioned
- Concrete numbers or values provided
- Technical specifications included
- Error messages or logs provided
- Clear success criteria stated

---

## 4. Ambiguity Scoring System

Calculate an ambiguity score to determine action:

| Factor | Points | Description |
|--------|--------|-------------|
| Missing target | +3 | No file, component, or feature specified |
| Vague outcome | +2 | Subjective success criteria |
| Pronoun reference | +1 | "it", "that" without clear antecedent |
| Scope ambiguity | +2 | "all", "everywhere" without bounds |
| Multiple interpretations | +3 | Genuinely different valid readings |
| Implicit assumption | +1 | Unstated but required information |
| Domain jargon | +1 | Technical terms without context |
| Compound request | +2 | Multiple distinct tasks combined |

### Score Thresholds

| Score | Action |
|-------|--------|
| 0-2 | Proceed with refinement |
| 3-4 | State assumption and proceed |
| 5-6 | Ask one clarifying question |
| 7+ | Ask clarifying question, consider breaking down request |

---

## 5. Multi-Layer Ambiguity Analysis

When simple signal detection is insufficient, apply multi-layer analysis:

### Layer 1: Lexical Analysis

- Identify pronouns without antecedents ("it", "that", "these")
- Flag subjective adjectives ("better", "faster", "cleaner", "nicer")
- Detect action verbs without objects ("fix", "update", "change")
- Count specificity markers (file paths, line numbers, function names)

### Layer 2: Semantic Analysis

- Check for domain terms with multiple meanings
- Identify implicit assumptions in the request
- Detect scope modifiers that could vary
- Assess whether context resolves ambiguity

### Layer 3: Pragmatic Analysis

- Consider conversation context and history
- Evaluate what the user likely means vs. what they said
- Assess organizational conventions and patterns
- Factor in recent files or features discussed

---

## 6. Context-Sensitive Detection

Ambiguity depends on context:

### Codebase Context

- Is there only one "UserService"? -> Less ambiguous
- Are there multiple "config" files? -> More ambiguous
- Is the error message unique? -> Less ambiguous
- Does the pattern match multiple files? -> More ambiguous

### Conversation Context

- Did user just mention a specific file? -> Pronoun likely refers to it
- Were we discussing a bug? -> "Fix it" has clear reference
- Is this a follow-up? -> Previous context applies
- Was there recent exploration? -> Results inform scope

### User Context

- Experienced users may use shorthand intentionally
- New users may not know what details are needed
- Domain experts use jargon naturally
- Adjust clarification style accordingly

---

## 7. Ambiguity Detection Checklist

Before refining, verify the prompt contains:

- [ ] An identifiable action (what to do)
- [ ] A specific target (where to do it)
- [ ] An expected outcome (why/what success looks like)
- [ ] Sufficient context (constraints, environment)

**If any checkbox fails, the prompt likely needs clarification.**

---

## 8. Common Ambiguity Patterns

### Pattern: "Just/Simply/Quick"

**Input**: "Just fix the API"
**Issue**: Minimizing language masks complexity
**Resolution**: Ignore minimizers, assess actual scope

### Pattern: "Make it Better"

**Input**: "Make the performance better"
**Issue**: Subjective success criteria
**Resolution**: Ask for specific metrics or targets

### Pattern: "The [Generic Thing]"

**Input**: "Update the service"
**Issue**: Multiple services exist
**Resolution**: Ask which specific service

### Pattern: "Fix It/That/This"

**Input**: "Can you fix that?"
**Issue**: Unclear referent
**Resolution**: Check context or ask for specifics

### Pattern: "All/Every/Everything"

**Input**: "Update all the tests"
**Issue**: Unbounded scope
**Resolution**: Confirm scope or suggest subset

---

## 9. Ambiguity vs. Incompleteness

| Type | Description | Response |
|------|-------------|----------|
| Ambiguity | Multiple valid interpretations | Clarify to select one |
| Incompleteness | Missing required details | Ask for missing info |
| Vagueness | Imprecise but single meaning | Proceed with interpretation |
| Under-specification | Details left to implementer | Make reasonable choices |

---

## See Also

- [SKILL.md](../SKILL.md) - Main prompt refinement documentation
- [clarification-strategies.md](clarification-strategies.md) - How to ask clarifying questions
- [orchestration-detection.md](orchestration-detection.md) - When to refine for orchestration
