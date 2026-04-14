# Using Your Personal Knowledge Base

A practical guide to the personal-kb integration — letting subagents recall your cross-project decisions, notes, and patterns from a personal knowledge graph you build and own.

## What This Integration Is

Agent Flow teaches Riko, Senku, and Lawliet to query your personal knowledge base via `mcp__personal-kb__*` MCP tools. You wire your own KB into the session — the plugin does not ship any path or data.

Specifically:
- Agent Flow detects whether your personal KB is configured (via the `AGENT_FLOW_PERSONAL_KB_PATH` env var) and writes a `personal_kb:` block into state files during orchestration init.
- When the personal KB is available, the orchestrator injects a one-line preamble into Riko/Senku/Lawliet prompts so they know to query it.
- Loid and Alphonse are intentionally excluded — they are write/verify-only agents and do not need structural recall.

Your personal KB is a separate graphify-indexed folder (e.g., `~/personal/knowledge-base/`) that you maintain. Agent Flow never writes to it.

## Prerequisites

Your personal KB must be graphify'd with `graphify-out/graph.json` present inside it before Agent Flow can use it.

If you have not done this yet:
1. Create your personal knowledge base directory (e.g., `~/personal/knowledge-base/`).
2. Add your notes, decision records, journal entries, or any documents you want indexed.
3. Run the graphify pipeline from within that directory:
   ```bash
   cd ~/personal/knowledge-base
   /graphify
   ```
   This creates `~/personal/knowledge-base/graphify-out/graph.json`.

See the [Using Graphify guide](using-graphify.md) for graphify installation and build details.

## Setup

### Step (a) — Register the MCP server under the key `personal-kb`

The personal-kb MCP server is just the graphify server pointed at your personal KB. Add it to YOUR `~/.claude.json` or your project's `.mcp.json` (NOT the agent-flow plugin's `.mcp.json` — that is not modified).

**Before** (typical graphify server entry for a project):
```json
{
  "mcpServers": {
    "graphify": {
      "command": "python3",
      "args": ["-m", "graphify.serve", "--graph", "/path/to/project/graphify-out/graph.json"]
    }
  }
}
```

**After** (add a separate personal-kb entry pointing to your personal KB):
```json
{
  "mcpServers": {
    "graphify": {
      "command": "python3",
      "args": ["-m", "graphify.serve", "--graph", "/path/to/project/graphify-out/graph.json"]
    },
    "personal-kb": {
      "command": "python3",
      "args": ["-m", "graphify.serve", "--graph", "/Users/you/personal/knowledge-base/graphify-out/graph.json"]
    }
  }
}
```

The key name `personal-kb` is what Agent Flow's agents look for when calling `mcp__personal-kb__*` tools. Do not rename it.

For a global setup (available in all Claude Code sessions), add the entry to `~/.claude.json`.

### Step (b) — Export `AGENT_FLOW_PERSONAL_KB_PATH` in your shell profile

```bash
# Add to ~/.zshrc or ~/.bashrc
export AGENT_FLOW_PERSONAL_KB_PATH=~/personal/knowledge-base
```

This env var tells `scripts/detect-personal-kb.sh` where to look for your KB. The script expands `~` automatically.

### Step (c) — Restart your Claude Code session

Close and reopen Claude Code (or reload the shell session) so that both the MCP server registration and the env var take effect.

## Verification

After setup, verify the integration is working:

1. **Check the MCP server is connected**:
   ```
   /mcp
   ```
   You should see `personal-kb: connected` in the output.

2. **Check the state file after running an orchestration command**:
   ```bash
   grep -A7 '^personal_kb:' .claude/orchestration.local.md
   ```
   You should see:
   ```yaml
   personal_kb:
     available: true
     path: "/Users/you/personal/knowledge-base"
     graph_path: "/Users/you/personal/knowledge-base/graphify-out/graph.json"
     generated: "2026-04-13T..."
     nodes: 342
     edges: 891
     communities: 27
   ```

3. **Check Riko can call the tool**:
   Ask Riko directly:
   > What are the god nodes in my personal knowledge base?

   Riko should call `mcp__personal-kb__god_nodes` and return results.

## How Agents Use It

Once configured, subagents query the personal KB automatically when the orchestrator detects `personal_kb: available: true` in the state file.

- **Riko** queries for cross-project priors during exploration ("have I seen this pattern before?")
- **Senku** consults personal decisions during planning ("what did I decide about X in past projects?")
- **Lawliet** checks personal anti-patterns during review ("does this code violate a pattern I've documented before?")

See [skills/personal-kb-usage/SKILL.md](../../skills/personal-kb-usage/SKILL.md) for the full query guide, tool decision table, and token hygiene rules.

## Refresh

Re-run the graphify pipeline on your personal KB whenever you add significant new notes or decisions:

```bash
cd ~/personal/knowledge-base
/graphify --update   # incremental, uses manifest
```

This updates `graphify-out/graph.json`. The change takes effect at the next Claude Code session start (or the next orchestration init within a session, since state files are rebuilt on each init run).

**Important**: Run the refresh from a Claude Code session rooted in your **personal KB directory**, not your project directory. The `/graphify` command uses the current working directory.

## Troubleshooting

### `/mcp` shows `personal-kb` as failed

Run the server manually to see the exact error:
```bash
python3 -m graphify.serve --graph ~/personal/knowledge-base/graphify-out/graph.json
```

Common failures:
| Symptom | Fix |
|---------|-----|
| `graphify` module not found | `pip install 'graphifyy[mcp]'` or `pipx install graphifyy && pipx inject graphifyy mcp` |
| Graph file not found | Run `/graphify` from `~/personal/knowledge-base/` first |
| Wrong path in `.mcp.json` | Use the absolute path to `graph.json`, not a relative one |

### `personal_kb: available: false` in state file despite KB existing

Check the env var:
```bash
echo $AGENT_FLOW_PERSONAL_KB_PATH
```

If empty, the env var is not set in the current session. Add it to your shell profile and restart Claude Code.

If set but path doesn't exist:
```bash
ls "$AGENT_FLOW_PERSONAL_KB_PATH/graphify-out/graph.json"
```

If missing, re-run `/graphify` in your personal KB directory.

### Agents ignore the personal KB

Check the state file:
```bash
grep -A7 '^personal_kb:' .claude/orchestration.local.md
```

If `available: false`, the detection failed — see above. If `available: true`, check that agents have `personal-kb-usage` in their skills list and `mcp__personal-kb__*` in their tools list.

### Stale results from personal KB

Re-index your personal KB:
```bash
cd ~/personal/knowledge-base && /graphify --update
```

## Related Documentation

- [Installation](../getting-started/installation.md) — plugin setup
- [State Files Reference](../reference/state-files.md#personal_kb-object) — `personal_kb:` block schema
- [Using Graphify](using-graphify.md) — graphify installation and pipeline details
- [skills/personal-kb-usage/SKILL.md](../../skills/personal-kb-usage/SKILL.md) — agent query guide
