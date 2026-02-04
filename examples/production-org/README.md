# Production Org Examples

**What these skills look like when applied to a real org.**

These examples show patterns you'll develop once you start using the skills in a multi-admin production environment. The scenarios are representative of what happens when:
- You deploy without checking for drift and overwrite someone else's work
- You create quick actions that don't appear because they're scoped wrong
- Integrations break at 3am and you have no audit trail
- "Just deploy it" turns into incident response

Use these to see what the skills help you avoid and what patterns emerge after you've learned the hard way.

## What's Different from Generic Skills

**Generic skills** provide templates. **These examples** show what they look like when customized for an actual org.

You'll see:
- RecordTypes documented with context about why they matter (not just "here's a list")
- Custom objects with notes about how you discovered them (undocumented, found when errors happened)
- Integration patterns that include failure modes ("this breaks when...")
- Deployment workflows evolved from mistakes ("drift detection exists because...")
- Real-world complexity: 20 admins, multiple business units, production data

**Use these** as a reference for what your skills will look like after you've used them for a while.

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
