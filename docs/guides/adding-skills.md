# Adding Skills

A guide to extending Agent Flow with custom skills.

## What is a Skill?

A skill is a domain expertise module that provides behavioral patterns and best practices. Skills are referenced by agents to guide their behavior in specific domains.

**Skills are NOT:**
- Code libraries
- Executable modules
- Configuration files

**Skills ARE:**
- Documentation of expertise
- Behavioral guidelines
- Decision frameworks
- Reference materials

## Skill Structure

```
skills/
└── your-skill/
    ├── SKILL.md              # Main documentation
    ├── references/           # Detailed reference materials
    │   ├── topic-a.md
    │   └── topic-b.md
    └── examples/             # Worked examples
        └── scenarios.md
```

## Step-by-Step Guide

### Step 1: Define the Domain

Clearly articulate:
1. What domain does this skill cover?
2. What decisions does it help with?
3. What behaviors does it encode?

**Example - API Design Skill:**
- **Domain**: REST API design patterns
- **Decisions**: Endpoint naming, response formats, error handling
- **Behaviors**: Consistent API structure, proper HTTP methods

### Step 2: Identify Owner and Consumers

| Role | Definition |
|------|------------|
| Owner | Agent responsible for maintaining and embodying the skill |
| Consumer | Agent that references the skill for guidance |

**Example:**
- **Owner**: Senku (Planner) - designs APIs
- **Consumers**: Loid (Executor), Lawliet (Reviewer)

### Step 3: Write SKILL.md

Create `skills/api-design/SKILL.md`:

````markdown
---
name: api-design
user-invocable: false
description: This skill should be used when designing REST APIs, defining endpoints, or handling API errors.
---

# API Design

## Overview
When to apply this skill and the key principles.

## Endpoint Naming
| Rule | Good | Bad |
|------|------|-----|
| Use nouns | /users | /getUsers |

## Resources
- [references/...](references/...) - Detailed reference
- [examples/...](examples/...) - Worked examples

## Related Skills
- [other-skill](../other-skill/SKILL.md) - How they relate
````

Most bundled skills set `user-invocable: false` to stay out of the slash menu. Put branch-only detail in `references/`, which agents read on demand, and keep `SKILL.md` to the rules and decision tables. Add worked examples under `examples/`.

### Step 4: Register the Skill

1. Add a row to the registry table and update the Visual Mapping diagram in `skills/skill-agent-mapping/SKILL.md`:
   ```markdown
   | api-design | Senku | Loid, Lawliet | REST API design patterns |
   ```
2. Reference the skill in the owning and consuming agents' frontmatter:
   ```yaml
   skills: agent-behavior-constraints, api-design
   ```

## Best Practices

### DO

- **Keep focused** - One domain per skill
- **Be prescriptive** - Clear guidance, not just information
- **Include examples** - Show, don't just tell
- **Provide checklists** - Quick reference for decisions
- **Cross-reference** - Link to related skills

### DON'T

- **Don't be too broad** - "software development" is not a skill
- **Don't just describe** - Provide actionable guidance
- **Don't skip examples** - Abstract rules are hard to apply
- **Don't duplicate** - Reference existing skills instead
- **Don't forget versioning** - Skills evolve

## Testing Your Skill

### Verify Integration

```bash
bash scripts/validate-plugin.sh     # new skills must be added to EXPECTED_SKILLS in that script
claude plugin validate --strict .
```

Then confirm the owner and consumer agents reference the skill and that the guidance is applied.

### Quality Checklist

- [ ] SKILL.md has complete frontmatter
- [ ] Overview explains when to use
- [ ] Key concepts are documented
- [ ] Quick reference is practical
- [ ] References provide depth
- [ ] Examples show real scenarios
- [ ] Registry is updated

## Related Documentation

- [Skills Reference](../reference/skills.md) - Existing skill specifications
- [Adding Agents](adding-agents.md) - Creating agents that use skills
- [Architecture Overview](../architecture/overview.md) - System design
