---
name: salesforce-connect
description: Verify Salesforce MCP connection and authentication at session start
allowed-tools: [Bash, Read, ListMcpResourcesTool]
---

# Salesforce MCP Connection

Diagnose and fix Salesforce MCP server connection issues at session start.

## When to Use

- At the start of any Claude Code session in this project
- "Connect to Salesforce"
- "Check Salesforce connection"
- "Is Salesforce MCP working?"
- When Salesforce tools aren't responding

## Instructions

### Step 1: Enable Salesforce MCP in Settings

**This is the most common fix.** The MCP server is configured but needs user approval:

1. Run `/config` (or press `Cmd+,`)
2. Find "salesforce" in the MCP Servers section
3. Enable it
4. Restart Claude Code

### Step 2: Verify Salesforce CLI Authentication

```bash
sf org list
```

**Expected output:**
- `sandbox` org with status "Connected" (used by MCP server)
- `production` org with status "Connected" (for read-only reference)

**If auth is missing**, re-authenticate:
```bash
sf org login web --alias sandbox --instance-url https://test.salesforce.com
sf org login web --alias production --instance-url https://login.salesforce.com
```

### Step 3: Verify .mcp.json Configuration

```bash
cat .mcp.json
```

**Required configuration:**
```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y",
        "@salesforce/mcp",
        "--orgs", "sandbox",
        "--toolsets", "orgs,metadata,data,apex,lwc-experts",
        "--allow-non-ga-tools"
      ]
    }
  }
}
```

### Step 4: Manual MCP Server Test

Test if the MCP server can start manually:
```bash
npx -y @salesforce/mcp --orgs sandbox --toolsets orgs --help
```

If this fails, there may be a package or auth issue.

### Step 5: After Fixing - Restart Required

**MCP servers only load at Claude Code startup.** After making any fix:
1. Exit Claude Code completely
2. Restart Claude Code in this project directory
3. Run `/salesforce-connect` again to verify

## Troubleshooting Checklist

| Issue | Fix |
|-------|-----|
| No Salesforce tools visible | Enable in settings + restart |
| `sf org list` shows no orgs | Run `sf org login web` |
| MCP server fails to start | Check `npx` and node versions |
| Wrong org targeted | Verify `--orgs sandbox` in .mcp.json |

## Available Toolsets (When Connected)

| Toolset | Purpose |
|---------|---------|
| orgs | Org management and info |
| metadata | Retrieve/deploy metadata |
| data | SOQL queries and DML |
| apex | Execute anonymous Apex |
| lwc-experts | LWC development assistance |

## Safety Reminder

- **Sandbox** is the default target for all writes/deploys
- **Production** queries are read-only via SOQL
- Never deploy to production without explicit user confirmation
