---
name: evidence-driven-work
description: Ground work in what the system actually did, then tell people about it so they get it at a glance. Use when investigating why something is slow, failing, or ignoring a setting; choosing what to measure, which tool or view can show it, or what access to ask the user for; a hypothesis or estimate was just disproven; judging whether a change is worth making or weighing a proposed approach; verifying a change after it runs in the target environment; citing numbers, logs, or screenshots as evidence; writing a report, PR or ticket description, announcement, or completion summary. Covers observation surfaces across domains, evidence standards, argument structure, narrative reports (background, change, purpose, impact), explaining terms, and clarity over decoration.
---

# Evidence-Driven Work

Base claims on what the system actually did, and communicate them so a reader understands at a glance.

## Overview

These practices apply to whoever does the work, in a plain session or in any persona. They sit one level above specific tools: the tools change per domain, the habits do not.

- Inside `/orchestrate`, the orchestrator's Phase 6 report follows the reporting shape in sections 7 and 8; the Intent Ledger and the `<orchestration-complete>` promise stay required. That report goes to the user inline: the ~3000-character report-length rule is for subagent reports, not this one. As orchestrator, hand investigation and verification to the specialists in the Delegation Decision Matrix.
- Commit and PR footers: follow the user's or project's stated rule; this skill sets none.
- Boundaries: code search is [exploration-strategy](../exploration-strategy/SKILL.md); gates, the Intent Ledger and environment-blocked triage are [verification-gates](../verification-gates/SKILL.md); irreversible actions and permission blocks are [agent-behavior-constraints](../agent-behavior-constraints/SKILL.md); precedent is [agentsview-usage](../agentsview-usage/SKILL.md).

## Running as a subagent

Lawliet and Alphonse preload this skill, but they report to the orchestrator, not the user, and their output is parsed. So in a subagent:

- **Your role's output format wins.** Verdict lines (`### Verdict`, `### Overall:`), gate lines and `file:line` findings keep their exact form and position (your agent definition puts `### Verdict` / `### Overall:` last); sections 7 and 8 shape only the prose around them. "Outcome first" doesn't apply to you: your verdict line carries the outcome, so don't move it up or add a headline restating it.
- **Blockers go in your report, not to the user.** Wherever this skill says to ask the user, confirm a reading, or hand them a command, return it the way your role's contract says instead: `ENVIRONMENT_BLOCKED` or `FAILED` with the exact error signature for Alphonse, a finding or a note in the summary for Lawliet. The orchestrator decides whether to ask the user.
- **Do your own role's checks.** Delegating to specialists is the orchestrator's job; you have no Agent tool, so the Delegation Decision Matrix doesn't apply to you.
- **Skip what your role can't act on**: change discipline (section 3) and the external-write protocol (section 8) are for whoever makes and ships the change.

## 1. Perceive: ask the system, not your model of it

Code shows what should happen; observation surfaces show what did. List the surfaces the domain offers before explaining any behaviour: effective config or state, execution plan, runtime metrics, history or audit log, events/logs/traces, the API behind a UI, and persisted state that outlives a restart.

- Configured is not effective. When a setting seems to do nothing, read the effective value, then find what overrides it (persisted state, a cache, precedence rules).
- Measure before optimizing. Rank by measured cost, not by the most plausible suspect.
- Pin down which instance is meant (run, stage, environment, project) before an expensive step; if the request has two readings, confirm in one line (in a subagent, state the reading you took in your report).
- Compare against a baseline window and state the sample size.
- If a default hides the effect you want to show, switch it off for a controlled window, restore it, and record the restore.
- Get evidence from the running system, the tests and the verification environment, not from code alone; a UI view supports numbers taken from its machine-readable source.
- Read the repo's own instructions and known traps before running anything; they say how to run and verify here.
- Without access: name the equivalent surface, say what it would answer, and ask the user for access or give them the exact command (in a subagent, put this in your report instead). Do not work around a block or extract credentials.

Detail and the cross-domain surface table: [perception](references/perception.md).

## 2. When you are wrong

- Retract a disproven hypothesis explicitly, in every place it was written.
- Correct an estimate in place and show it next to the measured value.
- Lead with what you could not verify; do not answer "yes, mostly" before checking.
- Rule out identity, permissions and environment before blaming the tool, and hand the user the exact command.
- After an interruption, do exactly what the restated request asks; do not resume the old plan.

