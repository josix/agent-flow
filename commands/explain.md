---
name: explain
description: Generate an interactive one-module explainer for a topic — Riko gathers code scope, Senku plans a 3-5 screen teaching arc, Speedwagon authors the HTML, assembler produces explain-out/index.html
argument-hint: <topic> [--revise <slug>]
---

# Explain Command

Generate an interactive HTML explainer for a codebase topic. Riko gathers the relevant code scope, Senku designs a 3–5 screen teaching arc, Speedwagon authors the module brief and HTML fragment, and the assembler concatenates everything into `explain-out/index.html` — a file you can open directly in a browser.

Requires `.claude/deep-dive.local.md` (run `/deep-dive` first). The graphify knowledge graph (`graphify-out/graph.json`) is used if present; absent it degrades gracefully.

## Argument Parsing

`$ARGUMENTS` is the raw argument string passed to this command.

- If `$ARGUMENTS` is **empty** → print usage error and stop:
  ```
  Usage: /agent-flow:explain <topic>
  Example: /agent-flow:explain how does orchestration work
  Run /deep-dive first if you haven't already.
  ```
- If `$ARGUMENTS` starts with `--revise` → **revise mode**: extract the slug from the argument (e.g. `--revise orchestration-pipeline`) and skip Phase 1–2 if the brief exists.
- Otherwise → **normal mode**: `$ARGUMENTS` is the full topic string.

**Slug derivation** (compute once, use throughout all phases):
```bash
slug=$(echo "$ARGUMENTS" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-40)
```

## Precondition Checks

Run these checks before dispatching any agents:

```bash
if [[ ! -f ".claude/deep-dive.local.md" ]]; then
  echo "Error: .claude/deep-dive.local.md not found."
  echo "Run /deep-dive first to build the codebase context."
  exit 1
fi

if [[ ! -f "graphify-out/graph.json" ]]; then
  echo "Note: graphify-out/graph.json not found. Continuing in degraded mode (no graph context)."
fi
```

## Phase 1 — Scope (Riko)

Dispatch Riko with this prompt template, substituting `$ARGUMENTS` for `TOPIC` and the actual content of `.claude/deep-dive.local.md` for `DEEP_DIVE_CONTEXT`:

```
TOPIC: $ARGUMENTS

You are gathering code scope for a topic explainer. Your output will be consumed by
Senku (curriculum design) and Speedwagon (HTML authoring) — keep it structured.

Steps:
1. Read .claude/deep-dive.local.md for architecture context.
2. If graphify-out/graph.json exists, query for nodes related to the topic.
3. Identify 3–8 file:line refs directly relevant to the topic (concrete functions,
   types, or config values — not just filenames).
4. Identify 2–4 graph node names (or write "graph: unavailable" if graph absent).
5. Extract 3–6 key terminology terms specific to this topic.

Return structured markdown in exactly this format:

## Scope Bundle: $ARGUMENTS

### File References
- <file>:<start>-<end>  — <one-line description>
...

### Graph Nodes
- <node-name>
...  (or: graph: unavailable)

### Key Terminology
- <term>: <definition>
...
```

## Phase 2 — Curriculum (Senku)

Pass Phase 1's scope bundle output to Senku with this prompt template:

```
You are designing a teaching curriculum for a single-module interactive explainer.

TOPIC: $ARGUMENTS
SLUG: $SLUG

SCOPE BUNDLE (from Riko):
$PHASE1_OUTPUT

Design a 3–5 screen teaching arc for this topic. Choose ONE code snippet from the
scope bundle for the code↔English translator primitive.

Return structured markdown in exactly this format:

## Curriculum: $ARGUMENTS

### Metaphor
<one sentence — a concrete, specific metaphor for this topic>

### Screens
- Screen 1 — <title>: <body text, 2-4 sentences>
- Screen 2 — <title>: <body text>
- Screen 3 — <title>: <body text> [TRANSLATOR: <file:line ref from scope bundle>]
- Screen 4 — <title>: <body text>
- Screen 5 — <title>: <body text>  (omit if 3-4 screens sufficient)

### Translator Pick
- Code ref: <file:line>
- English explanation: <2-3 sentences explaining what the code does in plain English>
```

## Phase 3 — Authoring (Speedwagon)

Dispatch Speedwagon with this prompt template, passing the Phase 1 and Phase 2 outputs:

```
You are authoring an interactive explainer module.

TOPIC: $ARGUMENTS
SLUG: $SLUG

SCOPE BUNDLE (from Riko):
$PHASE1_OUTPUT

CURRICULUM (from Senku):
$PHASE2_OUTPUT

Instructions:
1. Read every file:line reference in the scope bundle using the Read tool.
   Verify each ref exists before embedding it.
2. Write the module brief to .claude/explain-briefs/$SLUG.md following the
   brief shape shown in .claude/explain-design-examples/module-brief-example.md.
3. Write the HTML fragment to .claude/explain-briefs/$SLUG.fragment.html
   by filling in templates/explain/module-fragment.html.tmpl.
   Replace ALL __PLACEHOLDER__ tokens with real content.
4. Run bash scripts/compile-explain.sh to assemble explain-out/index.html.
5. Report: brief path, fragment path, assembler exit code, output path.
```

## Phase 4 — Assembly

After Speedwagon completes, confirm the assembler was invoked. If Speedwagon's output shows a non-zero exit code, run the assembler directly:

```bash
bash scripts/compile-explain.sh
```

Then show the user:
```
explain-out/index.html is ready.
Open in browser: file://<absolute-path>/explain-out/index.html
```

## Revise Mode

When `$ARGUMENTS` starts with `--revise <slug>`:

1. Check `.claude/explain-briefs/<slug>.md` exists — error if not.
2. Check `explain-out/status.json` for notes on that slug.
3. Dispatch Speedwagon with this prompt:

```
You are revising an existing explainer module.

SLUG: $SLUG

Re-read the existing brief at .claude/explain-briefs/$SLUG.md.
Read explain-out/status.json for revision notes on this slug.
Apply the notes to improve the module. Rewrite the HTML fragment
at .claude/explain-briefs/$SLUG.fragment.html with the improvements.
Then run: bash scripts/compile-explain.sh --revise $SLUG
Report: fragment path, assembler exit code, output path.
```

## Output Structure

```
explain-out/
  index.html        rendered course (gitignored)
  status.json       per-module feedback state (gitignored)

.claude/explain-briefs/
  <slug>.md             module brief
  <slug>.fragment.html  filled-in HTML fragment
```

## Critical Rules

1. **REQUIRE deep-dive.local.md** — fail early with a clear message if absent
2. **SPEEDWAGON AUTHORS** — Speedwagon owns brief + HTML authoring; do not hand this to Loid
3. **PRIMITIVE VOCABULARY** — author fragments using only the primitives in `agents/Speedwagon.md` "Allowed Primitives" table; the lint guardrail (`lib/explain-lint.py`) rejects undefined classes, forbidden inline handlers, and CSS variables outside the `:root` block. Multi-primitive composition is permitted; multi-module-per-invocation is deferred to v2 (see Rule 5).
4. **GITIGNORED OUTPUT** — explain-out/ is gitignored; never commit generated artifacts
5. **SINGLE MODULE** — this command produces one module per invocation; multi-module is deferred
