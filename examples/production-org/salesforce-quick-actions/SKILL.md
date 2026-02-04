---
name: salesforce-quick-actions
description: Create and deploy quick actions (flow-based, field update, etc.) correctly scoped to objects
allowed-tools: [Bash, Read, Write, Edit, mcp__Salesforce_DX__*]
---

# Quick Actions

> **Example patterns from a Service Cloud + Sales Cloud production org**

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
    <label>Log Meeting</label>
    <optionsCreateFeedItem>false</optionsCreateFeedItem>
    <targetObject>Account</targetObject>
    <type>Flow</type>
    <flowDefinition>Log_Meeting_QuickAction</flowDefinition>
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
    <label>Escalate to Tier 2</label>
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
            <quickActionLayoutItems>
                <field>Priority</field>
                <uiBehavior>Edit</uiBehavior>
            </quickActionLayoutItems>
        </quickActionLayoutColumns>
    </quickActionLayout>
</QuickAction>
```

## Real-World Examples

### Example 1: Meeting Note Capture (Flow-Based)

**Business need:** Sales reps need to quickly log meeting notes and link to related opportunities.

**File:** `force-app/main/default/objects/Account/quickActions/Log_Meeting.quickAction-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<QuickAction xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Log Meeting</label>
    <optionsCreateFeedItem>true</optionsCreateFeedItem>
    <targetObject>Account</targetObject>
    <type>Flow</type>
    <flowDefinition>Log_Meeting_QuickAction</flowDefinition>
</QuickAction>
```

**Supporting flow:** `Log_Meeting_QuickAction` (screen flow)
- Input: Account ID (auto-passed from record page)
- Screens: Meeting date, attendees, notes, related opportunity
- Creates: Meeting_Note__c record linked to Account

**Deployment:**
1. Deploy flow first
2. Deploy quick action
3. Wire to Account_Record_Page flexipage

### Example 2: Case Escalation (Field Update)

**Business need:** Support agents need quick way to escalate cases to Tier 2 with proper status/priority.

**File:** `force-app/main/default/objects/Case/quickActions/Escalate_Tier2.quickAction-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<QuickAction xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Escalate to Tier 2</label>
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
            <quickActionLayoutItems>
                <field>Priority</field>
                <uiBehavior>Edit</uiBehavior>
            </quickActionLayoutItems>
        </quickActionLayoutColumns>
        <quickActionLayoutColumns>
            <quickActionLayoutItems>
                <field>Escalation_Reason__c</field>
                <uiBehavior>Required</uiBehavior>
            </quickActionLayoutItems>
            <quickActionLayoutItems>
                <field>Escalation_Notes__c</field>
                <uiBehavior>Edit</uiBehavior>
            </quickActionLayoutItems>
        </quickActionLayoutColumns>
    </quickActionLayout>
</QuickAction>
```

**Pre-populates:** Status = "Escalated", Priority = "High"  
**Agent fills:** Escalation reason (required), notes (optional)

### Example 3: Opportunity Renewal Check (LWC-Based)

**Business need:** Account managers need to review renewal health score and update stage in one action.

**File:** `force-app/main/default/objects/Opportunity/quickActions/Review_Renewal.quickAction-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<QuickAction xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Review Renewal</label>
    <optionsCreateFeedItem>false</optionsCreateFeedItem>
    <targetObject>Opportunity</targetObject>
    <type>LightningComponent</type>
    <lightningComponent>c:renewalHealthReview</lightningComponent>
</QuickAction>
```

**Supporting component:** `c:renewalHealthReview` (LWC)
- Displays: Usage data, support tickets, CSAT score
- Updates: Opportunity stage, renewal likelihood, notes

## Recipes

### Create a Flow-Based Quick Action

**Step 1:** Create the Screen Flow first (see `salesforce-flows` skill)

**Step 2:** Deploy the flow:
```bash
sf project deploy start --source-dir force-app/main/default/flows/My_Flow.flow-meta.xml --target-org sandbox-dev
```

**Step 3:** Create the QuickAction XML at:
`force-app/main/default/objects/Case/quickActions/My_Action.quickAction-meta.xml`

Use the Flow-Based template above.

**Step 4:** Deploy the quick action:
```bash
sf project deploy start --source-dir force-app/main/default/objects/Case/quickActions/My_Action.quickAction-meta.xml --target-org sandbox-dev
```

**Step 5:** Wire it to the flexipage (see `salesforce-lightning-pages` skill)

### Fix "Action Not Found" on Flexipage Deploy

**Symptom:** Flexipage deploy fails saying action `Case.MyAction` doesn't exist.

**Diagnosis checklist:**
1. Does the QuickAction XML have `<targetObject>Case</targetObject>`?
   - If NO: Add it, redeploy the action, then retry flexipage
2. Is the action deployed to the org?
   - Check: `sf project retrieve start --metadata "QuickAction:Case.MyAction" --target-org sandbox-dev`
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
sf project deploy start --manifest /tmp/destructive/package.xml --post-destructive-changes /tmp/destructive/destructiveChanges.xml --target-org sandbox-dev

# Now deploy as object-scoped
sf project deploy start --source-dir force-app/main/default/objects/Case/quickActions/MyAction.quickAction-meta.xml --target-org sandbox-dev
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
