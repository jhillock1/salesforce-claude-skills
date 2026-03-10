---
name: salesforce-schema-verification
description: Verify all source-defined custom objects and fields exist in the target org's runtime schema before deploying dependent metadata
allowed-tools: [Bash, Read, Grep, Glob, mcp__Salesforce_DX__*]
---

# Schema Verification

## When to Use
- After deploying custom objects/fields and BEFORE deploying Apex, Flows, or LWCs
- After a sandbox refresh to verify all metadata survived
- When deploys succeed but Apex/Flows fail with "field not found" errors
- When you suspect schema cache corruption

## Why This Matters

Salesforce deployments can report success while silently skipping fields. Bulk deploys of the entire `force-app` directory have been observed to skip 30+ custom fields without any error. If you then deploy Apex or Flows that reference those fields, they'll fail — and you won't know WHY because the object deploy said "success."

## Quick Check: Do My Objects Exist?

```bash
# Run anonymous Apex to list all custom objects visible to runtime
sf apex run --target-org <your-org-alias> -f /dev/stdin <<'APEX'
Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
List<String> customs = new List<String>();
for (String s : gd.keySet()) {
    if (s.contains('__c')) customs.add(s);
}
customs.sort();
for (String s : customs) System.debug(s);
APEX
```

Compare this output against your source objects:
```bash
# List all custom objects in source
ls force-app/main/default/objects/ | grep '__c'
```

Any object in source but NOT in the Apex output is **invisible to runtime** despite potentially showing as "deployed."

## Detailed Check: Do All Fields Exist?

```bash
# For a specific object, list all fields visible to runtime
sf apex run --target-org <your-org-alias> -f /dev/stdin <<'APEX'
Schema.DescribeSObjectResult desc = Schema.SObjectType.YOUR_OBJECT__c;
Map<String, Schema.SObjectField> fields = desc.fields.getMap();
List<String> fieldNames = new List<String>(fields.keySet());
fieldNames.sort();
for (String f : fieldNames) System.debug(f);
APEX
```

Compare against source fields:
```bash
# List all fields defined in source for an object
ls force-app/main/default/objects/YOUR_OBJECT__c/fields/ | sed 's/.field-meta.xml//'
```

## Automated Verification Script

Run this after deploying objects to verify ALL custom fields across ALL custom objects:

```bash
sf apex run --target-org <your-org-alias> -f /dev/stdin <<'APEX'
// Get all custom objects from runtime schema
Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
for (String objName : gd.keySet()) {
    if (!objName.contains('__c')) continue;
    Schema.DescribeSObjectResult desc = gd.get(objName).getDescribe();
    Map<String, Schema.SObjectField> fields = desc.fields.getMap();
    System.debug('OBJECT: ' + objName + ' | FIELDS: ' + fields.size());
    for (String f : fields.keySet()) {
        if (f.contains('__c')) System.debug('  FIELD: ' + f);
    }
}
APEX
```

## When Objects Are Missing from Runtime (Schema Cache Corruption)

If objects deploy successfully but are invisible to `Schema.getGlobalDescribe()`:

1. **Confirm via Tooling API** that the objects actually exist:
```bash
sf data query --query "SELECT DurableId, DeveloperName, NamespacePrefix FROM CustomObject WHERE DeveloperName='Your_Object'" --target-org <your-org-alias> --tooling-api --json
```

2. If Tooling API shows them but runtime doesn't — this is **schema cache corruption**
3. See the `salesforce-deploy` skill's "Schema Cache Corruption on Hyperforce" section for workarounds

## Post-Refresh Verification Checklist

After a sandbox refresh, run these in order:

1. **Check custom objects exist:**
```bash
sf apex run --target-org <your-org-alias> -f /dev/stdin <<'APEX'
String[] expected = new String[]{'Object1__c', 'Object2__c', 'Object3__c'};
Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
for (String obj : expected) {
    System.debug(obj + ': ' + (gd.containsKey(obj.toLowerCase()) ? 'EXISTS' : 'MISSING'));
}
APEX
```

2. **Check field counts match source:**
```bash
# Count fields in source
for dir in force-app/main/default/objects/*__c/fields; do
    obj=$(basename $(dirname "$dir"))
    count=$(ls "$dir" 2>/dev/null | wc -l | tr -d ' ')
    echo "$obj: $count fields in source"
done
```

3. **Compare against org field counts** (from the automated verification above)

4. **Deploy missing fields explicitly** if any gaps found:
```bash
# Deploy fields for a specific object
sf project deploy start --source-dir force-app/main/default/objects/Case/fields/ --target-org <your-org-alias>
```

5. **Re-verify** after deploying missing fields

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Object in Tooling API but not in runtime | Schema cache corruption | Enable/disable Einstein or file support case |
| Field count mismatch | Bulk deploy silently skipped fields | Deploy fields explicitly per-object |
| Field exists but SOQL fails | Field-level security not granted | Check profile/permission set FLS |
| "Invalid field" in Apex after deploy | Deploy succeeded but field invisible | Run schema verification, redeploy fields individually |
