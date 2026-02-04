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
WHERE RecordTypeId = :renewalRecordTypeId
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
    .get('Service_Case').getRecordTypeId();

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

---

## Org-Specific Context

> **What I discovered after 6 months of "wait, why didn't that work?"**

### RecordTypes in Use

**Took me way too long to learn:** RecordTypes aren't just cosmetic. If you don't filter by them in SOQL, you get weird data. If you create global quick actions instead of object-scoped, they don't show up on pages. If you ignore them in validation rules, things break in ways that make no sense.

**Here's what we actually have:**

- **Case:** Service_Case, Support_Case, Escalation_Case
- **Opportunity:** New_Business, Renewal, Upsell
- **Account:** Business_Account, Partner_Account
- **Lead:** Standard (no custom RecordTypes)

### Custom Objects

**The ones I had to reverse-engineer because they weren't documented anywhere:**

- **Meeting_Note__c** - Someone integrated a meeting tool 2 years ago. Webhook creates these. I only found out when it broke.
- **Escalation__c** - Built by a contractor who's long gone. Has SLA tracking that nobody understands but everyone depends on.
- **Integration_Log__c** - I built this after spending 3 hours debugging webhook failures with no audit trail.
- **Product_Config__c** - Used in quoting. Learned about it when a Flow reference threw an error.
- **Service_Metric__c** - CSAT/NPS scores. Updated by a scheduled job. Found it while hunting for "where does this number come from?"
- **Partner_Activity__c** - Business development built it. I maintain it. Classic.
- **Implementation_Task__c** - Onboarding checklist. Works great until someone adds a task and breaks the automation.
- **Usage_Data__c** - Analytics platform syncs here daily. Failure = 47 Slack messages asking why dashboards are stale.

> **Real talk:** Your org has objects like this too. No documentation. Critical to someone's workflow. You'll find them when Claude throws an error or someone asks "why isn't this working?"
>
> **Document them as you discover them.** Future you will thank past you.

### Integration Points

**Things that break at 3am and wake someone up:**

- **Meeting Intelligence Platform** → Salesforce (webhook)
  - Creates Meeting_Note__c records when meetings end
  - Supposed to link to Opportunities automatically (sometimes doesn't, haven't figured out why)
  - Updates engagement scores (which feed into renewal predictions, so when it breaks, Sales gets nervous)
  - **Lesson learned:** Always log incoming webhooks. You'll need the data when debugging.

- **Analytics Platform** → Salesforce (daily sync)
  - Syncs Usage_Data__c every morning at 6am
  - If sync fails, renewal workflows don't trigger, dashboards go stale, everyone panics
  - **Lesson learned:** Build monitoring. Don't find out from users that data is 3 days old.

- **Support Ticketing System** ↔ Salesforce (bidirectional nightmare)
  - Creates Cases from tickets (works 95% of the time)
  - Syncs status updates (the other 5% creates duplicate cases)
  - Escalation routing depends on both systems agreeing on priority (they don't always)
  - **Lesson learned:** Bidirectional sync = eventual consistency = "why is this case showing two different statuses?"

- **Customer Portal** → Salesforce (Experience Cloud)
  - Self-service case creation (users love it when it works, hate it when it's down)
  - Knowledge base integration (search is... not great)
  - Usage dashboard (pulls from that Usage_Data__c that breaks every few weeks)
  - **Lesson learned:** Portal downtime = support ticket flood. Have a "portal is down" auto-response ready.

## Project References

> **Example project structure for Claude Code**

- **Project goals:** `.claude/GOALS.md` - 2026 roadmap, Service Cloud Phase 1-3
- **Org learnings:** `.claude/LEARNINGS.md` - Discoveries about custom objects, integrations, gotchas
- **Architectural decisions:** `.claude/DECISIONS.md` - Why we chose certain patterns (LWC over Aura, Flow vs Apex)
- **Safety rules:** `SAFETY-RULES.md` - Production deployment gates, testing requirements
- **Instructions:** `.claude/instructions.md` - Session-level instructions for Claude Code

> **Tip:** If you're not using project docs yet, you can remove this section. But maintaining these files dramatically improves Claude's context across sessions.

## Remember

- When in doubt, check metadata files in `force-app/`
- Query production for data questions (read-only via `sandbox-prod` alias)
- Develop in sandbox (write access via `sandbox-dev` or `sandbox-uat`)
- Test with bulk data (governor limits)
- Validate security at every layer
