---
name: salesforce-patterns
description: Salesforce development patterns and validation rules. LWC best practices, SOQL optimization, security, and org-specific patterns.
---

# Salesforce Patterns

## Overview

Validation rules and best practices for Salesforce development.

**When to use:** Automatically loaded by brainstorming and writing-plans when configured.

**Purpose:** Ensure designs follow Salesforce best practices and org-specific patterns.

## Lightning Web Components (LWC)

### Component Structure
- **Naming:** camelCase for properties/methods, PascalCase for component names
- **File organization:** Keep components small (<300 lines)
- **Reusability:** Extract common patterns to utility modules

### Data Access Patterns
```javascript
// ✅ GOOD: Wire decorator for org data
@wire(getRecord, { recordId: '$recordId', fields: FIELDS })
record;

// ✅ GOOD: Imperative with error handling
getOpportunities()
  .then(result => this.opportunities = result)
  .catch(error => this.handleError(error));

// ❌ BAD: No error handling
getOpportunities().then(result => this.opportunities = result);
```

### Error Handling
- Always implement error handling for Apex calls
- Show user-friendly error messages
- Log errors for debugging
- Use `reduceErrors` utility from `c/ldsUtils`

### LWC Lifecycle Patterns
```javascript
// ✅ GOOD: Proper lifecycle usage
connectedCallback() {
    this.loadData();
}

disconnectedCallback() {
    this.cleanup();
}

// ❌ BAD: Heavy work in constructor
constructor() {
    super();
    this.loadData(); // Don't do this
}
```

## SOQL Best Practices

### Query Optimization
```sql
-- ✅ GOOD: Selective filters, explicit fields
SELECT Id, Name, StageName, Amount, OwnerId
FROM Opportunity
WHERE RecordTypeId = :serviceRecordTypeId
  AND StageName IN ('Qualification', 'Proposal')
  AND CreatedDate = LAST_N_DAYS:30
LIMIT 200

-- ❌ BAD: SELECT *, no filters, no limit
SELECT * FROM Opportunity
```

### Security
- **Always use:** `WITH SECURITY_ENFORCED` in SOQL
- **Field-level security:** Check with `Schema.sObjectType.Object__c.fields.Field__c.isAccessible()`
- **Sharing rules:** Understand when to use `with sharing` vs `without sharing`

### RecordType Filtering
```apex
// ✅ GOOD: Filter by RecordType when applicable
Id serviceRT = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
    .get('Service_Cloud_Case').getRecordTypeId();

[SELECT Id FROM Case WHERE RecordTypeId = :serviceRT WITH SECURITY_ENFORCED]

// ❌ BAD: No RecordType filter when multiple RecordTypes exist
[SELECT Id FROM Case]
```

### Governor Limits
- Keep queries < 50,000 records
- Bulkify: Don't query inside loops
- Use selective filters to reduce query size
- Consider pagination for large datasets

### SOQL Gotchas

1. **Not all sObjects are queryable.** `WorkflowAlert`, `ObjectTerritory2Association`, and many setup objects cannot be queried via standard SOQL. Use the Tooling API (`/services/data/vXX.0/tooling/query`) for metadata objects instead.

