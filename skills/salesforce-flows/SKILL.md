---
name: salesforce-flows
description: Create and modify Salesforce Flows — XML structure, element ordering, record-triggered vs screen flows
allowed-tools: [Bash, Read, Write, Edit, mcp__Salesforce_DX__*]
---

# Salesforce Flows

## When to Use
- Creating screen flows, record-triggered flows, or auto-launched flows
- Modifying existing flow XML
- Fixing flow deployment errors (especially element ordering)
- Wiring flows to quick actions

## Critical Knowledge

### Flow XML Has STRICT Element Ordering
This is the #1 cause of cryptic deploy errors. Salesforce Flow XML requires elements of the same type to be **contiguous** (grouped together). You cannot interleave different element types.

**Correct order of elements in a Flow XML:**
```xml
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <label>My Flow</label>
    <processType>Flow</processType>
    <status>Draft</status>
    <interviewLabel>My Flow {!$Flow.CurrentDateTime}</interviewLabel>
    
    <!-- 1. Variables (ALL together) -->
    <variables>...</variables>
    <variables>...</variables>
    
    <!-- 2. Formulas (ALL together) -->
    <formulas>...</formulas>
    
    <!-- 3. Screens (ALL together) -->
    <screens>...</screens>
    <screens>...</screens>
    
    <!-- 4. Decisions (ALL together) -->
    <decisions>...</decisions>
    
    <!-- 5. Record operations (ALL together by type) -->
    <recordLookups>...</recordLookups>
    <recordUpdates>...</recordUpdates>
    <recordCreates>...</recordCreates>
    
    <!-- 6. Assignments (ALL together) -->
    <assignments>...</assignments>
    
    <!-- 7. Start element -->
    <start>
        <locationX>...</locationX>
        <locationY>...</locationY>
        <connector>
            <targetReference>FirstElement</targetReference>
        </connector>
    </start>
</Flow>
```

⚠️ **"Element X is duplicated" error** = You have the same element type in two non-contiguous locations. Group them together.

### Flow Types
| Type | `<processType>` | `<start>` Trigger | Use Case |
|------|-----------------|-------------------|----------|
| Screen Flow | `Flow` | No trigger, manual launch | Quick actions, guided UX |
| Record-Triggered | `AutoLaunchedFlow` | `<recordTriggerType>` in `<start>` | Auto-fire on record change |
| Auto-Launched | `AutoLaunchedFlow` | Called by other flows/process | Utility/helper flows |
| Scheduled | `AutoLaunchedFlow` | `<scheduledPaths>` in `<start>` | Batch/timed operations |

### Screen Flow for Quick Action (Template)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <interviewLabel>Propose Solution {!$Flow.CurrentDateTime}</interviewLabel>
    <label>Propose Solution Quick Action</label>
    <processType>Flow</processType>
    <status>Active</status>
    
    <!-- Input variable — receives the record ID from the quick action -->
    <variables>
        <name>recordId</name>
        <dataType>String</dataType>
        <isInput>true</isInput>
    </variables>
    
    <!-- Screen with confirmation -->
    <screens>
        <name>Confirm_Screen</name>
        <label>Propose Solution</label>
        <locationX>176</locationX>
        <locationY>158</locationY>
        <connector>
            <targetReference>Update_Case</targetReference>
        </connector>
        <fields>
            <name>Confirmation_Message</name>
            <fieldType>DisplayText</fieldType>
            <fieldText>&lt;p&gt;This will mark the case as &quot;Solution Proposed&quot; and set Waiting On to &quot;Customer&quot;.&lt;/p&gt;</fieldText>
        </fields>
    </screens>
    
    <!-- Record update -->
    <recordUpdates>
        <name>Update_Case</name>
        <label>Update Case</label>
        <locationX>176</locationX>
        <locationY>278</locationY>
        <inputReference>recordId</inputReference>
        <inputAssignments>
            <field>Status</field>
            <value>
                <stringValue>Solution Proposed</stringValue>
            </value>
        </inputAssignments>
        <inputAssignments>
            <field>Waiting_On__c</field>
            <value>
                <stringValue>Customer</stringValue>
            </value>
        </inputAssignments>
    </recordUpdates>
    
    <!-- Start -->
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector>
            <targetReference>Confirm_Screen</targetReference>
        </connector>
    </start>
</Flow>
```

**Key:** The `recordId` variable with `<isInput>true</isInput>` is what receives the current record's ID when launched from a quick action.

### Record-Triggered Flow Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <label>Auto-Set Waiting On for Solution Proposed</label>
    <processType>AutoLaunchedFlow</processType>
    <status>Active</status>
    
    <variables>
        <name>currentRecord</name>
        <dataType>SObject</dataType>
        <isInput>true</isInput>
        <objectType>Case</objectType>
    </variables>
    
    <recordUpdates>
        <name>Set_Waiting_On</name>
        <label>Set Waiting On Customer</label>
        <locationX>176</locationX>
        <locationY>278</locationY>
        <inputReference>$Record</inputReference>
        <inputAssignments>
            <field>Waiting_On__c</field>
            <value>
                <stringValue>Customer</stringValue>
            </value>
        </inputAssignments>
    </recordUpdates>
    
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector>
            <targetReference>Set_Waiting_On</targetReference>
        </connector>
        <object>Case</object>
        <recordTriggerType>Update</recordTriggerType>
        <triggerType>RecordAfterSave</triggerType>
        <filterLogic>and</filterLogic>
        <filters>
            <field>Status</field>
            <operator>EqualTo</operator>
            <value>
                <stringValue>Solution Proposed</stringValue>
            </value>
        </filters>
    </start>
</Flow>
```

## Recipes

### Modify an Existing Flow
1. **Retrieve it first:**
   ```bash
   sf project retrieve start --metadata "Flow:Case_Prompt_Waiting_On_Customer" --target-org <your-sandbox-alias>
   ```
2. **Edit the XML** — maintain element ordering (all variables together, all screens together, etc.)
3. **Deploy:**
   ```bash
   sf project deploy start --source-dir force-app/main/default/flows/Case_Prompt_Waiting_On_Customer.flow-meta.xml --target-org <your-sandbox-alias>
   ```

### Add a Decision Element to an Existing Flow
Insert the `<decisions>` block with ALL other decision elements (if any). Wire it by updating `<connector><targetReference>` on the upstream element.

### Resolve Placeholder IDs (Queues, Record Types, etc.)
When a flow references a Queue or Record Type by ID, you MUST resolve the actual ID before deployment:

```bash
# Find a Queue ID
sf data query --query "SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Incident_Managers'" --target-org <your-sandbox-alias>

# Find a Record Type ID
sf data query --query "SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Case'" --target-org <your-sandbox-alias>
```

⚠️ **NEVER deploy with placeholder IDs** like `REPLACE_WITH_ACTUAL_QUEUE_ID`. The deploy will succeed but the flow will be broken at runtime.

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| "Element X is duplicated" | Element types are split — group all same-type elements together |
| Flow deploys but doesn't fire | Check `<status>Active</status>` and trigger conditions |
| Quick action can't find flow | Deploy flow BEFORE quick action; use API name not label |
| `$Record` not available | Only in record-triggered flows; screen flows use `recordId` input variable |
| Placeholder IDs left in XML | Query for real IDs before deploying (queues, profiles, record types) |

## Validation
1. Deploy succeeds
2. For screen flows: Launch from quick action, verify UI renders
3. For record-triggered: Update a record matching trigger criteria, verify field changes
4. Run Apex tests if test class exists: `sf apex run test --class-names MyFlowTest --target-org <your-sandbox-alias>`
