---
id: orchestration-pipeline
slug: orchestration-pipeline
title: How Agent-Flow Orchestrates Multi-Agent Work
authored-by: Speedwagon
lang: en
---

## tldr

Orchestrate splits a task into phases and hands each one to a specialist agent, so no
single model context has to hold the whole job at once.

## glossary

- **phase**: one stage of the orchestration lifecycle (exploration, planning, implementation, review, verification)
- **gate**: a pass/fail check that must succeed before the next phase starts
- **dispatch**: the orchestrator handing a task to a specialist agent via a `Task(...)` call
- **state file**: `.claude/orchestration.local.md`, which tracks phase, iteration count, and gate results

## teaching_arc

4 screens that take a new contributor from "what even is this?" to "I understand how
a work item moves through the system and what prevents it from going off the rails."

- **Screen 1 — Orient: What is orchestration?**
  Agent-Flow's central idea is that complex tasks are too big for one model context.
  The orchestrate command breaks a task into phases (exploration → planning →
  implementation → review → verification) and delegates each phase to a specialist
  agent. The human is the director; the agents are the crew.
  Introduce the five agents and their roles before showing any code.

- **Screen 2 — Explain: The 6-phase lifecycle**
  Walk through the six phases defined in `commands/orchestrate.md`:
  Exploration (Riko), Planning (Senku), Implementation (Loid), Review (Lawliet),
  Verification (Alphonse), Report & Completion (orchestrator).
  Show the phase-transition table from `scripts/update-orchestration-state.sh` to
  make it concrete. Emphasize that phases run sequentially, not in parallel —
  this is deliberate (each phase gates the next).

- **Screen 3 — Demonstrate: How specialists are dispatched**
  Show the `Task(agent="Riko", prompt="...")` call pattern from `commands/orchestrate.md`
  lines 82–100. Explain that the prompt includes the agent's name, a structured task,
  and a graph hint. Use the code↔English translator primitive to let the reader toggle
  between the raw Task call and a plain-English description of what Riko is asked to do.

- **Screen 4 — Challenge: How state and gates prevent runaway**
  Introduce `scripts/init-orchestration.sh` and `scripts/update-orchestration-state.sh`.
  The state file (`.claude/orchestration.local.md`) tracks phase, iteration count, and
  gate results. The max-iterations guard (`--max-iterations`, default 10) is the circuit
  breaker: if the loop hasn't converged in 10 tries, the orchestration halts and asks for
  human input. End with the quiz primitive.

## pre_extracted_code_refs

Snippets extracted at brief-generation time. The assembler embeds these verbatim;
no re-read of source is needed at assembly time.

- commands/orchestrate.md:82–120  (Phase 1 Exploration block — Riko Task call pattern)
- commands/orchestrate.md:178–206  (Phase 2 Planning — Senku Task call)
- scripts/init-orchestration.sh:28–100  (argument parsing + state file initialization)
- scripts/update-orchestration-state.sh:36–62  (phase transition options + examples)
- scripts/update-orchestration-state.sh:1–20  (set -euo pipefail + cleanup trap pattern)

## interactive_checklist

- [ ] code-english-translator: commands/orchestrate.md:82–100 — the Riko Task call for Phase 1 Exploration; explanation: "Fire Riko to map the codebase before writing any code"
- [ ] quiz: "Which agent is responsible for running the test suite and reporting exact output?" (answer: Alphonse; distractor: Loid; distractor: Lawliet)
- [ ] graph-thumbnail: graphify community covering orchestrate.md, init-orchestration.sh, update-orchestration-state.sh — TBD (run community query in v1)

## related_nodes

graphify community: TBD (run `get_community` on `commands/orchestrate.md` node in v1 to
surface sibling nodes — expected to include init-orchestration.sh,
update-orchestration-state.sh, agents/Riko.md, agents/Senku.md, agents/Loid.md,
agents/Lawliet.md, agents/Alphonse.md)

## metaphor

The orchestrate command is a film director's shooting schedule: it doesn't write the
script or operate the camera, but it sequences who does what, when, and ensures every
scene is checked before the crew moves to the next location.