See [recovery and change](references/recovery-and-change.md).

## 3. Change

- One purpose per change set; split out unrelated work and anything that regresses.
- Gate scope on cost and benefit before building; drop scope that does not pay off.
- A switch is fine when it gates a rollout you will observe (safe default, log which path ran); it is not fine as a speculative bypass of a safety check.
- Derive limits from the real upstream cap, not a guess.
- Put shared logic in the shared place, with a test per consumer path.
- Roll risky changes out as a canary with a gated follow-up, a written rollback and a cleanup step.
- When the user applies infrastructure or production changes, give the narrowest exact command and its side effects.

## 4. Verify

Gates live in verification-gates; these are the habits around them.

- After deploying, verify in the target environment with the same metrics that motivated the change.
- For each acceptance criterion, name an observable and record pass or fail.
- Re-check anything that looks like a failure before reporting it; a cancellation is not a crash.
- Test the code you changed, not a stale installed copy.
- Test the realistic case, and say what the data cannot show.

See [verification](references/verification.md).

## 5. Evidence

- Cite identifiers someone can follow: path, run or commit id, link, UTC timestamp.
- Quote the primary artifact rather than paraphrasing it.
- Give each screenshot or other artifact a caption: what to look at, and when it was captured.
- Put verification evidence where the decision is made (the PR or ticket) as scenario, result, evidence.

## 6. Argue

- Order: finding, mechanism, evidence, impact per path, options, recommendation.
- Explain the mechanism and the reason, not only the fix.
- Answer "is it worth it?" with impact per code path and the cost side; recommend against the change when the benefit is about zero.
- Weigh the user's proposal against the data and say plainly whether it addresses the bottleneck.
- Name the condition that would change the recommendation (a measurement, a threshold, a new constraint).

See [evidence and argument](references/evidence-and-argument.md).

## 7. Express

- Outcome first: a reader who stops after the first line still has the key point.
- Tell the full story: background, what changed, purpose and impact, plus the mechanism when it matters, each backed by real evidence.
- Explain domain terms on first use; write the sentence out instead of private shorthand or codes.
- Clarity over decoration: form carries no weight; use a table only for a real comparison.
- Do not be verbose: cut restatement, hedging and meta-commentary; relevance sets the length. A full narrative is compatible with this because it carries only what the reader needs.
- Let audience and venue set the detail; use the reader's language and register.
- A style reference shapes how you write and never appears in the content.
- A slogan does not replace the story; a one-liner is fine when asked for.

Template and checklist: [expression](references/expression.md).

## 8. Report and communicate

- First line: done, done with caveats (name the caveat, e.g. tests never ran), or not done. Then what changed (links, hashes), what was deliberately left alone and why, side effects, what is pending.
- External or irreversible writes (messages, comments, descriptions, publishing): draft first, show it, send only after explicit confirmation, honouring standing instructions. Local work needs no asking.
- When a decision changes, update every artifact that records it in the same turn.

## Quick Reference

| Moment | Go to |
|--------|-------|
| A setting is ignored | 1 (configured vs effective) |
| Something is slow | 1 (metrics and plan, baseline) |
| Hypothesis disproven | 2 |
| Planning or reviewing a change | 3 |
| Change deployed | 4, 5 |
| User proposes an approach | 6 |
| About to report or write a description | 7, 8 |

At-a-glance check: outcome in line one; background, change, purpose, impact present; every claim has evidence; terms explained; no decoration doing the work of content; nothing the reader does not need.

## Resources

- [perception](references/perception.md) - observation surfaces across domains, recommending tools
- [recovery and change](references/recovery-and-change.md) - switch test, canary checklist
- [verification](references/verification.md) - target-environment checklist, per-criterion table
- [evidence and argument](references/evidence-and-argument.md) - worth-it table, argument skeleton
- [expression](references/expression.md) - narrative template, completion-report template, external-write protocol

## Related Skills

- [exploration-strategy](../exploration-strategy/SKILL.md) - searching code
- [verification-gates](../verification-gates/SKILL.md) - gates, Intent Ledger
- [agent-behavior-constraints](../agent-behavior-constraints/SKILL.md) - irreversible actions, permission blocks
- [agentsview-usage](../agentsview-usage/SKILL.md) - precedent from earlier sessions
