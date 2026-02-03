---
name: salesforce-test-validation
description: Create test data in sandbox, build validation matrices, run end-to-end tests to verify features work before production
allowed-tools: [Bash, Read, Write, mcp__Salesforce_DX__*]
---

# Salesforce Test & Validation

## When to Use
- Creating test cases/data in sandbox after deploying new features
- Building a validation checklist for a feature
- Running Apex tests
- Verifying flows, quick actions, list views, and page layouts work correctly
- Preparing for production deployment sign-off

## Critical Knowledge

### Deployed ≠ Working
Salesforce will happily deploy metadata that doesn't actually work at runtime. You MUST validate:
- Flows fire correctly on the right triggers
- Quick actions appear and launch
- List views show the right records
- Formula fields calculate correctly
- Apex tests pass

### Test Data via Anonymous Apex
Create test records quickly using `sf apex run`:

```bash
sf apex run --file /tmp/create-test-data.apex --target-org <your-sandbox-alias>
```

Example test data script:
```apex
// Create test cases covering different states
List<Case> testCases = new List<Case>();

testCases.add(new Case(
    Subject = 'TEST: New case needs attention',
    Status = 'New',
    Origin = 'Web'
));

testCases.add(new Case(
    Subject = 'TEST: Waiting on customer',
    Status = 'In Progress',
    Waiting_On__c = 'Customer',
    Origin = 'Web'
));

testCases.add(new Case(
    Subject = 'TEST: Solution proposed',
    Status = 'Solution Proposed',
    Waiting_On__c = 'Customer',
    Origin = 'Web'
));

testCases.add(new Case(
    Subject = 'TEST: Closed case',
    Status = 'Closed',
    Origin = 'Web'
));

insert testCases;

// Output case numbers for reference
for (Case c : [SELECT CaseNumber, Subject, Status, Waiting_On__c FROM Case WHERE Subject LIKE 'TEST:%' ORDER BY CaseNumber DESC LIMIT 10]) {
    System.debug('Created: ' + c.CaseNumber + ' | ' + c.Subject + ' | Status=' + c.Status + ' | WaitingOn=' + c.Waiting_On__c);
}
```

### Cleanup Test Data
Always clean up after validation:
```apex
// Delete test cases
List<Case> toDelete = [SELECT Id FROM Case WHERE Subject LIKE 'TEST:%'];
delete toDelete;
System.debug('Deleted ' + toDelete.size() + ' test cases');
```

## Recipes

### Build a Validation Matrix
After deploying a feature, create a validation checklist. For each scenario:

| # | Scenario | Steps | Expected Result | Pass? |
|---|----------|-------|-----------------|-------|
| 1 | New case appears in Needs Attention | Create case with no Waiting_On | Shows in "Needs Attention" list view | |
| 2 | Setting Waiting On removes from Needs Attention | Edit case, set Waiting_On = Customer | Disappears from "Needs Attention", appears in "Waiting On" | |
| 3 | Quick action launches | Open case → click "Propose Solution" | Screen flow opens | |
| 4 | Quick action updates record | Submit the flow | Status = "Solution Proposed", Waiting_On = "Customer" | |
| 5 | Closed case not in active views | Close a test case | Not in "Needs Attention" or "Waiting On" | |

### Validate List Views
```bash
# Query what a list view SHOULD show
sf data query --query "SELECT CaseNumber, Subject, Status, Waiting_On__c, Owner.Name FROM Case WHERE Needs_Attention__c = true AND OwnerId = '005...' ORDER BY CreatedDate DESC LIMIT 20" --target-org <your-sandbox-alias>
```

Compare query results against what appears in the UI list view.

### Validate Record-Triggered Flows
1. **Create a test record** that should trigger the flow
2. **Update the record** to match trigger criteria
3. **Re-query the record** to verify the flow's changes took effect:
```bash
sf data query --query "SELECT Id, Status, Waiting_On__c FROM Case WHERE CaseNumber = '00048522'" --target-org <your-sandbox-alias>
```

### Validate Quick Actions Exist on Page
1. Navigate to a record page in sandbox
2. Check the action bar (highlights panel)
3. Click each new action to verify it launches
4. Submit and verify record updates

### Run Apex Tests
```bash
# Run specific test class
sf apex run test --class-names CaseLifecycleFlowTest --target-org <your-sandbox-alias> --result-format human

# Run all tests (slower)
sf apex run test --target-org <your-sandbox-alias> --result-format human

# Check code coverage
sf apex run test --class-names CaseLifecycleFlowTest --code-coverage --target-org <your-sandbox-alias>
```

### Validate Queue Assignments
```bash
# Find queue IDs
sf data query --query "SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Queue'" --target-org <your-sandbox-alias>

# Check cases owned by a queue
sf data query --query "SELECT CaseNumber, Subject, Owner.Name FROM Case WHERE Owner.Type = 'Queue' AND Status != 'Closed' ORDER BY CreatedDate DESC LIMIT 10" --target-org <your-sandbox-alias>
```

### Cross-Queue Escalation Test
Create test cases assigned to different queues, then verify:
1. Each queue's list view shows the right cases
2. Cases DON'T appear in individual user's "My Cases" views
3. Queue-owned cases DO appear in "Needs Attention" when unassigned

### Pre-Production Checklist
Before promoting to production:

- [ ] All Apex tests pass in sandbox
- [ ] Code coverage ≥ 75%
- [ ] All flows activated (not just deployed)
- [ ] Quick actions visible on record pages
- [ ] List views return expected results
- [ ] Formula fields calculate correctly
- [ ] Test data cleaned up
- [ ] No placeholder IDs in metadata
- [ ] Validation matrix fully passed
- [ ] User acceptance sign-off

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Test data has wrong Owner | Use `OwnerId` in Apex to assign to specific users/queues |
| Flow deployed but not activated | Check `<status>Active</status>` in flow XML |
| List view looks empty | Check filter criteria + your user's permissions/role |
| Apex test passes but flow doesn't fire | Test class may mock DML — verify with real records in sandbox |
| Formula returns wrong value | Query the field directly: `SELECT Needs_Attention__c FROM Case WHERE Id = '...'` |

## Edge Cases to Always Test
1. **Closed records** — should they appear? Usually no.
2. **Queue-owned records** — different behavior than user-owned
3. **Bulk operations** — does the flow handle 200+ records?
4. **Permission sets** — can the target user profile actually see/edit the fields?
5. **Existing data** — does the feature work on records created before it was deployed?
