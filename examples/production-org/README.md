# Production Org Examples

**From someone who got thrown into "you're the Salesforce person now" and had to figure it out.**

These aren't polished enterprise best practices. They're patterns I learned by breaking things in a 20-admin org where:
- Nobody told me about RecordTypes until I deployed a global quick action that didn't work
- I learned about drift detection after overwriting an admin's Flow changes
- Testing in production seemed fine until it wasn't
- "Just deploy it" turned into "why is everyone's page broken?"

These examples show what the skills look like after you've made the mistakes and built the guardrails.

## What's Different from Generic Skills

**Generic skills** tell you what to do. **These examples** show what you learn after doing it wrong.

You'll see:
- RecordTypes I didn't know existed (and what happened when I ignored them)
- The drift detection workflow I built after overwriting prod changes
- Custom objects that aren't in any documentation (because someone built them 3 years ago)
- Integration patterns reverse-engineered from "why is this webhook failing?"
- Wave deployment that evolved from "just deploy everything" to "please god never again"

**Use these** to see what patterns emerge when you're learning Salesforce through Claude + trial & error.

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
