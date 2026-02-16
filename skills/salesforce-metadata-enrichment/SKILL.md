---
name: salesforce-metadata-enrichment
description: Enrich Salesforce object/field metadata with AI-generated descriptions for better context
---

# Metadata Enrichment

Analyze Salesforce objects and their related metadata to add meaningful descriptions, improving AI context for future interactions.

## When to Use

- "Enrich metadata for [Object]"
- "Add descriptions to [Object] fields"
- "Document [Object] metadata"
- "Improve metadata context for [Object]"
- When fields/objects lack descriptions or help text

## Workflow Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ 1. Retrieve     │───▶│ 2. Analyze      │───▶│ 3. Interview    │───▶│ 4. Review &     │
│    Metadata     │    │    (Haiku)      │    │    User         │    │    Deploy       │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
   From Production      Generate predictions   Clarify unknowns      Show diff, confirm
```

## Metadata Types Covered

| Type | Description Element | Location |
|------|---------------------|----------|
| **Object** | `<description>` | `objects/[Object]/[Object].object-meta.xml` |
| **Fields** | `<description>`, `<inlineHelpText>` | `objects/[Object]/fields/*.field-meta.xml` |
| **Flows** | `<description>` | `flows/*.flow-meta.xml` |
| **Quick Actions** | `<description>` | `objects/[Object]/quickActions/*.quickAction-meta.xml` or `quickActions/` |
| **Buttons/Links** | N/A (document via label) | `objects/[Object]/webLinks/*.webLink-meta.xml` |
| **Page Layouts** | Section labels | `layouts/*.layout-meta.xml` |
| **Lightning Pages** | `<description>`, `<masterLabel>` | `flexipages/*.flexipage-meta.xml` |
| **Compact Layouts** | `<label>` | `objects/[Object]/compactLayouts/*.compactLayout-meta.xml` |
| **Slack Record Layouts** | UI-only (see notes) | Setup > Object Manager > Slack Record Layouts |

### Slack Record Layouts Note

Slack Record Layouts control how records appear in Slack (View, Create, Edit modes, and URL unfurling). They are:
- Configured via **Setup > Object Manager > [Object] > Slack Record Layouts**
- Part of the **Sales Cloud for Slack** app configuration
- **Not currently exposed** as a standalone Metadata API type
- Must be configured manually in the UI after object enrichment

When enriching an object, note which fields would be valuable in Slack views so the user can configure Slack Record Layouts manually.

## Instructions

### Step 1: Get Object Name

Ask user which object to enrich. List available objects if needed:

```bash
ls force-app/main/default/objects/
```

### Step 2: Retrieve All Related Metadata from Production

Pull the complete picture for the target object:

```bash
# Core object and fields
sf project retrieve start --target-org production --metadata "CustomObject:[ObjectName]__c"

# Page layouts for this object
sf project retrieve start --target-org production --metadata "Layout:[ObjectName]__c-*"

# Lightning pages for this object (record pages)
sf project retrieve start --target-org production --metadata "FlexiPage:[ObjectName]_Record_Page,FlexiPage:[ObjectName]_Record_Lightning"

# Find related flows (retrieve all, then filter)
sf project retrieve start --target-org production --metadata "Flow"
```

### Step 3: Analyze Current State

#### 3a. Object and Fields
```bash
# Object-level metadata
cat "force-app/main/default/objects/[ObjectName]__c/[ObjectName]__c.object-meta.xml"

# All fields
find "force-app/main/default/objects/[ObjectName]__c/fields" -name "*.field-meta.xml" -exec cat {} \;

# Quick actions
find "force-app/main/default/objects/[ObjectName]__c/quickActions" -name "*.xml" -exec cat {} \; 2>/dev/null

# Buttons/Links
find "force-app/main/default/objects/[ObjectName]__c/webLinks" -name "*.xml" -exec cat {} \; 2>/dev/null

# Compact layouts
find "force-app/main/default/objects/[ObjectName]__c/compactLayouts" -name "*.xml" -exec cat {} \; 2>/dev/null
```

#### 3b. Related Flows
```bash
# Find flows that reference this object
grep -l "[ObjectName]__c" force-app/main/default/flows/*.flow-meta.xml 2>/dev/null

# Check each flow's description
for f in $(grep -l "[ObjectName]__c" force-app/main/default/flows/*.flow-meta.xml 2>/dev/null); do
  echo "=== $f ==="
  grep -A1 "<description>" "$f" || echo "NO DESCRIPTION"
  grep "<label>" "$f" | head -1
done
```

#### 3c. Page Layouts
```bash
# Classic layouts
ls force-app/main/default/layouts/ | grep "[ObjectName]"

# Lightning pages
ls force-app/main/default/flexipages/ | grep -i "[ObjectName]"
```

### Step 4: Generate Predictions (Use Haiku)

Launch a Haiku agent to analyze and generate descriptions:

```
Use the Task tool with model: "haiku" to analyze all gathered metadata and generate:

1. Object description (if missing)
2. Field descriptions and help text (prioritize fields missing both)
3. Flow descriptions (for flows touching this object)
4. Quick action descriptions
5. Lightning page descriptions
6. Compact layout analysis (which fields appear, are labels clear?)
7. Slack Record Layout recommendations (fields for View/Edit/Unfurl)

Output format:

## [ObjectName]__c Metadata Analysis

### Object Description
Current: [existing or "MISSING"]
Proposed: [AI-generated description]
Confidence: HIGH/MEDIUM/LOW

### Fields Needing Enrichment

| Field | Type | Current Desc | Proposed Desc | Proposed Help Text | Confidence |
|-------|------|--------------|---------------|-------------------|------------|
| Field_Name__c | Text | MISSING | [proposed] | [proposed] | HIGH |

### Related Flows

| Flow | Current Desc | Proposed Desc | Confidence |
|------|--------------|---------------|------------|
| Flow_Name | MISSING | [proposed] | MEDIUM |

### Quick Actions

| Action | Current Desc | Proposed Desc | Confidence |
|--------|--------------|---------------|------------|
| New_Case | MISSING | [proposed] | HIGH |

### Lightning Pages

| Page | Current Desc | Proposed Desc | Confidence |
|------|--------------|---------------|------------|
| Object_Record_Page | MISSING | [proposed] | MEDIUM |

### Slack Record Layout Recommendations
Fields recommended for Slack views (user must configure manually in Setup):
- **View mode**: [key identifying fields]
- **Edit mode**: [commonly updated fields]
- **URL unfurling**: [summary fields for link previews]

### Questions for User
1. [Question about LOW confidence items]
2. [Clarification needed for business context]
```

**Confidence levels:**
- **HIGH**: Clear from name, formula, or standard pattern
- **MEDIUM**: Reasonable inference from context
- **LOW**: Needs user input

### Step 5: Interview User

Present the Haiku analysis and ask for clarification on:
- LOW confidence predictions
- Business context the AI couldn't infer
- Any corrections to MEDIUM confidence items

Use AskUserQuestion for structured input when helpful.

### Step 6: Generate XML Changes

After user confirms, generate the exact XML edits for each metadata type:

**Object description:**
```xml
<description>User-approved description text here.</description>
```

**Field description and help text:**
```xml
<description>What this field stores and why.</description>
<inlineHelpText>Help text shown to users in the UI (max 255 chars).</inlineHelpText>
```

**Flow description** (add after `<label>` element):
```xml
<description>What this flow does and when it runs.</description>
```

**Quick Action description:**
```xml
<description>What this action does.</description>
```

**FlexiPage description:**
```xml
<description>Purpose of this Lightning page.</description>
```

### Step 7: Show Full Diff for Approval

Before any edits, show the user exactly what will change:

```bash
# After making edits, show diff
git diff force-app/main/default/objects/[ObjectName]__c/
git diff force-app/main/default/flows/
git diff force-app/main/default/flexipages/
```

**CRITICAL**: Wait for explicit user approval before proceeding.

### Step 8: Deploy to Production

Only after user explicitly approves:

```bash
# Deploy all enriched metadata
sf project deploy start --target-org production \
  --metadata "CustomObject:[ObjectName]__c" \
  --metadata "Flow:[FlowName1],Flow:[FlowName2]" \
  --metadata "FlexiPage:[PageName]"
```

Remind user:
- Verify changes in Setup > Object Manager
- **Slack Record Layouts** must be configured manually in UI (not deployable via metadata)
- Consider setting up Slack layouts using the recommended fields from analysis

## Safety Rules

1. **Never auto-deploy** - Always show diff and wait for approval
2. **Production is read-then-write** - Retrieve fresh before proposing changes
3. **One object at a time** - Reduces blast radius of any issues
4. **Preserve existing content** - Only add/improve, never remove descriptions
5. **Character limits** - `inlineHelpText` max 255 chars, `description` max 1000 chars

## Example Session

```
User: Enrich metadata for Asset_Contact__c

Claude: I'll retrieve all related metadata from production.
[Retrieves object, fields, flows, layouts, flexipages]

Found:
- 12 fields (8 missing descriptions)
- 1 custom button (Bulk_Create_from_Asset)
- 2 flows referencing this object
- 1 Lightning page

[Launches Haiku agent for analysis]

Haiku Analysis:
- Object has description ✓
- 8 fields need descriptions
- 2 flows missing descriptions
- Button links to flow "Build_Asset_Contact_Roles"

HIGH confidence (5):
- Contact__c: "Lookup to the Contact associated with this asset"
- Asset__c: "Master-detail to the parent Asset record"
- ...

LOW confidence (3):
- Role__c: What values are valid? What do they mean?
- IsSupportContact__c: How is this used operationally?

Questions:
1. What determines the Role__c picklist values?
2. What makes someone a "support contact"?

User: Role is the person's relationship to the asset (Admin, User, Billing).
      Support contacts receive automated notifications about the asset.

Claude: Here are all proposed changes:
[Shows complete XML diff across all metadata types]

Do you approve deploying these changes to production?

User: Yes

Claude: [Deploys and confirms]
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Retrieve fails | Check `sf org list` for auth status |
| Deploy fails | Check for validation rules, required fields |
| Flow not found | May be in a different package or inactive |
| No flexipage | Object may use standard page, not custom |
| Character limit error | Shorten description to fit limits |

## Field Description Patterns

Use these natural language patterns based on field type:

| Field Type | Description Pattern | Help Text Pattern |
|------------|---------------------|-------------------|
| **Checkbox** | "Indicates whether [condition]" | "Check if [when to check]" |
| **Picklist** | "Defines/Categorizes [what it classifies]" | "Select [guidance on choosing]" |
| **Multi-Select** | "Tracks which [items] are [state]" | "Select all [items] that [apply]" |
| **Date** | "Date when [event occurred/will occur]" | "Enter the date when [event]" |
| **DateTime** | "Timestamp when [event]" | "Enter when [event]" |
| **Lookup** | "Links to the [related object] that [relationship]" | "Select the [object] [guidance]" |
| **Text** | "Stores [what it contains]" | "Enter [what to enter]" |
| **TextArea** | "Documents [what it captures]" | "Describe [what to describe]" |
| **Logic TextArea** | "Documents the business rules for [process]" | "Describe the logic for [process]" |
| **Number/Currency** | "Stores the [metric/amount] for [purpose]" | "Enter the [metric] [guidance]" |
| **Formula** | "Calculated field that [what it computes]" | "[Result] (read-only)" |

### XML Element Ordering

When adding description to fields, place elements in this order:

```xml
<CustomField>
    <fullName>FieldName__c</fullName>
    <defaultValue>false</defaultValue>        <!-- if checkbox -->
    <description>YOUR DESCRIPTION HERE</description>
    <externalId>false</externalId>            <!-- if present -->
    <inlineHelpText>YOUR HELP TEXT HERE</inlineHelpText>
    <label>Field Label</label>
    <!-- remaining elements... -->
</CustomField>
```

**Key**: `description` goes after `fullName` (and `defaultValue` if present), before `label`.

## Efficient Batching for Large Objects

When enriching objects with many fields (50+):

1. **Count first**: `grep -L '<description>' force-app/.../fields/*.xml | wc -l`
2. **Read in batches of 8**: Process 8 fields at a time to balance context vs efficiency
3. **Edit in parallel**: Make all 8 Edit tool calls in a single response
4. **Verify progress**: `grep -c '<description>' .../*.xml | grep -v ':0$' | wc -l`

## Handling Untracked Files

When files are retrieved from prod but not yet committed:
- `git diff` shows nothing (files are untracked)
- Show sample files directly with `Read` tool instead
- Explain that files are new, not modified

## Session Persistence

If a session is interrupted (`/clear`):
- **Files on disk persist** - work is not lost
- **Conversation context is lost** - Claude won't remember prior discussion
- Check actual file state: `grep -c '<description>' .../*.xml`
- Resume from current file state, not from memory

## Direct Production Deployment

User may choose to skip sandbox. This is acceptable for metadata-only changes (descriptions/help text) that:
- Don't affect business logic
- Don't change field types or picklist values
- Only add/modify documentation

Always confirm user intent before deploying to production.
