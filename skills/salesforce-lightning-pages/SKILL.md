---
name: salesforce-lightning-pages
description: Modify Lightning Record Pages (flexipages) — add quick actions, move fields, add components, edit highlights panel
allowed-tools: [Bash, Read, Write, Edit, mcp__Salesforce_DX__*]
---

# Lightning Record Pages (Flexipages)

## When to Use
- Adding quick actions to a record page
- Moving fields, components, or tabs on a Lightning page
- Modifying highlights panel actions
- Adding or rearranging related lists

## Critical Knowledge

### Flexipages Live in the Org, Not Just the Repo
Most flexipages are NOT in your local repo. You must **retrieve first**:

```bash
# Find the flexipage name for an object
sf project retrieve start --metadata FlexiPage --target-org sandbox

# Or retrieve a specific one
sf project retrieve start --metadata "FlexiPage:Case_Record_Page" --target-org sandbox
```

The file lands in: `force-app/main/default/flexipages/<Name>.flexipage-meta.xml`

### Flexipage XML Structure (Key Sections)
```xml
<FlexiPage xmlns="http://soap.sforce.com/2006/04/metadata">
    <flexiPageRegions>
        <!-- HIGHLIGHTS PANEL — where quick actions live -->
        <name>header</name>
        <itemInstances>
            <componentInstance>
                <componentName>highlights</componentName>
                <!-- Actions are nested deep inside here -->
            </componentInstance>
        </itemInstances>
        
        <!-- MAIN BODY — tabs, fields, components -->
        <name>main</name>
        <!-- ... -->
        
        <!-- SIDEBAR — related lists, activity timeline -->
        <name>sidebar</name>
        <!-- ... -->
    </flexiPageRegions>
</FlexiPage>
```

## Recipes

### Add Quick Actions to Highlights Panel

**Step 1:** Retrieve the flexipage (see above)

**Step 2:** Find the highlights panel action list. Search for:
```xml
<componentName>highlights</componentName>
```

Inside that component, find the `<componentInstanceProperties>` with `<name>actionNames</name>`. The value is a **comma-separated list** of action API names.

**Step 3:** Add your action to the comma-separated list:
```xml
<componentInstanceProperties>
    <name>actionNames</name>
    <value>Case.Post_Email_Prompt,Case.Propose_Solution,Case.ChangeOwner,Case.Close</value>
</componentInstanceProperties>
```

⚠️ **CRITICAL**: Actions must be **object-scoped** (e.g., `Case.Post_Email_Prompt`), NOT global. See `salesforce-quick-actions` skill for how to create them correctly.

**Step 4:** Deploy the flexipage:
```bash
sf project deploy start --source-dir force-app/main/default/flexipages/Case_Record_Page.flexipage-meta.xml --target-org sandbox
```

### Add a Component to a Tab
Find the tab's `<flexiPageRegions>` section, then add an `<itemInstances>` block:
```xml
<itemInstances>
    <componentInstance>
        <componentName>YOUR_COMPONENT_NAME</componentName>
        <componentInstanceProperties>
            <name>propertyName</name>
            <value>propertyValue</value>
        </componentInstanceProperties>
    </componentInstance>
</itemInstances>
```

### Move Fields Between Sections
Fields on flexipages are in `<componentInstanceProperties>` within field section components. To move a field:
1. Find its current `<itemInstances>` block
2. Cut it
3. Paste into the target section's `<itemInstances>` list
4. Field order = display order

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Quick action "not found" during deploy | Action must be object-scoped with `<targetObject>` — see quick-actions skill |
| Flexipage not in repo | Must retrieve from org first: `sf project retrieve start --metadata FlexiPage` |
| Related list actions vs highlights panel actions | They're different XML sections — search for `highlights` for the main action bar |
| Deploy fails with unrelated errors | Use targeted deploy: `--source-dir` pointing only to the flexipage file |

## Validation After Deploy
1. Open a record in sandbox
2. Verify the action appears in the highlights panel (top action bar)
3. Click it to verify it launches correctly
4. Check that existing actions still work (regression)
