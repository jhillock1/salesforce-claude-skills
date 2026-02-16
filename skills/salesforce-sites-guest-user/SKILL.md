---
name: salesforce-sites-guest-user
description: Patterns for Salesforce Sites guest user pages — DML restrictions, Visualforce workarounds, and security model
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep, mcp__Salesforce_DX__*]
---

# Salesforce Sites & Guest User Development

## When to Use
- Building any Visualforce page served via Salesforce Sites (public-facing)
- When guest users need to read or write Salesforce records
- When you encounter 401 "Authorization Required" errors on Sites pages

## The Core Problem

Sites Guest Users have severe DML restrictions that are **not documented clearly by Salesforce**:

| Action | Allowed? | Notes |
|--------|----------|-------|
| SOQL in VF constructor (GET request) | Yes | Read-only is fine |
| DML in VF constructor (GET request) | **NO** | Returns 401 "Authorization Required" |
| DML in AJAX actionFunction | **NO** | Same 401 error |
| DML in VF action method via full page POST | **YES** | commandButton without reRender |

---

## The Working Pattern: Full Page POST

Guest users CAN do DML in Visualforce action methods triggered by a full page POST (commandButton **without** `reRender`). The key is avoiding AJAX — no `reRender`, no `actionFunction`.

### Architecture

```
1. Constructor (GET)
   └─ SOQL-only validation (check token, load record)
   └─ Set page state (valid/invalid/already-processed)
   └─ NO DML

2. Page renders with hidden commandButton
   └─ JavaScript auto-clicks the button on page load

3. Full POST fires action method
   └─ DML is allowed here (insert staging record)
   └─ Page re-renders with result (success/error)
```

### Visualforce Page Template

```xml
<apex:page controller="MyController" showHeader="false" sidebar="false"
           applyHtmlTag="true" applyBodyTag="false" docType="html-5.0"
           action="{!IF(autoSubmit, null, null)}">

    <!-- Show loading state initially -->
    <apex:outputPanel rendered="{!showProcessing}">
        <p>Processing your request...</p>
        <apex:form>
            <!-- Hidden button — JavaScript clicks this to trigger full POST -->
            <apex:commandButton id="autoSubmitBtn"
                                action="{!processRequest}"
                                value="Submit"
                                style="display:none;" />
        </apex:form>
        <script>
            // Auto-click after page loads — triggers full POST with DML
            window.onload = function() {
                var btn = document.getElementById('{!$Component.autoSubmitBtn}');
                if (btn) btn.click();
            };
        </script>
    </apex:outputPanel>

    <!-- Show result after POST completes -->
    <apex:outputPanel rendered="{!showResult}">
        <p>{!resultMessage}</p>
    </apex:outputPanel>
</apex:page>
```

### Controller Pattern

```apex
public without sharing class MyController {
    public Boolean showProcessing { get; set; }
    public Boolean showResult { get; set; }
    public String resultMessage { get; set; }

    // Constructor — SOQL ONLY, no DML
    public MyController() {
        String token = ApexPages.currentPage().getParameters().get('token');
        showProcessing = false;
        showResult = false;

        if (String.isBlank(token)) {
            showResult = true;
            resultMessage = 'Invalid request.';
            return;
        }

        // Validate token via SOQL
        List<My_Object__c> records = [
            SELECT Id, Status__c FROM My_Object__c
            WHERE Token__c = :token LIMIT 1
        ];

        if (records.isEmpty()) {
            showResult = true;
            resultMessage = 'Request not found.';
            return;
        }

        if (records[0].Status__c == 'Processed') {
            showResult = true;
            resultMessage = 'Already processed.';
            return;
        }

        // Valid — show processing state (JS will auto-click)
        showProcessing = true;
    }

    // Action method — DML IS ALLOWED HERE (full POST)
    public PageReference processRequest() {
        try {
            // Insert staging record — flow handles the rest
            Case_Response_Request__c req = new Case_Response_Request__c(
                Token__c = token,
                Action__c = 'accept'
            );
            insert req;

            showProcessing = false;
            showResult = true;
            resultMessage = 'Request processed successfully.';
        } catch (Exception e) {
            showProcessing = false;
            showResult = true;
            resultMessage = 'Error: ' + e.getMessage();
        }
        return null; // Stay on same page
    }
}
```

---

## Staging Object Pattern

When guest users need to trigger complex operations (updating Cases, sending emails), use a **staging object** to bridge guest user DML to system-level operations:

```
Guest User inserts Case_Response_Request__c (staging record)
  → Record-triggered flow fires (SystemModeWithoutSharing)
    → Flow reads the staging record
    → Flow updates the Case (system context — full access)
    → Flow deletes or marks the staging record as processed
```

### Why Not Direct DML on Case?

1. Guest user's `with sharing` context can't see most Cases
2. Even `without sharing` on the controller may not have field-level access
3. Staging object + flow gives you full system context with audit trail

### Staging Object Design

```
Case_Response_Request__c
├── Token__c (Text, Unique, External ID)
├── Action__c (Picklist: accept, reject, comment)
├── Case__c (Lookup to Case)
├── Response_Text__c (Long Text Area)
├── Status__c (Picklist: Pending, Processed, Error)
└── Processed_Date__c (DateTime)
```

---

## Security Considerations

### Controller Sharing Mode

- Use `without sharing` on the controller class — guest users need to read records they don't "own"
- The SOQL in the constructor is your access control — validate via token, not record sharing
- Never expose record IDs in URLs — use opaque tokens (UUID or encrypted ID)

### Token Validation

```apex
// GOOD: Opaque token that can't be guessed
String token = ApexPages.currentPage().getParameters().get('t');
List<My_Object__c> records = [
    SELECT Id FROM My_Object__c WHERE Token__c = :token LIMIT 1
];

// BAD: Salesforce record ID in URL (can be enumerated)
String caseId = ApexPages.currentPage().getParameters().get('id');
```

### Guest User Profile Permissions

- Grant READ access to the staging object
- Grant CREATE access to the staging object
- Do NOT grant access to Case, Contact, or other sensitive objects
- The flow runs in system context — it doesn't need guest user permissions

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| 401 "Authorization Required" | DML in constructor or AJAX | Use full page POST pattern |
| "Insufficient access on cross-reference entity" | Guest user can't access related record | Use staging object + system-mode flow |
| "FIELD_INTEGRITY_EXCEPTION" on lookup | Guest user can't see the related record | Set lookup field to not required, populate in flow |
| Page shows "Under Construction" | Sites page not assigned or not active | Check Sites settings in Setup |

---

## Debugging Sites Pages

```bash
# Check Sites configuration
sf data query --query "SELECT Id, Name, Status, SiteType FROM Site WHERE Name='Your_Site'" --target-org sandbox --json

# Check guest user profile
sf data query --query "SELECT Id, Name FROM Profile WHERE Name LIKE '%Site%Guest%'" --target-org sandbox --json

# Check page assignments
sf data query --query "SELECT Id, Name FROM ApexPage WHERE Name='YourPage'" --target-org sandbox --json
```

### Testing Locally

Sites pages must be tested via the actual Sites URL (not `/apex/PageName`):
```
https://casechek--partial.sandbox.my.salesforce-sites.com/pagepath?token=abc123
```

You cannot test guest user behavior as a logged-in admin — the sharing/permission model is completely different.
