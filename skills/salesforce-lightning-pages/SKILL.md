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
sf project retrieve start --metadata FlexiPage --target-org <your-sandbox-alias>

# Or retrieve a specific one
sf project retrieve start --metadata "FlexiPage:Case_Record_Page" --target-org <your-sandbox-alias>
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
sf project deploy start --source-dir force-app/main/default/flexipages/Case_Record_Page.flexipage-meta.xml --target-org <your-sandbox-alias>
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

### Remove a Component from a Tab (Full Facet Chain Cleanup)

Removing a component from a flexipage is NOT as simple as deleting its `<itemInstances>` block. Flexipages use nested facet chains, and leaving orphaned facets breaks the XML silently.

**Step 1: Map the full facet chain BEFORE making any edits**

Search the flexipage for the component you want to remove. Note its containing facet ID. Then trace upward:

```
Component (e.g., quickActionListItem for "Escalate_to_Jira")
  └── contained in Facet-abf7c7ae (the immediate wrapper)
       └── referenced by fieldSection16 (a tab or section)
            └── contained in Facet-3307d075 (section wrapper)
                 └── referenced by column28 (a column)
                      └── contained in Facet-e850b2e3 (column wrapper)
```

**Step 2: Identify ALL elements to remove**

You must remove:
1. The `<itemInstances>` block containing your component
2. The tab/section `<itemInstances>` that references the component's facet
3. ALL intermediate facet `<flexiPageRegions>` blocks in the chain
4. Any `<facets>` references pointing to removed facets

**Step 3: Remove from bottom up**

Start with the innermost element (the component itself) and work outward:
1. Remove the component's itemInstance
2. Remove the facet region that contained only that component (if it's now empty)
3. Remove the section/tab item that referenced the now-empty facet
4. Continue up the chain, removing any facet regions that are now empty

**Step 4: Verify XML integrity**

After all edits:
- Every `<facets>` reference should point to an existing `<flexiPageRegions>` name
- No orphaned facet regions (facets not referenced by anything)
- Tab counts and column counts still make sense

**Step 5: Deploy and verify**
```bash
sf project deploy start --source-dir force-app/main/default/flexipages/YourPage.flexipage-meta.xml --target-org <your-org-alias>
```

If deploy fails with XML errors, you likely left an orphaned facet or removed a facet still referenced elsewhere.

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Quick action "not found" during deploy | Action must be object-scoped with `<targetObject>` — see quick-actions skill |
| Flexipage not in repo | Must retrieve from org first: `sf project retrieve start --metadata FlexiPage` |
| Related list actions vs highlights panel actions | They're different XML sections — search for `highlights` for the main action bar |
| Deploy fails with unrelated errors | Use targeted deploy: `--source-dir` pointing only to the flexipage file |
| Removing component leaves orphaned facets | Trace FULL facet chain before editing — remove all facets in the chain |
| Tab removed but section/column facets remain | Map parent→child facet relationships first, remove bottom-up |

## Validation After Deploy
1. Open a record in sandbox
2. Verify the action appears in the highlights panel (top action bar)
3. Click it to verify it launches correctly
4. Check that existing actions still work (regression)
