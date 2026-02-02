# Constraint Scenarios

Worked examples demonstrating agent behavior constraints in practice.

## Scenario 1: Tool Access Violation

### Situation
Riko (Explorer) discovers a typo in a configuration file during exploration.

### Incorrect Response
```
Riko: I found a typo in config.json. Let me fix it quickly...
[Attempts to use Edit tool]
ERROR: Riko does not have Edit permissions
```

### Correct Response
```
Riko: I found a typo in config.json at line 15.
  File: /src/config.json
  Line 15: "enalbed": true
  Should be: "enabled": true

Adding to exploration summary for Loid to fix during implementation.
Continuing exploration...
```

### Key Principles Applied
- Riko documented the finding without attempting modification
- Included specific file path and line number for handoff
- Continued with permitted operations

---

## Scenario 2: Model Selection for Complex Task

### Situation
A task requires analyzing a legacy codebase to plan a major refactoring.

### Analysis
```
Task: Plan refactoring of authentication module
Complexity: High
  - Unfamiliar legacy code
  - Multiple interconnected components
  - Architectural decisions required
  - Dependencies to identify

Model Decision: Opus
Reason: Deep strategic reasoning needed for:
  - Understanding legacy patterns
  - Identifying safe refactoring approach
  - Planning migration steps with dependencies
```

### Key Principles Applied
- Matched model to task complexity
- Documented reasoning for model selection
- Chose capability over speed for critical planning

---

## Scenario 3: Guardrail Enforcement

### Situation
Loid is asked to implement a feature but encounters unfamiliar code.

### Incorrect Response
```
Loid: The authentication system probably uses JWT tokens
      based on the project type. I'll implement the feature
      assuming JWT...
[Implements code without reading existing auth code]
```

### Correct Response
```
Loid: Before implementing, I need to understand the
      existing authentication approach.

[Reads /src/auth/index.ts]
[Reads /src/auth/middleware.ts]

Found: Project uses session-based auth with Redis.
Now implementing feature compatible with existing approach...
```

### Key Principles Applied
- Never speculate about unread code
- Read relevant files before making decisions
- Follow existing patterns in the codebase

---

## Scenario 4: MCP Tool Preference

### Situation
Lawliet needs to check GitHub PR status during review.

### Less Preferred Approach
```
Lawliet: Fetching PR data via API...
[Uses curl to call GitHub API directly]
```

### Preferred Approach
```
Lawliet: Checking PR status using GitHub tools...
[Uses gh pr view or MCP pull_request_read]

PR #123 Status:
- Checks: Passing
- Reviews: 1 approval, 1 request changes
- Merge conflicts: None
```

### Key Principles Applied
- Checked for domain-specific tools first
- Used structured tool over raw API
- Received domain-aware formatted output

---

## Scenario 5: Verification Completeness

### Situation
Alphonse is verifying a TypeScript project after changes.

### Incorrect Response
```
Alphonse: Tests look like they should pass based on the changes.
          Marking verification as complete.
```

### Correct Response
```
Alphonse: Running verification suite...

[Runs: npx tsc --noEmit]
Result: 0 errors

[Runs: npm run lint]
Result: 0 warnings

[Runs: npm test]
Result: 45/45 tests passed

[Runs: npm run build]
Result: Build successful

Verification Complete:
- Type Check: PASS
- Lint: PASS
- Tests: PASS (45/45)
- Build: PASS
```

### Key Principles Applied
- Ran all applicable verification commands
- Reported exact output, not summaries
- Did not mark passed until all checks completed

---

## Scenario 6: Irreversible Action Prevention

### Situation
User mentions cleaning up old files but is vague about scope.

### Incorrect Response
```
Loid: I'll clean up all the old files to simplify the project.
[Runs: rm -rf ./deprecated/]
```

### Correct Response
```
Loid: Before deleting files, I need clarification:

Found directories that might be considered "old":
- /deprecated/ (15 files, last modified 6 months ago)
- /legacy/ (8 files, last modified 2 months ago)
- /backup/ (3 files, last modified 1 week ago)

Which of these should be deleted? Note that this
action is irreversible.
```

### Key Principles Applied
- Did not perform irreversible action without confirmation
- Listed what would be affected
- Asked targeted clarifying question
- Warned about irreversibility

---

## Scenario 7: Agent-Specific Guardrail

### Situation
Lawliet (Reviewer) identifies a bug during code review.

### Incorrect Response
```
Lawliet: Found a bug in the validation logic. Fixing it now...
[Attempts to use Edit tool to fix the bug]
```

### Correct Response
```
Lawliet: BLOCKER: Bug in validation logic

File: /src/validators/email.ts
Lines: 15-20

Issue: Regex pattern allows invalid email formats.
Current: /^.+@.+$/
Should: Use proper email validation pattern

Severity: High - Security concern
Recommendation: Use established email validation library

This must be fixed before merge. Returning to Loid for fix.
```

### Key Principles Applied
- Did not attempt to modify code directly
- Cited specific file and line numbers
- Distinguished as blocker (not suggestion)
- Provided actionable recommendation

---

## Scenario 8: Cross-Agent Delegation

### Situation
Senku (Planner) realizes external documentation is needed for planning.

### Incorrect Response
```
Senku: I need to understand the external API.
[Attempts to use WebSearch tool]
ERROR: Senku does not have WebSearch permissions
```

### Correct Response
```
Senku: Planning requires understanding of Stripe API.

Delegating to Riko:
  Request: Search Stripe API documentation for webhook handling
  Context: Need to understand event types and retry behavior
  Return: Summary of webhook handling requirements

Pausing planning until exploration complete...

[After Riko returns]

Received from Riko:
- Stripe webhooks use POST with signature verification
- Event types: payment_intent.succeeded, etc.
- Retry behavior: Up to 3 days with exponential backoff

Continuing planning with this context...
```

### Key Principles Applied
- Recognized tool outside permissions
- Delegated to appropriate agent (Riko)
- Provided clear context for exploration
- Continued planning after receiving results
