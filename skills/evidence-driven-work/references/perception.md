# Perception: Observation Surfaces

Ask the running system what it did. Before explaining behaviour, list which surfaces the domain exposes.

## Question to surface

| Question | Look at |
|----------|---------|
| Why is it slow? | runtime metrics, then the execution plan |
| Why is the setting ignored? | effective state, then persisted state that overrides config |
| Did it run? | history or audit log |
| What exactly happened? | events, logs, traces |
| What does the UI really show? | the API behind the UI |

## Surface type by domain

Illustrative. Confirm the surface exists in your stack.

| Surface | Data / stream processing | Web app | Kubernetes | Relational DB | CI / build | IaC | Agent sessions |
|---------|--------------------------|---------|------------|---------------|------------|-----|----------------|
| Effective config/state | runtime conf, job REST API | devtools storage/headers | resource as served (yaml output) | server settings views | resolved pipeline config | rendered plan | session settings |
| Execution plan | physical plan | network waterfall | scheduling decisions in describe output | EXPLAIN (ANALYZE) | job graph | plan output | tool-call sequence |
| Runtime metrics | job/stage UI and API | performance panel, APM | metrics server | stats views | build scans, timings | n/a | token/usage counters |
| History / audit | table history | server access logs | events, audit log | query history | run history | state history | transcripts |
| Events, logs, traces | driver/executor logs | HAR, server traces | pod logs, events | slow-query log | job logs | apply logs | tool logs |
| API behind the UI | REST endpoints of the UI | the XHR/fetch calls | API server | catalog views | CI REST API | provider API | session store |
| Persisted state overriding config | checkpoint/offset log | local storage, cache | live object vs manifest | persisted parameters | caches | state file | saved memory |

## Configured vs effective checklist

1. Read the effective value from the running system, not the file.
2. If it differs, list what can override: persisted state, caches, precedence rules, defaults at another layer.
3. Change one layer, then re-read the effective value.

## Measurement hygiene

- Use a baseline window and state the sample size.
- If a default hides the effect, turn it off for a controlled window, restore it, and record that you restored it.
- Rank by measured cost, not by the most plausible suspect.

## Recommending a tool to the user

When you cannot reach a surface: name it, say what question it answers, give the exact command or the access you need, and ask. Do not work around the block or extract credentials; see agent-behavior-constraints.

## Illustrations (de-identified)

- A tuning setting appeared to have no effect because the job silently restored its old value from persisted state; reading the effective value exposed it.
- The suspected step was cheap once measured; the real bottleneck was elsewhere in the plan.
