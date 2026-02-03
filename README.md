# Salesforce Claude Skills

**For everyone who got thrown into Salesforce admin/dev work and turned to AI for help.**

Claude Code is powerful. The Salesforce MCP gives it tools. But without guardrails, Claude makes expensive mistakes: global quick actions that won't deploy, SOQL queries without security enforcement, full-org deploys that fail on pre-existing errors.

These skills teach Claude the patterns you learned the hard way.

## What This Is

A **hybrid approach** combining:
- **Skills** (markdown docs) that teach Claude Code Salesforce patterns
- **Validation scripts** (bash/shell) that catch mistakes before deployment
- **Auto-configuration** that discovers your org setup and customizes everything

Built from 170+ real Claude Code sessions in a production org. Not by a consultant. By someone who needed it to work.

## What's Included

### Skills (`skills/`)

| Skill | Purpose | Validation Script |
|-------|---------|-------------------|
| **salesforce-install** ⭐ | **Run this first!** Auto-configure skills for your org | - |
| **salesforce-patterns** | LWC, SOQL, Apex best practices and validation rules | `check-soql-security.sh` |
| **salesforce-quick-actions** | Create flow-based and field update quick actions | `validate-quick-action.sh` ✓ |
| **salesforce-flows** | Build screen flows, autolaunched flows, and record-triggered flows | `validate-flow-xml.sh` |
| **salesforce-lightning-pages** | Wire components and actions to lightning pages | - |
| **salesforce-deploy** | Deployment patterns using `sf` CLI | - |
| **salesforce-prod-deploy** | Production deployment safety and validation | - |
| **salesforce-metadata-enrichment** | Query and enrich metadata from your org | - |
| **salesforce-list-views** | Create and manage list views | - |
| **salesforce-test-validation** | Test class patterns and validation | - |
| **salesforce-connect** | Connect to Salesforce orgs (sandbox/production) | - |

### Validation Scripts (`scripts/`)

- `check-soql-security.sh` - Find SOQL without `WITH SECURITY_ENFORCED`
- `validate-flow-xml.sh` - Validate flow XML structure
- `skills/salesforce-quick-actions/validate-quick-action.sh` - Check quick action scope

See `scripts/README.md` for details.

## Why These Skills Exist

**The Salesforce MCP provides tools but not guardrails.** Claude Code can deploy metadata but often:
- Creates global quick actions instead of object-scoped ones (flexipage deploy fails)
- Forgets `WITH SECURITY_ENFORCED` in SOQL (security violation)
- Does full-org deploys that fail on pre-existing errors
- Violates governor limits with queries in loops
- Gets XML element ordering wrong (deploy fails)

These skills fill the gaps between MCP capabilities and Salesforce best practices.

## Validation Scripts

Three scripts help catch common mistakes:

| Script | What It Checks | Run After |
|--------|---------------|-----------|
| `validate-quick-action.sh` | Ensures `<targetObject>` exists (not global) | Creating quick actions |
| `check-soql-security.sh` | Finds SOQL missing `WITH SECURITY_ENFORCED` | Writing Apex classes |
| `validate-flow-xml.sh` | Checks flow XML structure and common issues | Creating/editing flows |

**Usage:**
```bash
# Validate a quick action
bash skills/salesforce-quick-actions/validate-quick-action.sh \
  force-app/main/default/objects/Case/quickActions/MyAction.quickAction-meta.xml

# Check all Apex classes for SOQL security
bash scripts/check-soql-security.sh force-app/main/default/classes/

# Validate a flow
bash scripts/validate-flow-xml.sh force-app/main/default/flows/My_Flow.flow-meta.xml
```

## Installation

**Quick Start:**
```bash
# Clone to Claude's global skills directory
git clone https://github.com/jhillock/salesforce-claude-skills.git ~/.claude/skills/salesforce

# Start Claude Code in your Salesforce project
cd ~/your-salesforce-project
claude-code

# Run the install skill to auto-configure for your org
"Use the salesforce-install skill to configure these skills for my org"
```

Claude will discover your org aliases, RecordTypes, and custom objects, then auto-populate the customization sections.

**See [INSTALL.md](INSTALL.md) for detailed setup instructions.**

## Usage

**First time setup:**
```
Use the salesforce-install skill to configure these skills for my org
```

**After installation,** Claude Code will automatically reference these skills when:
- Creating quick actions → loads `salesforce-quick-actions`
- Writing SOQL queries → loads `salesforce-patterns`
- Deploying metadata → loads `salesforce-deploy`

You can also explicitly mention them:
```
Using the salesforce-quick-actions skill, create a flow-based quick action 
for the Case object that launches the "Propose Solution" screen flow.
```

## Customization

**The install skill handles most customization automatically.** It will:
- Discover your org aliases and update all skills
- Query RecordTypes and populate them in `salesforce-patterns`
- List custom objects for you to document

**Additional manual customizations:**

1. **Custom object descriptions:** Add business purpose for each custom object in `salesforce-patterns/SKILL.md`
2. **Integration points:** Document external systems connected to Salesforce
3. **Project structure:** Add paths to your `.claude/GOALS.md`, `LEARNINGS.md`, etc. (if using)

**To re-configure after org changes:**
```
Use the salesforce-install skill to reconfigure for my org
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on submitting improvements.

## License

MIT License - see [LICENSE](LICENSE)

## Author

**Built by someone who got thrown into a Salesforce admin role and had to figure it out.**

After 170+ Claude Code sessions (and way too many "why did that deploy fail?!" moments), these patterns emerged. Not a certified admin. Not a Salesforce consultant. Just someone who needed guardrails and built them.

If you're in the same boat - using AI to bridge the knowledge gap in Salesforce - these skills are for you.

**Connect:**
- GitHub: [@jhillock](https://github.com/jhillock)
- LinkedIn: [John Hillock](https://www.linkedin.com/in/YOUR_LINKEDIN) - Let's connect if you're building AI tools for Salesforce or navigating the "accidental admin" path

---

## Questions or Issues?

- **Bug reports:** [Open an issue](https://github.com/jhillock/salesforce-claude-skills/issues)
- **Usage questions:** [GitHub Discussions](https://github.com/jhillock/salesforce-claude-skills/discussions)
- **Just want to connect:** Find me on [LinkedIn](https://www.linkedin.com/in/YOUR_LINKEDIN)
