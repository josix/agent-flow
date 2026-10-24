# Expression

Write for a human who has not been watching.

## At-a-glance checklist

- [ ] Outcome in the first line, including any caveat (done / done with caveats / not done)
- [ ] Background, what changed, purpose, impact all present
- [ ] Each claim has real evidence
- [ ] Domain terms explained on first use; no private shorthand
- [ ] Table only where something is compared
- [ ] Nothing the reader does not need
- [ ] Level of detail fits the audience and venue

## Narrative report template

```
Headline: <outcome in one sentence>
Background: <the situation and why it mattered>
What changed: <the change>
Purpose: <why this approach>
Impact: <effect, with evidence>
Terms: <only terms the reader may not know>
Pending: <what remains>
```

## Plain-session completion report

1. Done or not done.
2. What changed (links, hashes).
3. What was deliberately left alone, and why.
4. Side effects.
5. What is pending.

Inside `/orchestrate`, the orchestrator's Phase 6 report uses this shape: outcome first, then background, what changed, impact and purpose, evidence with exact identifiers, terms explained, and what was not done and why. The Intent Ledger and completion promise remain required. The report goes to the user inline; the ~3000-character report-length rule is for subagent reports, not this one.

The first line is one of: done; done with caveats, naming them (e.g. "Done, but the test suite never ran: ENVIRONMENT_BLOCKED on requires-python >=3.10"); or not done (e.g. stopped at the review cap with N open findings). A reader who stops after line one must not miss a caveat.

Subagents whose output is parsed (Lawliet, Alphonse) don't use this template: their verdict and gate lines keep the exact form and position their agent definition gives them (the verdict comes last), and the narrative goes in the prose around them.

## External-write protocol

For messages, comments, descriptions and publishing: draft, show the draft, send after explicit confirmation, and follow standing instructions. Local edits go ahead without asking. If a decision changes, update every artifact recording it in the same turn.

## Slogans and length

A slogan does not replace the story. A one-line answer is right when requested or when the venue wants a one-line impact. Otherwise let relevance set the length.

## Before / after

Before: "Optimised the thing (big win!!) via SMJ->BHJ; see table below :tada:" followed by a decorated grid.

After: "The nightly merge now finishes in 9 minutes instead of 25. Background: the merge shuffled both sides of a join (a join that redistributes all rows across machines). Change: the small side is now sent whole to every machine instead. Purpose: remove the shuffle cost. Impact: run 1234 took 9 minutes against a 25 minute baseline over the previous 7 runs. Pending: apply to the second job."