2. **Verify field names before using them.** Don't guess field API names — they vary by org. Run `DESCRIBE` or query `FieldDefinition` first if unsure. Common mistakes: `DefaultLeadOwnerId` (doesn't exist on Organization), `FolderId` (doesn't exist on Report), `Error_Message__c` vs the actual field name.

3. **Parallel SOQL calls cascade on failure.** If you fire multiple SOQL queries in parallel and one fails, all sibling calls get cancelled. Run critical queries sequentially or handle cancellation gracefully.

## Apex Best Practices

### Trigger Patterns
- One trigger per object
- Delegate to handler classes
- Keep trigger logic minimal
- Test with bulk data (200+ records)

### Bulkification
```apex
// ✅ GOOD: Bulkified
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
);

// ❌ BAD: Query in loop
for (Id accId : accountIds) {
    Account acc = [SELECT Id, Name FROM Account WHERE Id = :accId];
}
```

## Service Cloud Patterns

### Case Management
- Use `Case.Status` for workflow stages
- Implement proper escalation rules
- Track SLA metrics via Entitlements
- Use Case Comments for internal notes, Email Messages for external

### Service Console
- Design for console layout (tabs, utilities)
- Use lightning:workspaceAPI for navigation
- Consider screen real estate in console context

### Omni-Channel
- Route cases based on skills/availability
- Configure presence statuses appropriately
- Monitor queue metrics

## Sales Cloud Patterns

### Opportunity Management
- Use proper Stage progression (no skipping stages)
- Implement validation rules for required fields per stage
- Track Close Date realistically
- Use Products/Price Books when applicable

### Lead Conversion
- Map custom fields properly
- Handle duplicate detection
- Assign ownership rules
- Track conversion metrics

## Validation Checklist

Use this during brainstorming/planning:

### LWC Components
- [ ] Component name is PascalCase?
- [ ] Properties/methods are camelCase?
- [ ] Wire decorators used for org data?
- [ ] Error handling implemented?
- [ ] Lifecycle methods used appropriately?
- [ ] Component size < 300 lines?

### Apex Classes
- [ ] WITH SECURITY_ENFORCED in SOQL?
- [ ] RecordType filtered when applicable?
- [ ] Bulkified (no queries in loops)?
- [ ] Proper exception handling?
- [ ] Test class with 200+ records?
- [ ] Governor limits considered?

### SOQL Queries
- [ ] Explicit field list (no SELECT *)?
- [ ] Selective filters applied?
- [ ] LIMIT clause used?
- [ ] WITH SECURITY_ENFORCED?
- [ ] RecordType filtered when multiple exist?

### Deployment
- [ ] Tested in sandbox first?
- [ ] Test coverage > 75%?
- [ ] User permissions validated?
- [ ] Field-level security checked?

## Org-Specific Context

**🔧 CUSTOMIZE THIS SECTION FOR YOUR ORG**

### RecordTypes in Use
```markdown
<!-- Example:
- **Case:** Service_Cloud_Case, Sales_Cloud_Case
- **Opportunity:** New_Business, Renewal, Upsell
- **Account:** Standard
-->

- **Object:** RecordType_Developer_Names_Here
```

### Custom Objects
```markdown
<!-- List your custom objects and their purpose:
- CustomObject__c - Description of what it tracks
- AnotherCustom__c - Its business purpose
-->

- Your custom objects here
- Reference metadata files in force-app/main/default/objects/
```

### Integration Points
```markdown
<!-- Document external systems:
- ExternalSystem → Salesforce (via API/webhook)
- Salesforce → ExternalSystem (via Platform Events/Apex callouts)
-->

- Document your org's integrations here
- Third-party apps connected to Salesforce
- API consumers and webhooks
```

## Project References

**🔧 CUSTOMIZE THESE PATHS** (or remove if not using project docs)

```markdown
<!-- Recommended project structure for Claude Code:
.claude/
  GOALS.md          - Project goals and success criteria
  LEARNINGS.md      - Discoveries about the org (custom objects, integrations)
  DECISIONS.md      - Architectural decisions and why
  instructions.md   - Session-level instructions
SAFETY-RULES.md     - Deployment safety rules
-->

- Project goals: `.claude/GOALS.md`
- Org learnings: `.claude/LEARNINGS.md`
- Architectural decisions: `.claude/DECISIONS.md`
- Safety rules: `SAFETY-RULES.md`
- Instructions: `.claude/instructions.md`
```

## Remember

- When in doubt, check metadata files in `force-app/`
- Query production for data questions (read-only)
- Develop in sandbox (write access)
- Test with bulk data (governor limits)
- Validate security at every layer

---

## SOQL Gotchas

### Polymorphic Lookups (Owner, WhoId, WhatId, ParentId)

`Owner` on Case (and Lead, Account, Contract, etc.) is polymorphic — it can be a User OR a Queue. **`Owner.Name` does NOT work.** Use the typed dot syntax:

```sql
-- ❌ FAILS: INVALID_FIELD: No such column 'Owner.Name'
SELECT Id, Owner.Name FROM Case

-- ✅ WORKS: typed access
SELECT Id, Owner.Type, Owner:User.Name, Owner:Group.Name FROM Case

-- ✅ Or use TYPEOF for branched fields
SELECT Id,
  TYPEOF Owner
    WHEN User THEN Name, Email
    WHEN Group THEN Name
  END
FROM Case
```

Common polymorphic fields: `Case.Owner`, `Lead.Owner`, `Account.Owner`, `Task.WhoId`, `Task.WhatId`, `EmailMessage.RelatedToId`.

### Preflight `sf sobject describe` Before Querying Unfamiliar Objects

For system/setup objects (EnhancedLetterhead, LayoutLight, PermissionSetGroup, FlowDefinition, etc.) **describe first — don't guess fields**. Multiple INVALID_FIELD trial-and-error cycles per session is wasted time.

```bash
# Cheap describe — lists all queryable fields with types
sf sobject describe --sobject EnhancedLetterhead --target-org sandbox --json | jq '.fields[] | {name, type, queryable: .filterable}' | head -50

# For tooling-only objects (Layout, Flow, etc.), use --use-tooling-api
sf sobject describe --sobject LayoutLight --target-org sandbox --use-tooling-api --json | jq '.fields[].name'
```

**Known field-name traps:**
| Object | Wrong | Right |
|---|---|---|
| EnhancedLetterhead | `DeveloperName`, `IsActive` | `Name` (no DeveloperName field) |
| LayoutLight | `TableEnumOrId` | use `Layout` (full sobject) instead |
| Layout | (queryable) | Tooling API only — needs `--use-tooling-api` |
| Case | `Owner.Name` | `Owner:User.Name` (polymorphic) |
| Incident (Casechek) | `Jira_Link__c` (sandbox-only) | `Jira_Ticket_Link__c` (prod) — verify per-org |
