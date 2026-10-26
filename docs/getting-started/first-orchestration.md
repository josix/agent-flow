# Your First Orchestration

This walkthrough takes you from an empty directory to a working Python module with tests, through the `/orchestrate` pipeline. You'll create a Fibonacci module and its pytest suite. **This takes 2-5 minutes and consumes tokens.**

!!! note
    Which agents run depends on the execution profile. A task this small may run as `fast` and skip Riko and Senku. Use a larger task, or `/deep-dive` first, to see them all.

## Before you start

- `claude` CLI installed and configured (see [installation.md](installation.md))
- Python 3.9 or newer available (`python3 --version`)
- `pytest` available, or willing to install it (`pip install pytest` / `uv add --dev pytest`)
- Agent Flow plugin already installed (see [installation.md](installation.md))

## What you'll build

By the end you'll have a `fibonacci.py` file with an iterative `fib(n)` function that raises `ValueError` for negative inputs. Alongside it, `tests/test_fibonacci.py` will contain four cases covering the base cases, a larger value, and the error path. Both files are created and verified entirely by the agent pipeline — you only provide the seed prompt.

## Set up an empty workspace

```bash
mkdir fib-demo && cd fib-demo
claude
```

Start Claude Code inside the fresh directory. There are no source files here yet, which is intentional — Riko will confirm the blank slate before Senku plans.

## Run the orchestration

Once the session is open, run:

```
/orchestrate Create a Python fibonacci.py module with an iterative fib(n) function and a pytest test file in tests/ that covers fib(0), fib(1), fib(10), and a negative-input ValueError case.
```

Then watch the agents work. The sections below describe the full pipeline; under a lighter profile you will see only some of these steps.

## What you'll see, agent by agent

### Riko explores

Riko opens by surveying the workspace. Because the directory is empty, Riko will report exactly that — no existing files, no dependencies, no test framework config detected. This is useful signal: Senku will know there is nothing to preserve or integrate with, and will plan a greenfield implementation. Riko's findings appear as a short summary in chat, typically a sentence or two noting the absence of source files and confirming Python as the target language.

### Senku plans

Senku takes Riko's findings and translates them into a concrete task list. Senku's plan appears as a numbered markdown checklist with items like "create fibonacci.py with iterative fib(n)", "raise ValueError for n < 0", and "create tests/test_fibonacci.py with four test cases". Senku may also note any assumptions — for instance, that `fib(0)` returns 0 and `fib(1)` returns 1. If anything in the plan looks wrong, this is the right moment to notice it, though you don't need to intervene.

### Loid implements

Loid works through Senku's task list one item at a time, writing `fibonacci.py` first and then `tests/test_fibonacci.py`. You'll see file-write events appear in the tool call stream. Loid follows the plan closely, so the iterative algorithm and the `ValueError` guard should both appear exactly as Senku specified. After writing, Loid may run a quick sanity check to confirm the files exist and import cleanly before handing off.

### Lawliet reviews

Lawliet reads the newly created files and checks for code quality issues — things like missing docstrings, edge-case gaps, or deviations from idiomatic Python. It runs in parallel with Alphonse (and with Codex, if installed, under the standard and thorough profiles). You'll see a verdict line in Lawliet's response, either `APPROVED` or `NEEDS_CHANGES`. For a simple Fibonacci module, Lawliet typically approves on the first pass. If Lawliet raises a `NEEDS_CHANGES` verdict, the feedback loops back to Loid automatically; you don't need to do anything.

### Alphonse verifies

Alphonse runs the actual test suite and reports concrete output. You'll see the `pytest` command execute and its output appear verbatim in chat — something along the lines of `4 passed in 0.12s`. Alphonse also checks for import errors or collection failures. If everything passes, you'll see the orchestration-complete marker:

```
<orchestration-complete>TASK VERIFIED</orchestration-complete>
```

## Verify the result yourself

After the session, confirm the files landed and the tests still pass outside Claude:

```bash
ls fibonacci.py tests/test_fibonacci.py
python -m pytest -v
```

Expected output shape: `4 passed in X.XXs` (the exact count may vary slightly if Loid splits edge cases into additional tests).

## If something goes wrong

**Agent stalls or session is interrupted** — orchestration state lives in `.claude/orchestration.local.md` inside `fib-demo/`. Re-running `/orchestrate` starts a new run (state is re-initialized); Loid sees the files already written. Check progress with `head -30 .claude/orchestration.local.md`.

**`pytest` not found** — run `pip install pytest` or, if you're using uv, `uv add --dev pytest`, then re-invoke the orchestration.

**Verification fails on the first Alphonse pass** — this is normal behaviour, not a bug. Blocking findings go to Loid in capped fix rounds. If findings remain at the cap, the report lists them and there is no completion marker.

**Want to start completely clean** — exit the Claude session, then:
```bash
rm -rf fib-demo && cd ..
```
Re-run the workspace setup steps to start fresh.

## Next steps

- [Using /orchestrate](../guides/using-orchestrate.md)
- [Using /deep-dive](../guides/using-deep-dive.md)
- [Architecture overview](../architecture/overview.md)
