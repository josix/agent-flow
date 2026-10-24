# Evidence and Argument

## Evidence standard

- Identifiers someone can follow: path, run or commit id, link, UTC timestamp.
- Quote the primary artifact; paraphrase only to summarise.
- Screenshots and other artifacts: place in the narrative with a caption saying what to look at and when it was captured.
- Put verification evidence where the decision is made, as scenario, result, evidence.

## Argument skeleton

1. Finding
2. Mechanism (why it happens)
3. Evidence
4. Impact per path
5. Options
6. Recommendation, plus the condition that would change it

## Worth-it table

| Path / step | Hits the issue? | Effect |
|-------------|-----------------|--------|
| (code path or step) | yes / no | (measured effect) |

## Cost side

- Risk of the change itself
- Configuration that misleads later readers
- New failure modes

If the benefit is about zero, recommend against the change and say so.

## Weighing the user's proposal

Compare it with the data; say plainly whether it addresses the bottleneck. Disagreement backed by evidence is more useful than agreement.

## Condition line

End with: "This changes if <measurable condition>."
