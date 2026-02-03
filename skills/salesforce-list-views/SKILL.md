---
name: salesforce-list-views
description: Create and modify list views — column references, filter logic, queue-based views
allowed-tools: [Bash, Read, Write, Edit, mcp__Salesforce_DX__*]
---

# Salesforce List Views

## When to Use
- Creating new list views for an object
- Adding/removing columns from list views
- Setting up queue-specific list views
- Fixing column reference errors

## Critical Knowledge

### Column API Names Are NOT Always Obvious
List view columns use a special naming convention that differs from field API names.

**Common Case columns:**
| Display Name | Column API Name | Notes |
|-------------|----------------|-------|
| Case Number | CASES.CASE_NUMBER | |
| Subject | CASES.SUBJECT | |
| Status | CASES.STATUS | |
| Priority | CASES.PRIORITY | |
| Owner | CORE.USERS.ALIAS | Owner alias |
| Owner (Full Name) | OWNER.ALIAS | Alternative |
| Created Date | CASES.CREATED_DATE | |
| Date/Time Opened | CASES.CREATED_DATE_DATE_ONLY | |
| Case Origin | CASES.ORIGIN | |
| Account Name | ACCOUNT.NAME | Via Account lookup |
| Contact Name | NAME | ⚠️ NOT `CASES.CONTACT` |

**Custom fields:** Use the API name directly: `Waiting_On__c`, `Needs_Attention__c`

⚠️ **Some standard fields DON'T work as list view columns.** If deploy fails with a column reference, remove it and try an alternative.

### List View XML Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ListView xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Needs_Attention</fullName>
    <label>Needs Attention</label>
    <filterScope>Mine</filterScope>
    <columns>CASES.CASE_NUMBER</columns>
    <columns>CASES.SUBJECT</columns>
    <columns>CASES.STATUS</columns>
    <columns>Waiting_On__c</columns>
    <columns>CORE.USERS.ALIAS</columns>
    <columns>CASES.CREATED_DATE</columns>
    <filters>
        <field>Needs_Attention__c</field>
        <operation>equals</operation>
        <value>1</value>
    </filters>
    <filters>
        <field>CASES.STATUS</field>
        <operation>notEqual</operation>
        <value>Closed,Merged</value>
    </filters>
</ListView>
```

**File location:** `force-app/main/default/objects/Case/listViews/Needs_Attention.listView-meta.xml`

### Filter Scope Options
| `<filterScope>` | Meaning |
|-----------------|---------|
| `Mine` | Records owned by current user |
| `Queue` | Records owned by a specific queue |
| `Everything` | All records visible to user |
| `MineAndMyGroups` | User's records + their queue records |

### Queue-Specific List View
```xml
<ListView xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Queue_Customer_Support</fullName>
    <label>Queue: Customer Support</label>
    <filterScope>Queue</filterScope>
    <queue>Customer_Support</queue>
    <columns>CASES.CASE_NUMBER</columns>
    <columns>CASES.SUBJECT</columns>
    <columns>CASES.STATUS</columns>
    <columns>CORE.USERS.ALIAS</columns>
    <columns>CASES.CREATED_DATE</columns>
    <filters>
        <field>CASES.STATUS</field>
        <operation>notEqual</operation>
        <value>Closed,Merged</value>
    </filters>
</ListView>
```

**Key:** `<queue>` uses the Queue's **DeveloperName**, not the display label.

Find queue developer names:
```bash
sf data query --query "SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Queue'" --target-org sandbox
```

## Recipes

### Create a List View
1. Write the XML file to `force-app/main/default/objects/<Object>/listViews/<Name>.listView-meta.xml`
2. Deploy:
   ```bash
   sf project deploy start --source-dir force-app/main/default/objects/Case/listViews/Needs_Attention.listView-meta.xml --target-org sandbox
   ```

### Add a Column to Existing List View
1. Retrieve it:
   ```bash
   sf project retrieve start --metadata "ListView:Case.Needs_Attention" --target-org sandbox
   ```
2. Add a `<columns>` element (order = display order)
3. Redeploy

### Validate List View Shows Correct Data
```bash
# Replicate the filter logic in SOQL
sf data query --query "SELECT CaseNumber, Subject, Status, Owner.Name FROM Case WHERE Needs_Attention__c = true AND OwnerId = '<userId>' ORDER BY CreatedDate DESC" --target-org sandbox
```

Compare the SOQL results with what appears in the list view UI.

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Column "not found" on deploy | Check the column API names table above; some standard fields have non-obvious names |
| `CASES.CONTACT` doesn't work | Use `NAME` for Contact Name |
| Queue list view is empty | Check `<queue>` uses DeveloperName not label; verify queue exists |
| Filter not working | Boolean fields use `1`/`0` not `true`/`false` |
| Custom field not showing | Use API name directly: `My_Field__c` (no prefix) |
