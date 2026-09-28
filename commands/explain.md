---
name: explain
description: Generate an interactive one-module explainer for a topic — Riko gathers code scope, Senku plans a 3-5 screen teaching arc, Speedwagon authors the HTML, assembler produces explain-out/index.html
argument-hint: <topic> [--revise <slug>]
---

# Explain Command

Generate an interactive HTML explainer for a codebase topic. Riko gathers the relevant code scope, Senku designs a 3–5 screen teaching arc, Speedwagon authors the module brief and HTML fragment, and the assembler concatenates everything into `explain-out/index.html` — a file you can open directly in a browser.

Uses `.claude/deep-dive.local.md` when present (richer context); without it, Riko orients from the README and entry points. The graphify knowledge graph (`graphify-out/graph.json`) is used if present; absent it degrades gracefully.

## Argument Parsing

`$ARGUMENTS` is the raw argument string passed to this command.

- If `$ARGUMENTS` is **empty** → print usage error and stop:
  ```
  Usage: /agent-flow:explain <topic>
  Example: /agent-flow:explain how does orchestration work
  Tip: run /deep-dive first for richer context.
  ```
- If `$ARGUMENTS` starts with `--revise` → **revise mode**: extract the slug from the argument (e.g. `--revise orchestration-pipeline`) and skip Phase 1–2 if the brief exists.
- Otherwise → **normal mode**: `$ARGUMENTS` is the full topic string.

**Slug derivation** (compute once, use throughout all phases):
```bash
slug=$(echo "$ARGUMENTS" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | LC_ALL=C tr -cd 'a-z0-9-' | sed 's/--*/-/g; s/^-//; s/-$//' | cut -c1-40)
if ! echo "$slug" | grep -q '[a-z0-9]'; then
  # Topic has no ASCII a-z0-9 chars (e.g. CJK topics) — fall back to a deterministic hash slug.
  slug="topic-$(printf '%s' "$ARGUMENTS" | cksum | cut -d' ' -f1)"
fi
```

**Reader language**: `READER_LANG` is the BCP-47 tag of the language the topic ($ARGUMENTS) is written in (for example `en` or `zh-TW`), defaulting to `en`. Decide it once here and pass it to Phases 2–3.

## Precondition Checks

Run these checks before dispatching any agents:

```bash
if [[ ! -f ".claude/deep-dive.local.md" ]]; then
  echo "Note: .claude/deep-dive.local.md not found. Continuing without it. For richer context run /deep-dive first."
fi

if [[ ! -f "graphify-out/graph.json" ]]; then
  echo "Note: graphify-out/graph.json not found. Continuing in degraded mode (no graph context)."
fi
```

## Dispatch Notes

- Dispatch each phase with `Agent(subagent_type="agent-flow:<Riko|Senku|Speedwagon>", prompt=...)`.
- End every dispatch prompt below with: "If your report exceeds ~3000 characters, write the full report to `.claude/agent-reports/<agent>-<phase>.md` and return only a ≤1500-char summary, your verdict, and that path." When a reply cites such a path, Read the file and use its contents as `$PHASE1_OUTPUT` / `$PHASE2_OUTPUT`.
- Pass absolute plugin paths (`${CLAUDE_PLUGIN_ROOT}/…`) in every prompt. Never copy or symlink `templates/` or `scripts/` into the project.

## Phase 1 — Scope (Riko)

Dispatch Riko with this prompt template, substituting `$ARGUMENTS` for `TOPIC`:

