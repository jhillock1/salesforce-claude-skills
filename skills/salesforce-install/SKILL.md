---
name: salesforce-install
description: Auto-configure Salesforce skills for user's org (discovers aliases, RecordTypes, custom objects)
allowed-tools: [Bash, Read, Write, Edit, mcp__Salesforce_DX__*]
---

# Salesforce Skills Installation & Configuration

**Run this skill FIRST** before using any other Salesforce skills. It auto-configures them for your org.

## When to Use

- "Install Salesforce skills"
- "Configure Salesforce skills for my org"
- "Set up Salesforce skills"
- First time using these skills in a new project

## What This Does

Automates the tedious customization steps:
1. ✅ Verifies prerequisites (sf CLI, MCP connection)
2. 🔍 Discovers your org aliases
3. 📊 Queries RecordTypes from your org
4. 📦 Lists custom objects
5. ✏️ Auto-populates customization sections in skills
6. 👀 Shows you the changes for approval

**Result:** Skills are customized for your org, Claude knows your context.

---

## Installation Workflow

### Step 1: Verify Prerequisites

```bash
# Check Salesforce CLI
sf --version

# Check authenticated orgs
sf org list
```

**Expected:**
- `sf` CLI installed (v2.0+)
- At least one authenticated org

**If missing:**
```bash
# Install sf CLI (macOS)
brew install sf

# Authenticate to sandbox
sf org login web --alias YOUR_SANDBOX_NAME --instance-url https://test.salesforce.com

# Authenticate to production (optional, for read-only queries)
sf org login web --alias YOUR_PROD_NAME --instance-url https://login.salesforce.com
```

### Step 2: Verify Salesforce MCP Connection

**Check if MCP is configured:**
```bash
# In your Salesforce project directory
cat .mcp.json
```

**Should see:**
```json
{
  "mcpServers": {
    "salesforce": {
      "command": "npx",
      "args": [
        "-y",
        "@salesforce/mcp",
        "--orgs", "YOUR_ORG_ALIAS",
        "--toolsets", "orgs,metadata,data,apex,lwc-experts",
        "--allow-non-ga-tools"
      ]
    }
  }
}
```

**If missing,** create `.mcp.json` in your project root with the config above (replace `YOUR_ORG_ALIAS`).

**Then restart Claude Code** (MCP servers only load at startup).

### Step 3: Discover Org Configuration

**Get org aliases:**
```bash
sf org list --json | jq -r '.result.nonScratchOrgs[] | .alias // .username'
```

**Ask user which org to use as default:**
- Sandbox for development/deployment
- Production for read-only queries (optional)

**Store aliases for later:**
```bash
SANDBOX_ALIAS="<user's choice>"
PROD_ALIAS="<user's choice or leave blank>"
```

### Step 4: Query RecordTypes

**For each standard object (Case, Opportunity, Account, Lead, Contact):**

```bash
sf data query \
  --query "SELECT SobjectType, DeveloperName FROM RecordType WHERE SobjectType IN ('Case','Opportunity','Account','Lead','Contact') ORDER BY SobjectType, DeveloperName" \
  --target-org "$SANDBOX_ALIAS" \
  --json
```

**Parse output** and group by SobjectType:
```
Case: Service_Cloud_Case, Sales_Cloud_Case
Opportunity: New_Business, Renewal, Upsell
Account: Business_Account, Person_Account
```

**If no RecordTypes found:** Note "Standard (no custom RecordTypes)"

### Step 5: List Custom Objects

```bash
sf org list metadata --metadata-type CustomObject --target-org "$SANDBOX_ALIAS" --json | jq -r '.result[] | select(.fullName | endswith("__c")) | .fullName'
```

**Get top 10** (or all if < 10). These will be added to the customization section.

### Step 6: Update salesforce-patterns/SKILL.md

**Find the customization section:**
```bash
grep -n "Org-Specific Context" skills/salesforce-patterns/SKILL.md
```

**Replace the RecordTypes template with discovered values:**

```markdown
### RecordTypes in Use
- **Case:** Service_Cloud_Case, Sales_Cloud_Case
- **Opportunity:** New_Business, Renewal, Upsell
- **Account:** Business_Account, Person_Account
- **Lead:** Standard (no custom RecordTypes)
```

**Replace the Custom Objects template:**

