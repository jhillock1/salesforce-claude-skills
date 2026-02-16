---
name: salesforce-flows
description: Flow development patterns — XML structure, side-effect awareness, competing flows, entry conditions, and debugging
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep, mcp__Salesforce_DX__*]
---

# Salesforce Flow Development

## When to Use
- Creating screen flows, record-triggered flows, or auto-launched flows
- Modifying existing flow XML
- Fixing flow deployment errors (especially element ordering)
- Wiring flows to quick actions
- Debugging unexpected behavior after DML operations
- When a data change "doesn't stick" or reverts unexpectedly

## Flow XML Structure (STRICT Element Ordering)

This is the #1 cause of cryptic deploy errors. Flow XML requires elements of the same type to be **contiguous** (grouped together). You cannot interleave different element types.

```xml
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>64.0</apiVersion>
    <label>My Flow</label>
    <processType>Flow</processType>
    <status>Draft</status>

    <!-- 1. Variables (ALL together) -->
    <variables>...</variables>
    <variables>...</variables>

    <!-- 2. Formulas (ALL together) -->
    <formulas>...</formulas>

    <!-- 3. Screens (ALL together) -->
    <screens>...</screens>

    <!-- 4. Decisions (ALL together) -->
    <decisions>...</decisions>

    <!-- 5. Record operations (ALL together by type) -->
    <recordLookups>...</recordLookups>
    <recordUpdates>...</recordUpdates>
    <recordCreates>...</recordCreates>

    <!-- 6. Assignments (ALL together) -->
    <assignments>...</assignments>

    <!-- 7. Start element -->
    <start>...</start>
</Flow>
```

"Element X is duplicated" error = same element type in two non-contiguous locations. Group them.

### Flow Types
| Type | `<processType>` | Trigger | Use Case |
|------|-----------------|---------|----------|
| Screen Flow | `Flow` | Manual launch | Quick actions, guided UX |
| Record-Triggered | `AutoLaunchedFlow` | `<recordTriggerType>` in `<start>` | Auto-fire on record change |
| Auto-Launched | `AutoLaunchedFlow` | Called by other flows | Utility/helper flows |
| Scheduled | `AutoLaunchedFlow` | `<scheduledPaths>` in `<start>` | Batch/timed operations |

### Resolve Placeholder IDs Before Deploy
Flows referencing Queue or Record Type IDs from sandbox will break in prod. Always resolve:
```bash
sf data query --query "SELECT Id, DeveloperName FROM Group WHERE Type='Queue'" --target-org <target>
sf data query --query "SELECT Id, DeveloperName FROM RecordType WHERE SObjectType='Case'" --target-org <target>
```

---

## Core Principle: Side-Effect Awareness

Casechek has **149+ flows**. Multiple record-triggered flows fire on the same DML operation. Before building or modifying any flow, you MUST understand what else fires.

---

## Before Writing Any Flow

### 1. Inventory Competing Flows

```bash
# Find ALL flows that trigger on the same object + event
grep -rl "<object>Case</object>" force-app/main/default/flows/ | xargs grep -l "<triggerType>RecordAfterSave</triggerType>"
grep -rl "<object>Case</object>" force-app/main/default/flows/ | xargs grep -l "<triggerType>RecordBeforeSave</triggerType>"

# For EmailMessage triggers (high-risk — 6+ active flows)
grep -rl "<object>EmailMessage</object>" force-app/main/default/flows/ | xargs grep -l "<triggerType>RecordAfterSave</triggerType>"
```

### 2. Check for Managed Package Triggers

```bash
# Talkdesk managed-package CaseTrigger overrides Status to 'New' when reopening
# Can't modify (managed pkg) — must design flows around this behavior
grep -rl "CaseTrigger" force-app/main/default/triggers/ 2>/dev/null
```

**Known managed package behaviors:**
- **Talkdesk CaseTrigger**: Overrides Status to 'New' when a Closed case is reopened. Tests should verify functional requirements (IsClosed=false, Reopen_Count) rather than exact Status value.

### 3. Map the Cascade Chain

When Flow A updates a Case field, that triggers all before-save and after-save flows on Case again. This creates cascading save cycles:

```
EmailMessage inserted
  → 6 EmailMessage after-save flows fire
    → Each may DML-update parent Case
      → All Case before/after-save flows re-fire
        → Which may update Case again...
```

**Guard every flow with entry conditions that prevent unnecessary re-firing.**

---

## Entry Condition Best Practices

### Always Use `IsChanged` When Possible

Without `IsChanged`, a flow fires on EVERY update to the record — even updates to unrelated fields. This causes:
- Performance problems (governor limit hits)
- Data stomping (flow overwrites manual changes)
- Infinite loops (flow A triggers flow B triggers flow A)

