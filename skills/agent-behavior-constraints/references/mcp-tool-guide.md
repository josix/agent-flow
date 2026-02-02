# MCP Tool Guide

Guidelines for Model Context Protocol (MCP) tool usage and domain-specific tool preferences.

## Overview

MCP tools provide domain-aware interfaces that understand context better than raw CLI commands. Prefer MCP tools when available for domain operations.

---

## Domain Tool Priority Matrix

| Domain | Preferred Tools | Fallback | Notes |
|--------|-----------------|----------|-------|
| Airflow | MCP Airflow tools | CLI | MCP understands DAG context |
| Database | MCP database tools | Direct SQL | MCP handles connection management |
| GitHub | `gh` CLI or MCP | API calls | Both `gh` and MCP are acceptable |
| Kubernetes | MCP K8s tools | kubectl | MCP manages context switching |
| Obsidian | MCP Obsidian tools | File operations | MCP understands vault structure |
| Playwright | MCP Playwright tools | Direct API | MCP manages browser state |

---

## MCP Tool Selection Rules

### Rule 1: Check Availability First

Before using CLI commands:
1. Check if MCP tools exist for the domain
2. Verify the MCP server is connected
3. Review available MCP tool capabilities

### Rule 2: Prefer Domain-Aware Tools

MCP tools offer advantages:
- **Context awareness**: Understand domain-specific concepts
- **State management**: Track sessions and connections
- **Error handling**: Provide domain-relevant error messages
- **Type safety**: Structured inputs and outputs

### Rule 3: Fall Back Gracefully

Use CLI fallback only when:
- MCP tools are unavailable
- MCP server is disconnected
- User explicitly requests CLI
- Specific CLI features are needed

### Rule 4: Document Tool Choice

When using CLI over MCP:
```
Tool Choice Log:
- Domain: [Domain name]
- Available MCP: [Yes/No]
- Tool Used: [CLI command]
- Reason: [Why CLI was chosen]
```

---

## Domain-Specific Guidance

### GitHub Operations

**Preferred: `gh` CLI or MCP GitHub tools**

| Operation | Preferred Tool | Alternative |
|-----------|----------------|-------------|
| Create PR | `gh pr create` | MCP create_pull_request |
| List issues | `gh issue list` | MCP list_issues |
| Review PR | `gh pr review` | MCP pull_request_review_write |
| Get file | MCP get_file_contents | `gh api` |

**Rules:**
- Use `gh` CLI for most operations as it is well-established
- Use MCP for complex queries and file operations
- Avoid raw API calls when `gh` or MCP available

### Obsidian Operations

**Preferred: MCP Obsidian tools**

| Operation | MCP Tool | Fallback |
|-----------|----------|----------|
| Search notes | obsidian_simple_search | Grep |
| Read note | obsidian_get_file_contents | Read |
| Create note | obsidian_append_content | Write |
| List files | obsidian_list_files_in_dir | Glob |

**Rules:**
- MCP understands vault structure and links
- MCP handles frontmatter and metadata
- Use MCP for any vault modifications

### Playwright Operations

**Preferred: MCP Playwright tools**

| Operation | MCP Tool | Alternative |
|-----------|----------|-------------|
| Navigate | browser_navigate | - |
| Click | browser_click | - |
| Screenshot | browser_take_screenshot | - |
| Snapshot | browser_snapshot | - |

**Rules:**
- MCP manages browser state across calls
- MCP handles element references
- Always use MCP for browser automation

### Database Operations

**Preferred: MCP database tools when available**

**Rules:**
- MCP handles connection pooling
- MCP provides query safety features
- Use raw SQL only when MCP unavailable
- Document connection details for fallback

### Kubernetes Operations

**Preferred: MCP K8s tools when available**

**Rules:**
- MCP manages kubeconfig context
- MCP provides cluster-aware operations
- Fall back to kubectl with explicit context

---

## MCP Tool Discovery

### How to Check for MCP Tools

1. **List available MCP resources**
   - Use ListMcpResourcesTool to see available servers

2. **Check server capabilities**
   - Review tool descriptions for the domain
   - Verify server is connected and responsive

3. **Test tool availability**
   - Make a simple read operation
   - Confirm expected response format

### Common MCP Servers

| Server | Domain | Key Tools |
|--------|--------|-----------|
| personal-github | GitHub | PR, issue, file operations |
| obsidian | Notes | Vault search and edit |
| playwright | Browser | Automation and testing |
| context7 | Documentation | Library docs lookup |

---

## Anti-Patterns to Avoid

### 1. Ignoring MCP Tools
```
AVOID: Using curl to fetch GitHub data
PREFER: Using gh CLI or MCP GitHub tools
```

### 2. Raw File Operations on Managed Content
```
AVOID: Using Write to edit Obsidian notes
PREFER: Using MCP obsidian_patch_content
```

### 3. Manual State Management
```
AVOID: Tracking browser state manually
PREFER: Using MCP Playwright for all browser ops
```

### 4. Unstructured Queries
```
AVOID: String-based SQL in shell commands
PREFER: MCP database tools with parameterized queries
```