```markdown
### Custom Objects
- CustomObject1__c - [User should add description]
- CustomObject2__c - [User should add description]
- CustomObject3__c - [User should add description]

> **Note:** Add business purpose for each custom object above. This helps Claude understand your org's data model.
```

### Step 7: Update Org Aliases in All Skills

**Replace placeholder aliases with actual values:**

```bash
# Find all SKILL.md files
find skills -name "SKILL.md" -exec sed -i '' "s/<your-sandbox-alias>/$SANDBOX_ALIAS/g" {} \;

# If production alias provided
if [ -n "$PROD_ALIAS" ]; then
  find skills -name "SKILL.md" -exec sed -i '' "s/<your-prod-alias>/$PROD_ALIAS/g" {} \;
fi
```

### Step 8: Update .mcp.json (if needed)

If `.mcp.json` has a placeholder alias, update it:

```bash
# Check current config
CURRENT_ALIAS=$(jq -r '.mcpServers.salesforce.args[] | select(. != "--orgs") | select(startswith("--") | not)' .mcp.json 2>/dev/null)

if [ "$CURRENT_ALIAS" != "$SANDBOX_ALIAS" ]; then
  echo "⚠️ .mcp.json uses alias: $CURRENT_ALIAS"
  echo "You selected: $SANDBOX_ALIAS"
  echo ""
  echo "Update .mcp.json to use $SANDBOX_ALIAS? (requires Claude Code restart)"
fi
```

### Step 9: Show Summary & Next Steps

**Display what was configured:**

```
✅ Configuration Complete

**Org Aliases:**
- Sandbox: dev-sandbox
- Production: production (read-only)

**RecordTypes Found:**
- Case: Service_Cloud_Case, Sales_Cloud_Case
- Opportunity: New_Business, Renewal

**Custom Objects Found (top 10):**
- CustomObject1__c
- CustomObject2__c
- CustomObject3__c

**Files Updated:**
- skills/salesforce-patterns/SKILL.md (RecordTypes, custom objects)
- All SKILL.md files (org aliases: <your-sandbox-alias> → dev-sandbox)

**Next Steps:**
1. Review changes: `git diff skills/`
2. Add descriptions to custom objects in salesforce-patterns/SKILL.md
3. (Optional) Add integration points and project references
4. Start using the skills!

**Try asking:**
- "Create a flow-based quick action for Case"
- "Deploy this flow to sandbox"
- "Check this Apex class for SOQL security issues"
```

---

## Manual Configuration (If Auto-Config Fails)

If MCP isn't available or queries fail, fall back to manual:

**1. Edit salesforce-patterns/SKILL.md:**
- Add your RecordTypes manually
- List your custom objects
- Update org aliases

**2. Run this in your terminal:**
```bash
cd ~/.claude/skills/salesforce  # or wherever you cloned it

# Replace aliases in all skills
find skills -name "SKILL.md" -exec sed -i '' 's/<your-sandbox-alias>/YOUR_ACTUAL_ALIAS/g' {} \;
find skills -name "SKILL.md" -exec sed -i '' 's/<your-prod-alias>/YOUR_ACTUAL_ALIAS/g' {} \;
```

**3. Restart Claude Code** to pick up changes.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `sf org list` shows no orgs | Run `sf org login web` to authenticate |
| MCP tools not available | Check `.mcp.json` exists, restart Claude Code |
| RecordType query fails | Verify org alias is correct, check permissions |
| No custom objects found | Your org may only use standard objects (that's fine) |
| Changes not taking effect | Restart Claude Code session |

---

## Re-running Configuration

**If you add new RecordTypes or custom objects later:**

```bash
# Just re-run this skill
"Configure salesforce skills for my org"
```

It will re-query and update. You can also manually edit `salesforce-patterns/SKILL.md` anytime.

---

## What Gets Customized

| Skill | What Changes |
|-------|-------------|
| **All skills** | `<your-sandbox-alias>` → actual alias |
| **All skills** | `<your-prod-alias>` → actual alias |
| **salesforce-patterns** | RecordTypes section populated |
| **salesforce-patterns** | Custom objects section populated |
| **salesforce-connect** | Example .mcp.json uses your alias |

**What stays generic:**
- Validation scripts (work for any org)
- Pattern examples (LWC, SOQL, Apex best practices)
- Deployment workflows

---

## Privacy Note

This skill only queries **metadata** (RecordTypes, object names). It does NOT query actual records or data. All configuration stays local in your skill files.
