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

**🔧 CUSTOMIZE:** Use your own org aliases

**Expected output:**
- Your sandbox org with status "Connected" (used by MCP server)
- Your production org with status "Connected" (for read-only reference, optional)

**If auth is missing**, re-authenticate:
```bash
# Sandbox
sf org login web --alias YOUR_SANDBOX_ALIAS --instance-url https://test.salesforce.com

# Production (optional, for read-only queries)
sf org login web --alias YOUR_PROD_ALIAS --instance-url https://login.salesforce.com
```

### Step 3: Verify .mcp.json Configuration

```bash
cat .mcp.json
```

**🔧 CUSTOMIZE:** Replace `YOUR_SANDBOX_ALIAS` with your org alias (from `sf org list`)

**Example configuration:**
```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y",
        "@salesforce/mcp",
        "--orgs", "YOUR_SANDBOX_ALIAS",
        "--toolsets", "orgs,metadata,data,apex,lwc-experts",
        "--allow-non-ga-tools"
      ]
    }
  }
}
```

**Toolsets you can enable:**
- `orgs` - Org management and info
- `metadata` - Retrieve/deploy metadata  
- `data` - SOQL queries and DML
- `apex` - Execute anonymous Apex
- `lwc-experts` - LWC development assistance

### Step 4: Manual MCP Server Test

Test if the MCP server can start manually:
```bash
npx -y @salesforce/mcp --orgs YOUR_SANDBOX_ALIAS --toolsets orgs --help
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
| Wrong org targeted | Verify `--orgs YOUR_ALIAS` in .mcp.json |

## Available Toolsets (When Connected)

| Toolset | Purpose |
|---------|---------|
| orgs | Org management and info |
| metadata | Retrieve/deploy metadata |
| data | SOQL queries and DML |
| apex | Execute anonymous Apex |
| lwc-experts | LWC development assistance |

## Safety Reminder

**🔧 CUSTOMIZE:** Adjust this based on your deployment strategy

- **Sandbox** should be the default target for all writes/deploys
- **Production** queries should be read-only via SOQL
- Never deploy to production without explicit user confirmation
- Consider using separate MCP configs per project if working with multiple orgs