```xml
<!-- GOOD: Only fire when Status changes -->
<conditions>
    <leftValueReference>$Record.Status</leftValueReference>
    <operator>IsChanged</operator>
    <rightValue><booleanValue>true</booleanValue></rightValue>
</conditions>

<!-- BAD: Fires on every Case update -->
<conditions>
    <leftValueReference>$Record.Status</leftValueReference>
    <operator>EqualTo</operator>
    <rightValue><stringValue>Closed</stringValue></rightValue>
</conditions>
```

### Guard Flows to Skip Irrelevant Cases

```xml
<!-- Skip Closed and Service Project cases when specialized flows handle them -->
<conditions>
    <leftValueReference>$Record.IsClosed</leftValueReference>
    <operator>EqualTo</operator>
    <rightValue><booleanValue>false</booleanValue></rightValue>
</conditions>
<conditions>
    <leftValueReference>$Record.RecordType.DeveloperName</leftValueReference>
    <operator>NotEqualTo</operator>
    <rightValue><stringValue>Service_Project</stringValue></rightValue>
</conditions>
```

---

## Debugging Flow Behavior

### When a Data Change "Doesn't Stick"

1. **Check for competing flows** — another flow may be overriding your change in a later save cycle
2. **Check for managed package triggers** — Talkdesk CaseTrigger overrides Status on reopen
3. **Check assignment rules** — Case assignment rules can override Owner changes
4. **Check entry conditions** — your flow may not be firing (or firing when it shouldn't)

### Debugging Checklist

```bash
# 1. Is the flow active? (ActiveVersionId == LatestVersionId)
sf data query --query "SELECT DurableId, ActiveVersionId, LatestVersionId, ApiName FROM FlowDefinition WHERE ApiName='Your_Flow'" --target-org sandbox --tooling-api --json

# 2. Did the flow fire? Check flow interviews
sf data query --query "SELECT Id, InterviewLabel, CurrentElement, InterviewStatus, CreatedDate FROM FlowInterview WHERE FlowDeveloperName='Your_Flow' ORDER BY CreatedDate DESC LIMIT 5" --target-org sandbox --json

# 3. Did it error?
sf data query --query "SELECT Id, InterviewLabel, CurrentElement, InterviewStatus FROM FlowInterview WHERE FlowDeveloperName='Your_Flow' AND InterviewStatus='Error' ORDER BY CreatedDate DESC LIMIT 5" --target-org sandbox --json
```

### When Multiple Flows Conflict

If two flows both update the same field on the same trigger event, the last one to execute "wins." Flow execution order is **not guaranteed** by Salesforce.

**Resolution patterns:**
1. **Merge into one flow** — combine the logic so there's no race condition
2. **Use before-save for one, after-save for the other** — before-save runs first, deterministically
3. **Guard with entry conditions** — ensure only one flow's conditions are true for any given scenario

---

## EmailMessage Flow Patterns (High Risk)

EmailMessage triggers are the most dangerous in this org. 6+ active flows fire on EmailMessage Create, each potentially DML-updating the parent Case.

### Rules for EmailMessage Flows

1. **Always guard with Case status/type checks** — skip Closed cases, skip Service Project cases
2. **Never assume you're the only flow updating the parent Case** — query Case state, don't assume it's what you set
3. **EmailMessage.ParentId is read-only after insert** — you cannot reparent emails in after-save flows
4. **Use `$Record.Incoming` to distinguish inbound vs outbound** — many flows should only fire on one direction

### Known Active EmailMessage Flows (as of Feb 2026)
- Case_Waiting_On_From_Email
- Case_Reopen_Handler
- Case_Post_Close_New_Case_Creator
- Case_Received_Acknowledgment
- (Legacy: EmailMessage_Record_Triggered_Flow_Create — deactivated in sandbox, must deactivate in prod)

---

## Flow Testing in Apex

Always wrap flow-triggering DML in `Test.startTest()` / `Test.stopTest()`:

```apex
@IsTest
static void testFlowBehavior() {
    Case testCase = new Case(Subject = 'Test', Status = 'In Progress');
    insert testCase;

    Test.startTest();
    // This DML triggers the flow
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    // Query AFTER stopTest to see flow results
    Case result = [SELECT Status, Waiting_On__c FROM Case WHERE Id = :testCase.Id];
    System.assertEquals('Closed', result.Status);
}
```

**Can't insert Case as Closed** — Salesforce defaults new Case status. Use two-step DML:
```apex
Case c = new Case(Subject = 'Test', Status = 'In Progress');
insert c;
c.Status = 'Closed';
update c;
```
