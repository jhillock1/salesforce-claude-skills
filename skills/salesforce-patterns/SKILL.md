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

### RecordTypes in Use
- **Case:** Service_Cloud_Case, Sales_Cloud_Case
- **Opportunity:** Standard (no custom RecordTypes currently)
- **Account:** Standard

### Custom Objects
- Check LEARNINGS.md for discovered custom objects
- Reference metadata files in force-app/main/default/objects/

### Integration Points
- Document your org's integrations here
- Third-party apps connected to Salesforce
- API consumers and webhooks

## References

- Project goals: `.claude/GOALS.md`
- Org learnings: `.claude/LEARNINGS.md`
- Architectural decisions: `.claude/DECISIONS.md`
- Safety rules: `SAFETY-RULES.md`
- Instructions: `.claude/instructions.md`

## Remember

- When in doubt, check metadata files in `force-app/`
- Query production for data questions (read-only)
- Develop in sandbox (write access)
- Test with bulk data (governor limits)
- Validate security at every layer
