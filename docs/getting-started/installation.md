# Installation

Get Agent Flow up and running with Claude Code in minutes.

## Prerequisites

Before installing Agent Flow, ensure you have:

- **Claude Code CLI** installed and configured
- **Bash** shell available (macOS, Linux, or WSL on Windows)
- A project directory where you want to use Agent Flow

## Installation Methods

### Method 1: Plugin Directory (Recommended)

Clone or download Agent Flow to a location on your system, then reference it when launching Claude Code:

```bash
# Clone the repository
git clone https://github.com/your-org/agent-flow.git ~/agent-flow

# Launch Claude Code with the plugin
claude --plugin-dir ~/agent-flow
```

### Method 2: Project-Local Installation

For project-specific usage, add Agent Flow as a subdirectory:

```bash
# From your project root
git clone https://github.com/your-org/agent-flow.git .claude-plugins/agent-flow

# Launch Claude Code with the plugin
claude --plugin-dir .claude-plugins/agent-flow
```

### Method 3: Git Submodule

For version-controlled projects:

```bash
# Add as submodule
git submodule add https://github.com/your-org/agent-flow.git .claude-plugins/agent-flow

# Launch Claude Code with the plugin
claude --plugin-dir .claude-plugins/agent-flow
```

## Directory Structure

After installation, Agent Flow contains:

```
agent-flow/
├── .claude-plugin/
│   └── plugin.json         # Plugin manifest
├── agents/                  # Agent definitions
│   ├── Riko.md
│   ├── Senku.md
│   ├── Loid.md
│   ├── Lawliet.md
│   └── Alphonse.md
├── commands/                # Command definitions
│   ├── orchestrate.md
│   └── deep-dive.md
├── hooks/                   # Hook configurations
│   ├── hooks.json
│   └── scripts/
├── scripts/                 # Utility scripts
├── skills/                  # Skill definitions
└── docs/                    # Documentation
```

## Verifying Installation

After launching Claude Code with the plugin, verify the installation:

1. **Check commands are available**:
   ```
   /orchestrate --help
   /deep-dive --help
   ```

2. **Check agents are registered**:
   - Try delegating to an agent: "Ask Riko to explore the codebase"
   - You should see agent-specific behavior and output formatting

3. **Check hooks are active**:
   - Start a session and observe the project context detection
   - Submit a vague task and observe prompt refinement

## Configuration

### State Directory

Agent Flow creates a `.claude/` directory in your project for state files:

```
your-project/
└── .claude/
    ├── orchestration.local.md   # Created by /orchestrate
    └── deep-dive.local.md       # Created by /deep-dive
```

Add to your `.gitignore`:

```gitignore
# Agent Flow state files
.claude/*.local.md
```

### Environment Variables

Agent Flow uses these environment variables (set automatically by Claude Code):

| Variable | Description |
|----------|-------------|
| `CLAUDE_PLUGIN_ROOT` | Plugin installation directory |
| `TOOL_NAME` | Current tool being used (in hooks) |
| `TOOL_INPUT` | Tool input JSON (in hooks) |

### Project Context Detection

On session start, Agent Flow detects your project type:

| Marker File | Detected Type |
|-------------|---------------|
| `package.json` | Node.js |
| `pyproject.toml` | Python |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pom.xml` | Java (Maven) |
| `build.gradle` | Java (Gradle) |

This affects which verification commands are used.

## Troubleshooting

### Commands Not Found

If `/orchestrate` or `/deep-dive` are not recognized:

1. Verify plugin path is correct
2. Check that `commands/` directory exists
3. Ensure command files have `.md` extension

### Agents Not Responding

If agents don't exhibit specialized behavior:

1. Check that `agents/` directory contains all `.md` files
2. Verify agent names match (case-sensitive)
3. Check for YAML frontmatter syntax errors

### Hooks Not Triggering

If hooks don't seem to activate:

1. Verify `hooks/hooks.json` exists and is valid JSON
2. Check script permissions: `chmod +x hooks/scripts/*.sh`
3. Verify `${CLAUDE_PLUGIN_ROOT}` resolves correctly

### State File Errors

If state files cause issues:

1. Remove existing state files: `rm -f .claude/*.local.md`
2. Ensure `.claude/` directory exists: `mkdir -p .claude`
3. Check disk permissions for writing

## Updating

To update Agent Flow:

```bash
# If cloned directly
cd ~/agent-flow
git pull

# If using submodule
git submodule update --remote .claude-plugins/agent-flow
```

## Uninstalling

To remove Agent Flow:

1. Stop using the `--plugin-dir` flag
2. Optionally remove the plugin directory:
   ```bash
   rm -rf ~/agent-flow
   # OR
   rm -rf .claude-plugins/agent-flow
   ```
3. Remove state files:
   ```bash
   rm -rf .claude/
   ```

## Next Steps

- [Quick Start Guide](quick-start.md) - 5-minute introduction
- [Using Orchestrate](../guides/using-orchestrate.md) - Execute complex tasks
- [Using Deep-Dive](../guides/using-deep-dive.md) - Explore codebases
- [Architecture Overview](../architecture/overview.md) - Understand the system
