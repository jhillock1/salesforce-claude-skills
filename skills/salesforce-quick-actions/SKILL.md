---
name: salesforce-quick-actions
description: Create and deploy quick actions (flow-based, field update, etc.) correctly scoped to objects
allowed-tools: [Bash, Read, Write, Edit, mcp__Salesforce_DX__*]
---

# Quick Actions

## When to Use
- Creating a new quick action on a record page
- Wiring a Screen Flow to a quick action button
- Fixing "action not found" errors on flexipages
- Understanding global vs object-scoped actions

## Critical Knowledge

### Global vs Object-Scoped Actions
This is the #1 mistake. **Object-scoped actions** are required for flexipages.

| Type | File Location | XML Element | Flexipage Reference |
|------|--------------|-------------|-------------------|
| **Object-scoped** ✅ | `objects/Case/quickActions/MyAction.quickAction-meta.xml` | Has `<targetObject>Case</targetObject>` | `Case.MyAction` |
| **Global** ❌ | `quickActions/MyAction.quickAction-meta.xml` | No `<targetObject>` | Won't work on flexipages |

⚠️ File location alone is NOT enough. You MUST include `<targetObject>` in the XML even if the file is under `objects/Case/quickActions/`.

### Flow-Based Quick Action Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<QuickAction xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Propose Solution</label>
    <optionsCreateFeedItem>false</optionsCreateFeedItem>
    <targetObject>Case</targetObject>
    <type>Flow</type>
    <flowDefinition>Propose_Solution_QuickAction</flowDefinition>
</QuickAction>
```

**Key fields:**
- `<targetObject>` — REQUIRED for flexipage visibility
- `<type>Flow</type>` — tells SF this launches a screen flow
- `<flowDefinition>` — API name of the flow (NOT the flow label)

### Field Update Quick Action Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<QuickAction xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Close Case</label>
    <optionsCreateFeedItem>false</optionsCreateFeedItem>
    <targetObject>Case</targetObject>
    <type>Update</type>
    <targetRecordType>Case</targetRecordType>
    <quickActionLayout>
        <layoutSectionStyle>TwoColumnsLeftToRight</layoutSectionStyle>
        <quickActionLayoutColumns>
            <quickActionLayoutItems>
                <field>Status</field>
                <uiBehavior>Edit</uiBehavior>
            </quickActionLayoutItems>
        </quickActionLayoutColumns>
    </quickActionLayout>
</QuickAction>
```

## Recipes

### Create a Flow-Based Quick Action

**Step 1:** Create the Screen Flow first (see `salesforce-flows` skill)

**Step 2:** Deploy the flow:
```bash
sf project deploy start --source-dir force-app/main/default/flows/My_Flow.flow-meta.xml --target-org <your-sandbox-alias>
```

**Step 3:** Create the QuickAction XML at:
`force-app/main/default/objects/Case/quickActions/My_Action.quickAction-meta.xml`

Use the Flow-Based template above.

**Step 4:** Deploy the quick action:
```bash
sf project deploy start --source-dir force-app/main/default/objects/Case/quickActions/My_Action.quickAction-meta.xml --target-org <your-sandbox-alias>
```

**Step 5:** Wire it to the flexipage (see `salesforce-lightning-pages` skill)

### Fix "Action Not Found" on Flexipage Deploy

**Symptom:** Flexipage deploy fails saying action `Case.MyAction` doesn't exist.

**Diagnosis checklist:**
1. Does the QuickAction XML have `<targetObject>Case</targetObject>`?
   - If NO: Add it, redeploy the action, then retry flexipage
2. Is the action deployed to the org?
   - Check: `sf project retrieve start --metadata "QuickAction:Case.MyAction" --target-org <your-sandbox-alias>`
3. Is it registered as global instead of object-scoped?
   - If YES: Delete the global version first, then redeploy as object-scoped

**To delete a global action and redeploy as object-scoped:**
```bash
# Create destructiveChanges.xml
cat > /tmp/destructive/destructiveChanges.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>MyAction</members>
        <name>QuickAction</name>
    </types>
    <version>62.0</version>
</Package>
EOF

cat > /tmp/destructive/package.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <version>62.0</version>
</Package>
EOF

# Delete global version
sf project deploy start --manifest /tmp/destructive/package.xml --post-destructive-changes /tmp/destructive/destructiveChanges.xml --target-org <your-sandbox-alias>

# Now deploy as object-scoped
sf project deploy start --source-dir force-app/main/default/objects/Case/quickActions/MyAction.quickAction-meta.xml --target-org <your-sandbox-alias>
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| File in `objects/Case/quickActions/` but still global | Add `<targetObject>Case</targetObject>` to XML |
| Flow not found by quick action | Deploy the flow BEFORE deploying the quick action |
| Action exists but won't show on page | Wire it in flexipage highlights panel — see lightning-pages skill |
| `<flowDefinition>` wrong | Use Flow API Name, not label. Check: `force-app/main/default/flows/` for filename |

## Validation

### Automated Check
```bash
# Validate quick action has <targetObject> element
bash skills/salesforce-quick-actions/validate-quick-action.sh \
  force-app/main/default/objects/Case/quickActions/MyAction.quickAction-meta.xml
```

### Manual Verification
1. Deploy succeeds without errors
2. Navigate to record page → action appears in action bar
3. Click action → flow/form launches correctly
4. Submit → record updates as expected
