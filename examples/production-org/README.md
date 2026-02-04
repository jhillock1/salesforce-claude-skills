# Production Org Examples

**Real-world customizations from a 20-admin production org.**

These examples show how the generic skills look after configuration for an actual enterprise Salesforce org with:
- 2 Service Cloud business units
- Sales Cloud for renewals and new business
- Multiple sandbox environments (dev, UAT, staging)
- Third-party integrations (meeting notes, analytics)
- ~50 custom objects
- RecordTypes across Case, Opportunity, Account

## What's Different from Generic Skills

**Generic skills** (in `/skills`) have placeholders:
- `<your-sandbox-alias>` → replaced with actual org names
- `RecordTypes in Use` → populated with discovered RecordTypes
- `Custom Objects` → listed with business context
- Integration points → documented

**These examples** show what those sections look like after the `salesforce-install` skill runs.

## Using These Examples

**Option 1: Reference**
Use these as a guide when customizing your own skills. See how RecordTypes are documented, how integration points are described, etc.

**Option 2: Starting Point**
Copy these into your project and modify:
```bash
cp -r examples/production-org/salesforce-patterns ~/.claude/skills/
# Edit to match your org
```

**Option 3: Run Install Skill**
The `salesforce-install` skill will auto-populate most of this for you. These examples show what the output looks like.

## Privacy Note

All org-specific data has been anonymized:
- Company names removed
- Specific product names generalized
- Custom object names changed to generic equivalents
- Integration partners referenced generically

The **patterns and structures** are real. The **names and context** are sanitized.
