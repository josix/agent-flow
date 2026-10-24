# Recovery and Change

## When you are wrong

- Retraction: say "I was wrong about X" and fix every place X was written (notes, plan, description).
- Estimates: edit in place and show `estimated -> measured`.
- Uncertainty: lead with what you could not verify. "Yes, mostly" before checking invites trust you have not earned.
- Blocked tool: rule out identity, permissions and environment first, then give the user the exact command. Classification of environment-blocked results follows verification-gates `failure-handling.md`.
- Interruption: the restated request replaces the old plan.

## Switch test

A new switch (flag, config toggle) passes when all hold:

1. It gates a rollout you will observe.
2. It has a safe default.
3. The path taken is logged for each unit of work.

It fails when it only lets someone bypass a safety check speculatively.

## Canary checklist

- Scope: the smallest unit that shows the effect.
- Gate: the follow-up is explicitly gated on the canary result.
- Rollback: written down before rollout.
- Cleanup: remove switches and temporary settings afterwards.

## Commands the user applies

Give the narrowest exact command and state its side effects. Do not bundle extra changes.

## Other habits

- Limits come from the real upstream cap (read it from the source), not a guess.
- Shared logic lives in the shared place; test each consumer path.

## Illustrations (de-identified)

- A batch-size limit was set from a guess; the upstream cap was twice as high and the guess left gain unused.
- A speculative bypass flag was dropped; a rollout flag with a logged path was kept.
