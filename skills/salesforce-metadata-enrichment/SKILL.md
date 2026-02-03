---
name: salesforce-metadata-enrichment
description: Enrich Salesforce object/field metadata with AI-generated descriptions for better context
allowed-tools: [Bash, Read, Write, Edit, mcp__Salesforce_DX__*]
---

# Metadata Enrichment

Analyze Salesforce objects and their related metadata to add meaningful descriptions, improving AI context for future interactions.

## When to Use

- "Enrich metadata for [Object]"
- "Add descriptions to [Object] fields"
- "Document [Object] metadata"
- When fields/objects lack descriptions or help text

## Workflow Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ 1. Retrieve     │───▶│ 2. Analyze &    │───▶│ 3. Interview    │───▶│ 4. Review &     │
│    Metadata     │    │    Predict      │    │    User         │    │    Deploy       │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
   From Production      Generate descriptions  Clarify unknowns      Show diff, confirm
```

## Metadata Types Covered

| Type | Description Element | Location |
|------|---------------------|----------|
| **Object** | `<description>` | `objects/[Object]/[Object].object-meta.xml` |
| **Fields** | `<description>`, `<inlineHelpText>` | `objects/[Object]/fields/*.field-meta.xml` |
| **Flows** | `<description>` | `flows/*.flow-meta.xml` |
| **Quick Actions** | `<description>` | `objects/[Object]/quickActions/*.quickAction-meta.xml` |
| **Page Layouts** | Section labels | `layouts/*.layout-meta.xml` |
| **Lightning Pages** | `<description>` | `flexipages/*.flexipage-meta.xml` |
| **Compact Layouts** | `<label>` | `objects/[Object]/compactLayouts/*.compactLayout-meta.xml` |

> **Slack Record Layouts** are UI-only (Setup > Object Manager > Slack Record Layouts). Note recommended fields for Slack views during enrichment, but these must be configured manually.

## Instructions

### Step 1: Get Object Name

Ask user which object to enrich. List available objects if needed:

```bash
ls force-app/main/default/objects/
```

### Step 2: Retrieve All Related Metadata from Production

```bash
# Core object and fields
sf project retrieve start --target-org production --metadata "CustomObject:[ObjectName]__c"

# Page layouts
sf project retrieve start --target-org production --metadata "Layout:[ObjectName]__c-*"

# Lightning pages
sf project retrieve start --target-org production --metadata "FlexiPage:[ObjectName]_Record_Page"

# Find related flows
sf project retrieve start --target-org production --metadata "Flow"
```

### Step 3: Analyze Current State

```bash
# Object-level metadata
cat "force-app/main/default/objects/[ObjectName]__c/[ObjectName]__c.object-meta.xml"

# All fields
find "force-app/main/default/objects/[ObjectName]__c/fields" -name "*.field-meta.xml" -exec cat {} \;

# Quick actions
find "force-app/main/default/objects/[ObjectName]__c/quickActions" -name "*.xml" -exec cat {} \; 2>/dev/null

# Compact layouts
find "force-app/main/default/objects/[ObjectName]__c/compactLayouts" -name "*.xml" -exec cat {} \; 2>/dev/null

# Flows referencing this object
grep -l "[ObjectName]__c" force-app/main/default/flows/*.flow-meta.xml 2>/dev/null

# Check each flow's description
for f in $(grep -l "[ObjectName]__c" force-app/main/default/flows/*.flow-meta.xml 2>/dev/null); do
  echo "=== $f ==="
  grep -A1 "<description>" "$f" || echo "NO DESCRIPTION"
  grep "<label>" "$f" | head -1
done
```

### Step 4: Generate Predictions

Analyze all gathered metadata and generate descriptions. For each item, assign a confidence level:

- **HIGH**: Clear from name, formula, or standard pattern
- **MEDIUM**: Reasonable inference from context
- **LOW**: Needs user input — flag for interview

Output format:

```
## [ObjectName] Metadata Analysis

### Object Description
Current: [existing or "MISSING"]
Proposed: [description]
Confidence: HIGH/MEDIUM/LOW

### Fields Needing Enrichment

| Field | Type | Current Desc | Proposed Desc | Proposed Help Text | Confidence |
|-------|------|--------------|---------------|-------------------|------------|

### Related Flows

| Flow | Current Desc | Proposed Desc | Confidence |

### Quick Actions / Lightning Pages

| Item | Current Desc | Proposed Desc | Confidence |

### Questions for User
1. [Question about LOW confidence items]
```

### Step 5: Interview User

Present analysis and ask for clarification on:
- LOW confidence predictions
- Business context that can't be inferred
- Corrections to MEDIUM confidence items

### Step 6: Generate XML Changes

After user confirms, apply edits. For XML element ordering in fields, see `salesforce-flows` skill for general ordering rules. Field-specific order:

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

### Step 7: Show Full Diff for Approval

**CRITICAL**: Wait for explicit user approval before deploying.

```bash
git diff force-app/main/default/objects/[ObjectName]__c/
git diff force-app/main/default/flows/
git diff force-app/main/default/flexipages/
```

### Step 8: Deploy

Only after user explicitly approves. Use targeted deploys (see `salesforce-deploy` skill):

```bash
sf project deploy start --target-org production \
  --source-dir force-app/main/default/objects/[ObjectName]__c
```

Direct production deployment is acceptable for metadata-only changes (descriptions/help text) that don't affect business logic.

## Field Description Patterns

| Field Type | Description Pattern | Help Text Pattern |
|------------|---------------------|-------------------|
| **Checkbox** | "Indicates whether [condition]" | "Check if [when to check]" |
| **Picklist** | "Categorizes [what it classifies]" | "Select [guidance on choosing]" |
| **Multi-Select** | "Tracks which [items] are [state]" | "Select all that apply" |
| **Date/DateTime** | "Date/time when [event]" | "Enter when [event]" |
| **Lookup** | "Links to the [object] that [relationship]" | "Select the [object] [guidance]" |
| **Text** | "Stores [what it contains]" | "Enter [what to enter]" |
| **TextArea** | "Documents [what it captures]" | "Describe [what to describe]" |
| **Number/Currency** | "The [metric/amount] for [purpose]" | "Enter the [metric]" |
| **Formula** | "Calculated: [what it computes]" | "(Read-only)" |

## Safety Rules

1. **Never auto-deploy** — always show diff and wait for approval
2. **Production is read-then-write** — retrieve fresh before proposing changes
3. **One object at a time** — reduces blast radius
4. **Preserve existing content** — only add/improve, never remove descriptions
5. **Character limits** — `inlineHelpText` max 255 chars, `description` max 1000 chars

## Efficient Batching for Large Objects

When enriching objects with many fields (50+):

1. **Count first**: `grep -L '<description>' force-app/.../fields/*.xml | wc -l`
2. **Batch by 8**: Process 8 fields at a time to balance context vs efficiency
3. **Edit in parallel**: Make all 8 edits in a single response
4. **Verify progress**: `grep -c '<description>' .../*.xml | grep -v ':0$' | wc -l`

## Session Persistence

If a session is interrupted:
- **Files on disk persist** — work is not lost
- **Conversation context is lost** — check actual file state: `grep -c '<description>' .../*.xml`
- Resume from current file state, not from memory