```
TOPIC: $ARGUMENTS

You are gathering code scope for a topic explainer. Your output will be consumed by
Senku (curriculum design) and Speedwagon (HTML authoring) — keep it structured.

Steps:
1. If .claude/deep-dive.local.md exists, read it, especially Purpose & Use Cases and
   Key Flows. Otherwise read the README and at most 5 entry-point files relevant to the topic.
2. If graphify-out/graph.json exists, query for nodes related to the topic.
3. Identify 3–8 file:line refs directly relevant to the topic (concrete functions,
   types, or config values — not just filenames).
4. Identify 2–4 graph node names (or write "graph: unavailable" if graph absent).
5. Extract 3–6 key terminology terms specific to this topic.

Return structured markdown in exactly this format:

## Scope Bundle: $ARGUMENTS

### Why It Matters
<1-2 sentences on what problem this code solves for its user>

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
READER_LANG: $READER_LANG

SCOPE BUNDLE (from Riko):
$PHASE1_OUTPUT

Design a 3–5 screen teaching arc for this topic. Choose ONE code snippet from the
scope bundle for the code↔English translator primitive.

Plain-language rules: write for a smart newcomer with no background in this codebase.
Write in READER_LANG, but keep code, identifiers, file paths, and CLI flags verbatim.
Define every technical term on first use. No unexplained acronyms. At most 3 sentences
per paragraph. Screen 1 opens from a concrete, user-visible action. Each screen says
why the reader should care before explaining how.

Return structured markdown in exactly this format:

## Curriculum: $ARGUMENTS

### TL;DR
<= 2 sentences: what this is and why it matters, in READER_LANG>

### Metaphor
<one sentence — a concrete, specific metaphor for this topic>

### Screens
- Screen 1 — <title>: <body text, 2-4 sentences> [VISUAL: diagram|translator|step-cards|callout|badge-list|icon-rows|quiz]
- Screen 2 — <title>: <body text> [VISUAL: ...]
- Screen 3 — <title>: <body text> [TRANSLATOR: <file:line ref from scope bundle>] [VISUAL: translator]
- Screen 4 — <title>: <body text> [VISUAL: ...]
- Screen 5 — <title>: <body text>  (omit if 3-4 screens sufficient) [VISUAL: ...]

### Translator Pick
- Code ref: <file:line>
- English explanation: <2-3 sentences explaining what the code does in plain English>

### Glossary
- <term>: <plain definition>  (3-6 entries, seeded from Riko's Key Terminology)
```

## Phase 3 — Authoring (Speedwagon)

Dispatch Speedwagon with this prompt template, passing the Phase 1 and Phase 2 outputs:

```
You are authoring an interactive explainer module.

TOPIC: $ARGUMENTS
SLUG: $SLUG
READER_LANG: $READER_LANG

SCOPE BUNDLE (from Riko):
$PHASE1_OUTPUT

CURRICULUM (from Senku):
$PHASE2_OUTPUT

Plain-language rules: write for a smart newcomer with no background in this codebase.
Write in READER_LANG, but keep code, identifiers, file paths, and CLI flags verbatim.
Define every technical term on first use. No unexplained acronyms. At most 3 sentences
per paragraph. Each screen says why the reader should care before explaining how.

Instructions:
1. Read every file:line reference in the scope bundle using the Read tool.
   Verify each ref exists before embedding it.
2. Write the module brief to .claude/explain-briefs/$SLUG.md following the
   brief shape shown in ${CLAUDE_PLUGIN_ROOT}/templates/explain/module-brief-example.md.
3. Write the HTML fragment to .claude/explain-briefs/$SLUG.fragment.html
   by filling in ${CLAUDE_PLUGIN_ROOT}/templates/explain/module-fragment.html.tmpl.
   Replace ALL __PLACEHOLDER__ tokens with real content, including __MODULE_TLDR__,
   __GLOSSARY_HEADING__, __GLOSSARY_ITEMS__, and the translator label placeholders
   (__EXPLANATION_LABEL__, __TOGGLE_SHOW_LABEL__, __TOGGLE_HIDE_LABEL__), all in READER_LANG.
   Set `lang: $READER_LANG` in the brief frontmatter. Wrap each glossary term's first
   use in the prose with the `.term` tooltip primitive.
4. Run bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-explain.sh to assemble explain-out/index.html.
5. Report: brief path, fragment path, assembler exit code, output path.
```

## Phase 4 — Assembly

After Speedwagon completes, confirm the assembler was invoked. If Speedwagon's output shows a non-zero exit code, run the assembler directly:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-explain.sh
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
Keep the brief's existing `lang:` value.
Then run: bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-explain.sh --revise $SLUG
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

1. **DEEP-DIVE OPTIONAL** — use `.claude/deep-dive.local.md` when present; never block on it
2. **SPEEDWAGON AUTHORS** — Speedwagon owns brief + HTML authoring; do not hand this to Loid
3. **PRIMITIVE VOCABULARY** — author fragments using only the primitives in `agents/Speedwagon.md` "Allowed Primitives" table; the lint guardrail (`lib/explain-lint.py`) rejects undefined classes, forbidden inline handlers, and CSS variables outside the `:root` block. Multi-primitive composition is permitted; multi-module-per-invocation is deferred to v2 (see Rule 5).
4. **GITIGNORED OUTPUT** — explain-out/ is gitignored; never commit generated artifacts
5. **SINGLE MODULE** — this command produces one module per invocation; multi-module is deferred
6. **PLAIN LANGUAGE, READER'S LANGUAGE** — write in `READER_LANG` (the topic's language) using plain-language rules; code, identifiers, file paths, and CLI flags stay verbatim
