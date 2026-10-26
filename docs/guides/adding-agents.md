# Adding Agents

A guide to extending Agent Flow with custom agents.

## When to Add an Agent

Consider adding a new agent when:

- **You have a distinct responsibility** that doesn't fit existing agents
- **You need different tool access** than current agents provide
- **You want to enforce specific behaviors** for a domain
- **You need a different model** for specific task types

## Agent Anatomy

Each agent is defined in a Markdown file with YAML frontmatter:

```markdown
---
name: AgentName
description: Use this agent when [scenario description].

model: opus|sonnet
effort: low|medium|high
color: [color name]
tools: ["Tool1", "Tool2", ...]
skills: skill-name-1, skill-name-2
---

[Agent system prompt content]
```

`tools:` may also list MCP tool names (for example the graphify tools Riko uses), not just built-ins.

## Step-by-Step Guide

### Step 1: Define the Role

Clearly articulate:
1. What is this agent responsible for?
2. What should it NOT do?
3. How does it fit the existing workflow?

**Example - Security Auditor:**
- **Responsible for**: Security analysis, vulnerability detection, dependency auditing
- **Should NOT**: Fix issues (Loid's job), run tests (Alphonse's job)
- **Workflow fit**: After implementation, before verification

### Step 2: Choose the Model

| Choose Opus When | Choose Sonnet When |
|------------------|-------------------|
| Deep reasoning required | Well-defined tasks |
| Unfamiliar territory | Fast iteration needed |
| Strategic decisions | Clear pass/fail criteria |
| Complex analysis | Repetitive operations |

### Step 3: Select Tools

Only include tools the agent needs:

| Tool | Purpose | Typical Agents |
|------|---------|----------------|
| Read | Read file contents | All |
| Grep | Search content | Explorer, Reviewer |
| Glob | Find files | Explorer, Planner |
| Write | Create files | Loid; Senku (plans/reports) and Speedwagon (`explain-out/`) have scoped Write |
| Edit | Modify files | Loid; Speedwagon (scoped) |
| Bash | Run commands | Executor, Reviewer, Verifier |
| WebSearch | Web lookup | Explorer only |
| WebFetch | Fetch URLs | Explorer only |

### Step 4: Create the Agent File

Create `agents/YourAgent.md`:

```markdown
---
name: Guardian
description: Use this agent when validating security constraints, checking access control, or enforcing policy compliance.

model: sonnet
color: purple
tools: ["Read", "Grep", "Glob", "Bash"]
skills: agent-behavior-constraints, verification-gates
---

You are the Guardian Agent, responsible for security analysis.

**EVIDENCE REQUIREMENTS - READ THIS FIRST:**
- Do NOT claim "secure" without running security tools and showing output
- Do NOT approve security without actual scanner evidence
- Every finding must cite file path, line number, and vulnerability type

**Core Responsibilities:**
1. Run security scanners (npm audit, bandit, semgrep)
2. Check for common vulnerabilities
3. Review authentication and authorization code
4. Identify sensitive data handling issues
5. Report findings with severity levels

**Tool Usage Boundaries:**
- Read, Grep, Glob: Search and read code
- Bash: ONLY for security scanning tools
- NEVER: Modify code (that's Loid's job)
- NEVER: Run tests (that's Alphonse's job)

**Allowed Bash Commands:**
```bash
# Security scanning
npm audit --json
bandit -r src/ -f json
semgrep --config auto src/
trivy fs --security-checks vuln .

# FORBIDDEN
npm test        # Testing is Alphonse's job
npm run build   # Building is Alphonse's job
```

**Output Format:**

## Security Audit

### Summary
[Brief summary]

### Findings
| Severity | Location | Issue | Recommendation |
|----------|----------|-------|----------------|
| CRITICAL | path:line | [Issue] | [Fix] |
| HIGH | path:line | [Issue] | [Fix] |
| MEDIUM | path:line | [Issue] | [Fix] |

### Dependency Vulnerabilities
[npm audit / pip-audit output]

### Verdict
[SECURE | NEEDS_REMEDIATION | BLOCKED]

## Self-Reflection Protocol

Before returning your response, verify:

1. **Completeness** - Did I scan all relevant areas?
2. **Evidence** - Am I providing tool output, not claims?
3. **Accuracy** - Are severity levels correct?
4. **Scope** - Did I stay within security analysis?

If any check fails, iterate before returning.
```

### Step 5: Integrate into Workflow

Phases 3–5 normally run as the `agent-flow:implement-review-verify` workflow, so a new phase or parallel reviewer must be wired in three places:

- `workflows/implement-review-verify.js`, plus a scenario in `scripts/test-implement-review-verify.js`
- `commands/orchestrate.md` (the manual path used when the Workflow tool is unavailable)
- the docs that describe the phase

**Option A: New phase** (sequential, after review):

```markdown
### Phase 4.5: Security Audit
**Delegate to Guardian**, then:
- If SECURE: proceed to verification
- If NEEDS_REMEDIATION: return to Loid with the issues
```

**Option B: Parallel with an existing phase.** Reviewers that never write code can run next to Lawliet and Alphonse in the parallel Phase 4+5 block.

### Step 6: Update Documentation and Checks

1. Update the `README.md` agent table and any agent counts in README and `docs/`
2. Update `docs/reference/agents.md`
3. Update `skills/skill-agent-mapping/SKILL.md` if the agent owns or consumes skills
4. Add the agent to `EXPECTED_AGENTS` in `scripts/validate-plugin.sh`

## Testing Your Agent

### Manual Testing

1. Start Claude Code with the plugin
2. Request a task that should use your agent
3. Verify the agent is selected correctly
4. Check output matches expected format

### Behavioral Verification

Ensure your agent:
- [ ] Stays within tool boundaries
- [ ] Follows evidence requirements
- [ ] Produces expected output format
- [ ] Integrates with workflow correctly

## Best Practices

### DO

- **Keep responsibilities focused** - One agent, one job
- **Restrict tool access** - Only what's needed
- **Include evidence requirements** - Prevent hallucination
- **Document self-reflection** - Built-in quality check
- **Follow existing patterns** - Consistency matters

### DON'T

- **Don't overlap responsibilities** - Clear boundaries
- **Don't give all tools** - Temptation to shortcut
- **Don't skip evidence requirements** - Trust issues
- **Don't make it too general** - Defeats specialization

## Related Documentation

- [Agents Reference](../reference/agents.md) - Existing agent specifications
- [Agent Specialization](../concepts/agent-specialization.md) - Why specialization matters
- [Adding Skills](adding-skills.md) - Creating supporting skills
- [Architecture Overview](../architecture/overview.md) - System design
