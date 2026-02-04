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

> **Example: What you'll discover as you use these skills**

### RecordTypes in Use

**Why this matters:** RecordTypes aren't just cosmetic. If you don't filter by them in SOQL, you get unexpected data. If you create global quick actions instead of object-scoped, they won't appear on pages. If you ignore them in validation rules, things break in non-obvious ways.

**Example from a production org:**

- **Case:** Service_Case, Support_Case, Escalation_Case
- **Opportunity:** New_Business, Renewal, Upsell
- **Account:** Business_Account, Partner_Account
- **Lead:** Standard (no custom RecordTypes)

### Custom Objects

**Example: What you'll find in a production org (and how you typically discover them):**

- **Meeting_Note__c** - Webhook integration creates these. You'll discover it when the integration breaks or when building a report.
- **Escalation__c** - Built by someone no longer at the company. Has SLA tracking. You'll find it when flows reference it or users ask about it.
- **Integration_Log__c** - Audit trail for webhooks/APIs. Often built after debugging integration failures with no visibility.
- **Product_Config__c** - Complex product configuration data. You'll encounter it when flows or pricing logic references it.
- **Service_Metric__c** - CSAT/NPS scores synced from surveys. You'll find it when building dashboards or investigating data sources.
- **Partner_Activity__c** - Partner engagement tracking. You'll discover it when asked to report on partner relationships.
- **Implementation_Task__c** - Onboarding checklist automation. You'll learn about it when someone says "new customer onboarding is broken."
- **Usage_Data__c** - Product usage metrics from external system. You'll find it when the sync fails and dashboards go stale.

> **Common pattern:** Custom objects often lack documentation. You discover them through:
> - Error messages (flow/validation rule references)
> - User questions ("where does this data come from?")
> - Integration failures (webhooks creating records)
> - Reporting requests ("can you show me X?")
>
> **Document them as you find them.** Include how they're populated, what uses them, and who owns them.

### Integration Points

**Example: Typical integration patterns and what to watch for**

- **Meeting Intelligence Platform** → Salesforce (webhook)
  - Creates Meeting_Note__c records when meetings end
  - Links to Opportunities/Contacts (when mapping works correctly)
  - Updates engagement scores (which may feed into other automation)
  - **Watch for:** Webhook failures, authentication expiry, field mapping errors
  - **Best practice:** Log all incoming webhooks for debugging

- **Analytics Platform** → Salesforce (scheduled sync)
  - Syncs Usage_Data__c on a schedule (daily/hourly)
  - Feeds dashboards, triggers workflows based on thresholds
  - **Watch for:** Sync failures causing stale data, API rate limits, schema changes
  - **Best practice:** Build monitoring/alerts. Users shouldn't discover stale data before you do.

- **Support Ticketing System** ↔ Salesforce (bidirectional sync)
  - Creates Cases from external tickets
  - Syncs status updates between systems
  - **Watch for:** Duplicate record creation, status conflicts, field mapping drift
  - **Common issue:** Bidirectional sync = eventual consistency. Systems may temporarily disagree on state.
  - **Best practice:** Idempotent webhooks, unique external IDs, clear conflict resolution rules

- **Customer Portal** → Salesforce (Experience Cloud)
  - Self-service case creation, knowledge base search, dashboards
  - **Watch for:** Portal authentication issues, slow search performance, broken dashboard widgets
  - **Common issue:** Portal downtime = support ticket flood
  - **Best practice:** Status page, fallback workflows, "portal is down" messaging

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
