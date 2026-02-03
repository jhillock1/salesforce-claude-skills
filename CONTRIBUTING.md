# Contributing

Thanks for considering contributing to salesforce-claude-skills! These skills exist because Salesforce development has too many footguns and Claude Code needs guardrails.

## What Makes a Good Contribution

**High value:**
- Common mistakes Claude makes (e.g., global vs object-scoped actions)
- Salesforce best practices that prevent runtime errors
- Governor limit patterns
- Security/sharing rule guidance

**Low value:**
- Opinionated style preferences
- Overly specific patterns that only apply to your org

## How to Contribute

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/salesforce-claude-skills.git
cd salesforce-claude-skills
```

### 2. Make Your Changes

**Adding a new skill:**
```bash
mkdir skills/salesforce-your-skill
touch skills/salesforce-your-skill/SKILL.md
```

Structure your SKILL.md:
```markdown
---
name: salesforce-your-skill
description: Brief one-line description
allowed-tools: [Bash, Read, Write, Edit, mcp__Salesforce_DX__*]
---

# Your Skill Name

## When to Use
Clear triggers for when this skill applies

## Critical Knowledge
The #1 thing Claude gets wrong

## Recipes
Step-by-step patterns with examples

## Common Pitfalls
Mistakes and how to fix them

## Validation
How to verify it worked (include validation script if applicable)
```

**Adding a validation script:**

If your skill catches a common mistake, add a bash script:

```bash
# Create script with the skill or in scripts/ for cross-cutting checks
touch skills/salesforce-your-skill/validate-your-thing.sh
chmod +x skills/salesforce-your-skill/validate-your-thing.sh
```

**Good validation script structure:**
```bash
#!/bin/bash
# Brief description of what it validates

# Usage check
if [ $# -eq 0 ]; then
    echo "Usage: $0 <arguments>"
    exit 1
fi

# Validate input exists
if [ ! -f "$1" ]; then
    echo "❌ ERROR: File not found: $1"
    exit 1
fi

# Run check
if [check passes]; then
    echo "✅ VALID: What's correct"
    exit 0
else
    echo "❌ INVALID: What's wrong"
    echo "Fix: How to fix it"
    exit 1
fi
```

Reference the script in your SKILL.md's Validation section.

**Updating an existing skill:**
- Add patterns you've learned from real sessions
- Include examples of correct vs incorrect approaches
- Link to Salesforce docs when relevant

### 3. Test Your Changes

Start a Claude Code session and test:
```bash
claude-code
```

Ask Claude to use your skill on a real problem. Does it help?

### 4. Submit a Pull Request

**Good PR description:**
```
## Problem
Claude kept creating triggers without bulkification, causing governor limit errors.

## Solution
Added "salesforce-trigger-patterns" skill with bulkification examples and checklist.

## Testing
Tested on 3 different trigger scenarios - Claude now bulkifies by default.
```

**Commit message format:**
```
[skill-name] Brief description

Longer explanation if needed.
```

## Skill Naming

Use `salesforce-` prefix:
- ✅ `salesforce-trigger-patterns`
- ✅ `salesforce-test-coverage`
- ❌ `triggers` (too generic)
- ❌ `my-org-triggers` (too specific)

## Sanitize Org-Specific Info

Before submitting:
- Remove custom object names (unless widely applicable)
- Generalize examples (use `Case`, `Account`, `Opportunity` when possible)
- Strip org URLs, usernames, API keys
- Replace "Acme Corp" with "your org" in descriptions

## Style Guide

**Tone:** Blunt, direct, useful
- ✅ "This is the #1 mistake. File location alone is NOT enough."
- ❌ "You might want to consider that sometimes people forget..."

**Examples:** Show both wrong and right
```markdown
// ❌ BAD: Query in loop
for (Id accId : accountIds) {
    Account acc = [SELECT Id FROM Account WHERE Id = :accId];
}

// ✅ GOOD: Bulkified
Map<Id, Account> accounts = new Map<Id, Account>(
    [SELECT Id FROM Account WHERE Id IN :accountIds]
);
```

**Structure:** Scannable
- Use tables for comparison
- Use checklists for validation
- Keep recipes step-by-step

## License

By contributing, you agree your contributions will be licensed under the MIT License.

---

## Questions or Issues?

- **Bug reports:** [Open an issue](https://github.com/jhillock/salesforce-claude-skills/issues)
- **Usage questions or discussions:** [GitHub Discussions](https://github.com/jhillock/salesforce-claude-skills/discussions)
- **Connect with others building AI tools for Salesforce:** [LinkedIn - John Hillock](https://www.linkedin.com/in/YOUR_LINKEDIN)

**Community contributions welcome!** These skills exist because people like you needed better tools.
