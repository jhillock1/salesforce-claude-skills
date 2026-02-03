# Salesforce Claude Skills

**Claude Code skills for Salesforce development** - patterns, best practices, and workflows for building on the Salesforce platform.

## What's Included

| Skill | Purpose |
|-------|---------|
| **salesforce-patterns** | LWC, SOQL, Apex best practices and validation rules |
| **salesforce-quick-actions** | Create flow-based and field update quick actions |
| **salesforce-flows** | Build screen flows, autolaunched flows, and record-triggered flows |
| **salesforce-lightning-pages** | Wire components and actions to lightning pages |
| **salesforce-deploy** | Deployment patterns using `sf` CLI |
| **salesforce-prod-deploy** | Production deployment safety and validation |
| **salesforce-metadata-enrichment** | Query and enrich metadata from your org |
| **salesforce-list-views** | Create and manage list views |
| **salesforce-test-validation** | Test class patterns and validation |
| **salesforce-connect** | Connect to Salesforce orgs (sandbox/production) |

## Why These Skills Exist

Claude Code is powerful for Salesforce development but often:
- Creates global quick actions instead of object-scoped ones
- Forgets `WITH SECURITY_ENFORCED` in SOQL
- Deploys without testing in sandbox first
- Violates governor limits in loops

These skills teach Claude your org's patterns so it builds correctly the first time.

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

These skills are templates. You should:
1. Update `salesforce-patterns/SKILL.md` with your org's RecordTypes
2. Add your custom objects to relevant skills
3. Modify deployment patterns to match your CI/CD setup
4. Add org-specific validation rules

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on submitting improvements.

## License

MIT License - see [LICENSE](LICENSE)

## Author

Built by [jhillock1](https://github.com/jhillock1) after 170+ Claude Code sessions and way too many "why is this quick action global?!" moments.
