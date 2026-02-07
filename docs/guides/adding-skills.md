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

### Step 3: Create the Skill Directory

```bash
mkdir -p skills/api-design/references skills/api-design/examples
```

### Step 4: Write SKILL.md

Create `skills/api-design/SKILL.md`:

```markdown
---
name: api-design
description: This skill should be used when designing REST APIs, defining endpoints, choosing HTTP methods, structuring responses, or handling API errors.
---

# API Design

Patterns and best practices for REST API design.

## Overview

This skill provides guidance on designing consistent, maintainable REST APIs. Apply these patterns when:

- Creating new API endpoints
- Refactoring existing APIs
- Reviewing API implementations
- Documenting API contracts

## Key Principles

1. **Consistency**: Same patterns across all endpoints
2. **Predictability**: Clients know what to expect
3. **Clarity**: Self-documenting URLs and responses
4. **Versioning**: Support evolution without breaking changes

---

## Endpoint Naming

### URL Structure

```
/{version}/{resource}/{id?}/{sub-resource?}

Examples:
GET  /v1/users              # List users
GET  /v1/users/123          # Get user 123
POST /v1/users              # Create user
PUT  /v1/users/123          # Update user 123
GET  /v1/users/123/orders   # List user's orders
```

### Naming Rules

| Rule | Good | Bad |
|------|------|-----|
| Use nouns | /users | /getUsers |
| Use plurals | /orders | /order |
| Use kebab-case | /order-items | /orderItems |
| Avoid verbs | /users/123/activate | /activateUser |

---

## HTTP Methods

| Method | Purpose | Idempotent | Safe |
|--------|---------|------------|------|
| GET | Read resource | Yes | Yes |
| POST | Create resource | No | No |
| PUT | Replace resource | Yes | No |
| PATCH | Partial update | No | No |
| DELETE | Remove resource | Yes | No |

---

## Response Format

### Success Response

```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "abc123"
  }
}
```

### Error Response

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ]
  },
  "meta": {
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "abc123"
  }
}
```

---

## Status Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| 200 | OK | Successful GET, PUT, PATCH |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Invalid input |
| 401 | Unauthorized | Missing/invalid auth |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Resource conflict |
| 422 | Unprocessable | Validation failed |
| 500 | Server Error | Unexpected error |

---

## Quick Reference

### New Endpoint Checklist

- [ ] Uses appropriate HTTP method
- [ ] Follows naming conventions
- [ ] Returns correct status codes
- [ ] Includes standard response format
- [ ] Has error handling
- [ ] Is documented

### Review Checklist

- [ ] Consistent with existing APIs
- [ ] Proper HTTP semantics
- [ ] Correct status codes
- [ ] Standard error format
- [ ] Versioned appropriately

---

## Resources

- `references/endpoint-patterns.md` - Common patterns
- `references/error-handling.md` - Error strategies
- `examples/api-scenarios.md` - Worked examples

## Related Skills

- `../verification-gates/SKILL.md` - API testing patterns
- `../task-classification/SKILL.md` - API task routing
```

### Step 5: Create Reference Files

Create detailed reference materials in `skills/api-design/references/`:

**endpoint-patterns.md:**
```markdown
# Endpoint Patterns

Common patterns for REST endpoint design.

## Collection Endpoints

### List with Pagination

```
GET /v1/users?page=1&limit=20&sort=createdAt:desc
```

Response:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "pages": 8
  }
}
```

[... more patterns ...]
```

### Step 6: Create Examples

Create worked examples in `skills/api-design/examples/`:

**api-scenarios.md:**
```markdown
# API Design Scenarios

## Scenario: User Registration Endpoint

**Requirement**: Allow users to register with email and password

**Design Decision**:

```
POST /v1/users
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Response (201 Created)**:
```json
{
  "data": {
    "id": "usr_123",
    "email": "user@example.com",
    "createdAt": "2024-01-15T10:30:00Z"
  }
}
```

**Why this design**:
- POST for creation (not GET with query params)
- Returns 201 Created (not 200 OK)
- Returns created resource (not just ID)
- Excludes password from response

[... more scenarios ...]
```

### Step 7: Update Registry

Add to `skills/skill-agent-mapping/SKILL.md`:

```markdown
| api-design | Senku | Loid, Lawliet | REST API design patterns |
```

### Step 8: Update Consuming Agents

Update agent frontmatter to reference the skill:

```yaml
skills: agent-behavior-constraints, api-design
```

## Skill Template

Use this template for new skills:

```markdown
---
name: skill-name
description: This skill should be used when [specific situations where skill applies].
---

# Skill Name

Brief description of what this skill provides.

## Overview

- When to apply this skill
- What decisions it helps with
- Key principles

## [Main Topic 1]

### Subtopic A
[Content]

### Subtopic B
[Content]

## [Main Topic 2]

### Subtopic A
[Content]

## Quick Reference

### Checklist
- [ ] Item 1
- [ ] Item 2

### Decision Table
| Situation | Action |
|-----------|--------|
| ... | ... |

## Resources

- [references/...](references/...) - Detailed reference
- [examples/...](examples/...) - Worked examples

## Related Skills

- [other-skill](../other-skill/SKILL.md) - How they relate
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

1. Check skill loads without errors
2. Verify owner agent references it
3. Confirm consumer agents can access it
4. Test that guidance is applied correctly

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
