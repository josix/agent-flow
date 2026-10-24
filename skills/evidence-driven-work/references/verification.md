# Verification Habits

Gates, commands and the Intent Ledger belong to [verification-gates](../../verification-gates/SKILL.md). These are the surrounding habits.

## Target-environment checklist

- [ ] The change is actually running in the target environment (not only locally).
- [ ] The metrics that motivated the change are re-read there.
- [ ] Baseline and sample size are stated.
- [ ] What the data cannot show is stated.

## Per-criterion table

| Criterion | Observable | Result | Evidence |
|-----------|------------|--------|----------|
| (what must be true) | (what you read to decide) | pass / fail | (id, link, UTC time) |

## Failure-looking signals

Re-check before reporting. Read the status and its cause: a cancellation, a retry or a timeout is not a crash. Report the re-check result, not the first glance.

## Stale copy and realistic data

- Confirm the code under test is the code you changed (installed copy vs working tree).
- Exercise the realistic case; synthetic data that hides the effect proves little.
