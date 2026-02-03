# Salesforce Claude Skills

**Claude Code skills for Salesforce development** - patterns, best practices, and validation tools for building on the Salesforce platform.

## What This Is

A **hybrid approach** combining:
- **Skills** (markdown docs) that teach Claude Code common Salesforce patterns
- **Validation scripts** (bash/shell) that catch mistakes before deployment

Built from 170+ real Claude Code sessions and countless "why did that fail?!" moments.

## What's Included

### Skills (`skills/`)

| Skill | Purpose | Validation Script |
|-------|---------|-------------------|
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

See [INSTALL.md](INSTALL.md) for setup instructions.

## Usage

Once installed, Claude Code will automatically reference these skills when:
- Creating quick actions → loads `salesforce-quick-actions`
- Writing SOQL queries → loads `salesforce-patterns`
- Deploying metadata → loads `salesforce-deploy`

You can also explicitly mention them:
```
Using the salesforce-quick-actions skill, create a flow-based quick action 
for the Case object that launches the "Propose Solution" screen flow.
```

## Customization

**These skills are templates - customize them for your org.**

Look for **🔧 CUSTOMIZE** markers in skill files:

1. **Org aliases:** Replace `<your-sandbox-alias>` with your actual org names (see `sf org list`)
2. **RecordTypes:** Update `salesforce-patterns/SKILL.md` with your org's RecordTypes
3. **Custom objects:** Document your custom objects and their purpose
4. **Integration points:** List external systems connected to Salesforce
5. **Project structure:** Add paths to your `.claude/GOALS.md`, `LEARNINGS.md`, etc. (or remove if not using)

**Recommended first customizations:**
```bash
# 1. Set your org aliases
sed -i '' 's/<your-sandbox-alias>/YOUR_SANDBOX_NAME/g' skills/*/SKILL.md
sed -i '' 's/<your-prod-alias>/YOUR_PROD_NAME/g' skills/*/SKILL.md

# 2. Add your RecordTypes to salesforce-patterns
vim skills/salesforce-patterns/SKILL.md  # Search for "RecordTypes in Use"
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on submitting improvements.

## License

MIT License - see [LICENSE](LICENSE)

## Author

Built by [jhillock1](https://github.com/jhillock1) after 170+ Claude Code sessions and way too many "why is this quick action global?!" moments.
