# Installation

## Prerequisites

- [Claude Code](https://github.com/anthropics/claude-code) installed
- Salesforce CLI (`sf`) installed
- Git

## Option 1: Clone into Global Skills Directory

```bash
# Clone to Claude's global skills directory
git clone https://github.com/jhillock1/salesforce-claude-skills.git ~/.claude/skills/salesforce

# Claude will auto-discover skills in this directory
```

## Option 2: Clone into Project-Specific Skills

```bash
# Clone into your Salesforce project
cd ~/your-salesforce-project
git clone https://github.com/jhillock1/salesforce-claude-skills.git .claude/skills/salesforce
```

## Option 3: Symlink (Recommended for Multiple Projects)

```bash
# Clone once
git clone https://github.com/jhillock1/salesforce-claude-skills.git ~/salesforce-claude-skills

# Symlink in each project
cd ~/project-1
mkdir -p .claude/skills
ln -s ~/salesforce-claude-skills/skills .claude/skills/salesforce

cd ~/project-2
mkdir -p .claude/skills
ln -s ~/salesforce-claude-skills/skills .claude/skills/salesforce
```

## Verify Installation

Start a Claude Code session in your Salesforce project:

```bash
claude-code
```

Ask Claude:
```
What Salesforce skills do you have available?
```

It should list the skills from this repo.

## Customization

After installation, customize for your org:

### 1. Update RecordTypes

Edit `skills/salesforce-patterns/SKILL.md`:

```markdown
### RecordTypes in Use
- **Case:** Your_RecordType_Names_Here
- **Opportunity:** Your_RecordType_Names_Here
- **Account:** Your_RecordType_Names_Here
```

### 2. Add Custom Objects

If you have custom objects like `CustomObject__c`:

```markdown
### Custom Objects
- CustomObject__c - Description of purpose
- AnotherCustom__c - Description of purpose
```

### 3. Configure Deployment Targets

Edit `skills/salesforce-deploy/SKILL.md` to match your org aliases:

```bash
# Your sandbox
sf project deploy start --target-org YOUR_SANDBOX_ALIAS

# Your production
sf project deploy start --target-org YOUR_PROD_ALIAS
```

## Updates

Pull latest changes:

```bash
cd ~/.claude/skills/salesforce  # or wherever you cloned it
git pull origin main
```

## Troubleshooting

**Claude doesn't see the skills:**
- Check that skills are in `~/.claude/skills/` or `YOUR_PROJECT/.claude/skills/`
- Verify each skill has a `SKILL.md` file
- Restart your Claude Code session

**Skills exist but aren't being used:**
- Explicitly mention the skill name in your prompt
- Check `.claude/instructions.md` in your project - it may override skill behavior

**Deploy commands fail:**
- Verify `sf` CLI is installed: `sf --version`
- Confirm org authentication: `sf org list`
- Check that org aliases match your customizations
