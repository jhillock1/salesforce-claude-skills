---
name: salesforce-deploy
description: Deploy metadata to sandbox safely — targeted deploys, validation, error filtering
allowed-tools: [Bash, Read, mcp__Salesforce_DX__*]
---

# Salesforce Deployment

## When to Use
- Deploying new or modified metadata to sandbox
- Fixing deployment failures
- Understanding pre-existing vs new errors
- Choosing between full-org and targeted deploys

## Critical Knowledge

### ALWAYS Use Targeted Deploys for New Work
Full-org deploys (`sf project deploy start` with no flags) will fail if ANY metadata in the repo has errors — even pre-existing ones unrelated to your work.

**🔧 CUSTOMIZE:** Replace `<your-sandbox-alias>` with your actual org alias (run `sf org list` to see aliases)

```bash
# ❌ DON'T: Full org deploy
sf project deploy start --target-org <your-sandbox-alias>

# ✅ DO: Targeted deploy of specific files
sf project deploy start --source-dir force-app/main/default/flows/My_Flow.flow-meta.xml --target-org <your-sandbox-alias>

# ✅ DO: Deploy a whole directory
sf project deploy start --source-dir force-app/main/default/objects/Case --target-org <your-sandbox-alias>

# ✅ DO: Deploy multiple specific paths
sf project deploy start \
  --source-dir force-app/main/default/flows/My_Flow.flow-meta.xml \
  --source-dir force-app/main/default/objects/Case/quickActions/ \
  --target-org <your-sandbox-alias>
```

### Deploy Order Matters
Some metadata depends on other metadata existing first:

```
1. Custom Fields / Objects (dependencies for everything)
2. Flows (referenced by quick actions)  
3. Quick Actions (referenced by flexipages)
4. Flexipages / Page Layouts (reference actions + fields)
5. Permission Sets / Profiles (reference all of the above)
```

Deploy in this order. If you deploy a flexipage that references a quick action that doesn't exist yet, it fails.

### Validate Before Deploy (Optional but Recommended)
```bash
# Dry-run — validates without actually deploying
sf project deploy start --source-dir <path> --target-org <your-sandbox-alias> --dry-run
```

## Recipes

### Deploy a Set of Related Components
When you've built a feature (e.g., fields + flows + quick actions + flexipage):

```bash
# Step 1: Fields first
sf project deploy start --source-dir force-app/main/default/objects/Case/fields/ --target-org <your-sandbox-alias>

# Step 2: Flows
sf project deploy start --source-dir force-app/main/default/flows/My_Flow.flow-meta.xml --target-org <your-sandbox-alias>

# Step 3: Quick Actions (depend on flows)
sf project deploy start --source-dir force-app/main/default/objects/Case/quickActions/ --target-org <your-sandbox-alias>

# Step 4: Flexipage (depends on actions)
sf project deploy start --source-dir force-app/main/default/flexipages/Case_Record_Page.flexipage-meta.xml --target-org <your-sandbox-alias>
```

### Diagnose a Failed Deploy
When a deploy fails:

1. **Read the error carefully** — is it about YOUR metadata or pre-existing?
2. **Common pre-existing errors to IGNORE:**
   - `OrderIntegration` references
   - `PromptFlow` permissions
   - Missing field references in flows you didn't touch
3. **If it's your metadata:**
   - Missing dependency → deploy the dependency first
   - Invalid XML → check element ordering (see flows skill)
   - "Not found" → component isn't deployed yet, deploy it first

### Retrieve Before Modify
When modifying existing metadata (flexipages, layouts):

```bash
# Retrieve current state from org
sf project retrieve start --metadata "FlexiPage:Case_Record_Page" --target-org <your-sandbox-alias>

# Or retrieve by directory
sf project retrieve start --source-dir force-app/main/default/flexipages/ --target-org <your-sandbox-alias>
```

Always retrieve before editing — the repo may be stale.

### Check What's Deployed
```bash
# List all metadata of a type
sf org list metadata --metadata-type FlexiPage --target-org <your-sandbox-alias>

# Retrieve specific component to inspect
sf project retrieve start --metadata "QuickAction:Case.My_Action" --target-org <your-sandbox-alias>
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Full deploy fails on pre-existing errors | Use `--source-dir` for targeted deploy |
| "Component not found" | Deploy dependencies first (fields → flows → actions → pages) |
| Deploying stale local copy | Always `sf project retrieve start` before modifying existing metadata |
| Deploy succeeds but feature missing | Check flow activation status — deployed ≠ activated |
| Timeout on large deploys | Break into smaller targeted deploys |

## Validation After Deploy
```bash
# Check deploy status
sf project deploy report --target-org <your-sandbox-alias>

# Verify component exists
sf org list metadata --metadata-type <type> --target-org <your-sandbox-alias> | grep "MyComponent"
```

Then manually verify in the org UI that the feature works as expected.
