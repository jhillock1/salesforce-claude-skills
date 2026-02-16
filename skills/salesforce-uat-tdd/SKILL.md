---
name: salesforce-uat-tdd
description: UAT-driven development for Salesforce — write acceptance criteria first, validate with Apex tests, then build and verify
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep, mcp__Salesforce_DX__*]
---

# UAT-Driven Development for Salesforce

## When to Use
- Starting any new feature branch (flows, fields, flexipages, quick actions)
- Before building anything — define what "done" looks like first
- When John says "let's build X" or "we need Y"

## Core Loop

```
1. Write UAT checklist  →  Defines "done"
2. Write Apex tests     →  Validates metadata + flow behavior programmatically
3. Build in sandbox     →  Implement until tests pass
4. Manual UAT walkthrough → Walk the user's actual workflow in sandbox
5. Deploy to prod       →  Use salesforce-prod-deploy skill
6. Prod UAT walkthrough →  Walk the user's actual workflow in prod
```

**The UAT checklist is the source of truth.** Everything else serves it.

---

## Phase 1: Write the UAT Checklist

Before touching any metadata, create `docs/test_plans/<feature>-uat.xlsx`.

### Structure

Follow the proven pattern from Phase 0 (`service-cloud-phase0-master-uat.md`), but split into two tiers:

```markdown
# [Feature Name]: UAT Checklist

> **Branch:** `plan/feature-name`
> **Environment:** Sandbox (casechek--partial)
> **Tester:** John Hillock + Claude Code

---

## Tier 1: Apex-Validated (automated — no manual re-testing needed)

> These items are covered by `FeatureFlowTest.cls`. When all tests pass,
> mark the entire tier as passed. Do NOT manually re-verify these.

### Infrastructure
| # | Check | Apex Test | Pass? |
|---|-------|-----------|-------|
| AV-1 | `New_Field__c` picklist exists with 5 values | testFieldAcceptsAllValues | [ ] |
| AV-2 | `Formula__c` returns TRUE when Status = In Progress | testFormulaTrueWhenOpen | [ ] |

### Flow Behavior
| # | Check | Apex Test | Pass? |
|---|-------|-----------|-------|
| AV-3 | Inbound email clears Waiting_On__c | testInboundEmailClearsWaitingOn | [ ] |
| AV-4 | Flow does NOT override Status on email | testEmailFlowDoesNotOverrideStatus | [ ] |

### Data Outcomes
| # | Check | Apex Test | Pass? |
|---|-------|-----------|-------|
| AV-5 | Migration: old status maps to new Waiting_On value | testMigrationOutcome | [ ] |

**Pass criteria:** `sf apex run test --class-names FeatureFlowTest` → all green.
When tests pass, mark every AV item as [x] in one batch.

---

## Tier 2: Manual UAT (human walkthrough — things Apex can't test)

> These items require a human in the UI. They test layout, UX, and
> workflow coherence that Apex has no visibility into.

### UI & Layout
| # | Case # | Test | Expected | Pass? |
|---|--------|------|----------|-------|
| MU-1 | 00001234 | New field visible on record page | Field appears under "Case Information" | [ ] |
| MU-2 | 00001234 | Quick action appears in action bar | "Escalate Case" button visible | [ ] |

### End-to-End Workflow
| # | Case # | Step | Expected | Pass? |
|---|--------|------|----------|-------|
| MU-3 | (create new) | Agent opens queue, accepts case | Owner = agent | [ ] |
| MU-4 | 00001235 | Agent sends email reply | Toast shown, Waiting_On = Customer | [ ] |

### Edge Cases (manual-only)
| # | Case # | Test | Expected | Pass? |
|---|--------|------|----------|-------|
| MU-5 | 00001236 | Slack notification renders correctly | mrkdwn formatting | [ ] |
```

### Key Principle: Apex First, Manual Only When Necessary

**Every UAT item must pass the "Can Apex verify this?" gate.** If the answer is yes — even partially — it belongs in Tier 1. Tier 2 is exclusively for things that require human eyes on the UI.

**The gate question:** "Does this test check a data outcome, field value, flow behavior, or record state?" → **Tier 1 (Apex).** "Does this test check visual layout, UX coherence, element positioning, or workflow feel?" → **Tier 2 (Manual).**

Edge cases, process integrity checks, and error-handling scenarios are almost always Tier 1. They test whether flows/logic handle unusual inputs correctly — that's exactly what Apex assertions are for.

| Apex tests (Tier 1) | Manual UAT (Tier 2) |
|---------------------|---------------------|
| Fields exist and accept values | Fields are in the right page section |
| Formulas compute correctly | Formula result is visible/meaningful to user |
| Flows fire and set correct values | Flow outcomes make sense in context of workflow |
| Picklist values are valid | Picklist order/labels make sense in dropdown |
| Migration data is correct | Migrated records look right in list views |
| Flow interactions don't conflict | User doesn't see confusing intermediate states |
| **Edge cases produce correct data** | **Edge case UI doesn't confuse the user** |
| **Process integrity (rapid toggles, missing steps)** | **Slack/email notifications render correctly** |
| **Metrics calculate correctly in all scenarios** | **Dashboard/report layout makes sense** |

### UAT Checklist Rules

1. **Every item belongs to exactly one tier** — never both
2. **Tier 1 items link to their Apex test method** — so passing tests auto-pass the checklist
3. **Tier 2 items are things ONLY a human clicking through the UI can verify** — if Apex can assert the outcome, it's Tier 1
4. **Expected values are specific** — "Status = In Progress" not "Status changes"
5. **End-to-end scenarios are Tier 2 only when testing workflow coherence** — the individual assertions within them (field values, record states) should still be Tier 1
6. **When in doubt, write the Apex test** — if it passes, the item is Tier 1; if Apex literally cannot see it (page layout, tab order, toast messages), it's Tier 2

---

## Phase 2: Write Apex Tests (TDD)

Write `CaseLifecycleFlowTest.cls`-style Apex tests that validate metadata and flow behavior **before building the feature**.

### What Apex Tests Should Validate

Apex tests are your automated safety net. They catch metadata problems before you deploy.

#### 1. Fields exist and accept all picklist values

```apex
@IsTest
static void testFieldAcceptsAllValues() {
    List<Case> cases = new List<Case>();
    for (String val : new List<String>{'Value 1', 'Value 2', 'Value 3'}) {
        cases.add(new Case(Subject = 'Test ' + val, New_Field__c = val));
    }
    insert cases;
    System.assertEquals(3, [SELECT Id FROM Case WHERE Id IN :cases].size(),
        'All picklist values should be insertable');
}
```

**Why:** Catches missing picklist values before deploy. If a value doesn't exist, the insert fails with a clear error.

#### 2. Formula fields compute correctly

```apex
@IsTest
static void testFormulaFieldComputesCorrectly() {
    Case testCase = new Case(Subject = 'Test', Status = 'In Progress');
    insert testCase;
    Case result = [SELECT My_Formula__c FROM Case WHERE Id = :testCase.Id];
    System.assertEquals(true, result.My_Formula__c,
        'Formula should return TRUE when Status = In Progress');
}
```

**Why:** Formula logic is easy to get wrong. Tests verify the formula works for every condition in the truth table.

#### 3. Record-triggered flows fire correctly

```apex
@IsTest
static void testFlowSetsFieldOnCreate() {
    Test.startTest();
    Case testCase = new Case(Subject = 'Test Flow', Status = 'New');
    insert testCase;
    Test.stopTest();

    Case result = [SELECT Auto_Field__c FROM Case WHERE Id = :testCase.Id];
    System.assertEquals('Expected Value', result.Auto_Field__c,
        'Flow should auto-set field on case creation');
}
```

**Why:** Flows are invisible. Without a test, you only discover a broken flow when a user reports it. `Test.startTest()` / `Test.stopTest()` ensures async flow execution completes.

#### 4. Flow interactions don't conflict

```apex
@IsTest
static void testEmailFlowDoesNotOverrideStatus() {
    Case testCase = new Case(Subject = 'Test', Status = 'In Progress');
    insert testCase;

    Test.startTest();
    EmailMessage em = new EmailMessage(
        ParentId = testCase.Id, Incoming = true,
        FromAddress = 'customer@example.com',
        ToAddress = 'support@casechek.com',
        Subject = 'Re: Test', TextBody = 'Reply.'
    );
    insert em;
    Test.stopTest();

    Case result = [SELECT Status FROM Case WHERE Id = :testCase.Id];
    System.assertEquals('In Progress', result.Status,
        'Inbound email should NOT change Status');
}
```

**Why:** Casechek has 149+ flows. Multiple record-triggered flows can fire on the same DML operation. Tests catch when Flow A stomps on Flow B's changes.

#### 5. Migration/data transformation outcomes

```apex
@IsTest
static void testMigrationOutcome() {
    // Validate the expected POST-migration state
    Case testCase = new Case(
        Subject = 'Migrated Case',
        Status = 'In Progress',
        Waiting_On__c = 'Customer'
    );
    insert testCase;

    Case result = [SELECT Status, Waiting_On__c, Needs_Attention__c
                    FROM Case WHERE Id = :testCase.Id];
    System.assertEquals('In Progress', result.Status);
    System.assertEquals('Customer', result.Waiting_On__c);
    System.assertEquals(false, result.Needs_Attention__c);
}
```

**Why:** One-time migration flows are high-risk. Writing tests for the expected end-state lets you verify the migration worked without manually inspecting every record.

### Apex Test Pattern

```
Test class name:  <Feature>FlowTest.cls
Test setup:       @TestSetup with Account + Contact (required for Email tests)
Each method:      Tests ONE UAT checklist item
Method name:      test<UATItem><ExpectedOutcome>
Assertions:       Include failure message that maps back to UAT ID
```

### TDD Cycle

1. **Write the test first** — it will fail (field doesn't exist, flow not built yet)
2. **Build the minimum metadata** to make the test pass
3. **Run tests** — `sf apex run test --class-names FeatureFlowTest --target-org sandbox`
4. **Repeat** until all tests pass
5. **Batch-pass all Tier 1 (AV) items** — when the test suite is green, every AV item linked to a passing test gets checked off in one pass. No manual re-verification needed.

---

## Phase 3: Build in Sandbox

With UAT checklist and Apex tests defined, build the actual metadata:

1. **Fields first** — tests that insert records need fields to exist
2. **Flows second** — tests that check flow behavior need flows deployed
3. **UI components last** — flexipages, quick actions, list views

After each deployment to sandbox:
```bash
# Run tests to see what passes now
sf apex run test --class-names FeatureFlowTest --target-org casechek--partial --wait 10
```

Track progress by updating the UAT checklist — check off items as tests pass.

---

## Phase 3.5: Seed Test Cases for Manual UAT

**Before the human walkthrough, create real test records in the target org.** Every Tier 2 (MU) item must have a specific record the tester can open, not a vague instruction to "create a case."

### Why This Matters

Manual testers shouldn't waste time setting up data. They should open a record, perform the action, and verify the result. Claude creates the test cases; John validates the workflow.

### Test Case Creation Rules

1. **Every MU item gets a Case # (or record identifier)** — the tester opens that exact record
2. **Cases are pre-staged to the right state** — if MU-12 tests "customer replies," the case should already be In Progress with Waiting_On = Customer, with a real email thread
3. **Subjects are descriptive** — include the MU item number: `[MU-9] UAT: New case for state change logging`
4. **Group related MU items on the same case when sequential** — MU-9 through MU-16 (end-to-end workflow) can share one case walked through in order
5. **Use real-looking data** — real Account names from the org, realistic subjects, not "Test 123"
6. **Create via SOQL/DML (sf data create)** — not Apex test classes, so records persist in the org
7. **Record the Case # in the UAT xlsx** — in a dedicated "Case #" column on the Tier 2 sheet

### What to Create

For each MU section, seed records that let the tester start immediately:

| MU Section | Test Record State | Example |
|------------|------------------|---------|
| UI & Layout | Closed case with metrics populated | Case with state change history + metrics calculated |
| Field History | Case with recent Status/Waiting_On changes | Case changed 2-3 times so history is visible |
| E2E Workflow | Fresh case (Status = New, queue-owned) | Tester will walk it through the full lifecycle |
| Reports & Dashboard | N/A — reports query existing data | Ensure enough closed cases exist with metrics |
| Process Integrity | Edge-case states (never In Progress, rapid toggles) | One case per edge case scenario |

### Template: Test Case Insert

```bash
# Create a test case for manual UAT
sf data create record --sobject Case \
  --values "Subject='[MU-9] UAT: New case for state change logging' Status='New'" \
  --target-org sandbox --json
```

After creating all test cases, update the UAT xlsx with the Case numbers in the "Case #" column.

---

## Phase 4: Manual UAT Walkthrough (Sandbox)

**Tier 1 is already done.** All Apex tests pass, all AV items are checked off. This phase ONLY covers Tier 2 (MU items).

**Test cases are already seeded** (Phase 3.5). The tester opens the specific Case # listed in the xlsx for each MU item.

Manual UAT tests what Apex can't see — layout, UX, workflow coherence:
- Field is on the page but in the wrong section
- Quick action appears but has confusing field labels
- List view works but column order is unintuitive
- Flow fires correctly but the toast message is misleading
- Create form is missing a field that the user expects
- End-to-end workflow feels right from the agent's perspective

### Walkthrough Process

1. Open the UAT xlsx — go to the "Tier 2 - Manual UAT" sheet
2. For each MU item, open the Case # listed in the row
3. Perform the action described in "Test / Step"
4. Compare the result to "Expected Result"
5. Mark Pass/Fail in the "Pass?" column, add notes if needed
6. Log any issues on the "Issues" sheet with severity and related MU item
7. Fix issues, re-run Apex tests to ensure fixes didn't break Tier 1
8. Re-walk only the MU scenario that had the issue

**Do NOT re-verify Tier 1 items during walkthrough.** If you find yourself checking whether a field exists or a formula computes correctly, that belongs in an Apex test — add one and move the item to Tier 1.

---

## Phase 5: Deploy to Production

Hand off to `salesforce-prod-deploy` skill. The UAT checklist becomes the post-deploy verification list.

---

## Phase 6: Production UAT Walkthrough

**Production has different data, different users, different metadata names.**

This session proved why prod UAT matters:
- Field named `Jira_Link__c` in sandbox was `Jira_Ticket_Link__c` in prod
- Flow deployed as Draft instead of Active (old version kept running)
- Custom metadata type didn't exist in prod at all

### Prod Walkthrough Checklist

For each E2E scenario from the UAT:
1. Perform the action in production
2. Verify the expected outcome
3. If something breaks:
   - Check flow activation (`ActiveVersionId == LatestVersionId`)
   - Check field names match production
   - Check custom metadata records have correct prod values
4. Fix and re-verify

---

## Test Run Logging

After each UAT session, create a test run log at `docs/test_plans/test-runs/YYYY-MM-DD-runN.md` using the template.

Track:
- Which UAT items were tested
- Issues found and fixed
- New requirements discovered
- Blockers encountered
- What's left for next session

---

## Critical: Test Contact Rules

**NEVER create test cases with real/existing contacts.** Active flows (Case_Received_Acknowledgment) fire on every Case create with Origin=Email/Web + Contact, sending a **real email** to the Contact.

### Always use 'John Test' contact
```bash
# Find John Test contact
sf data query --query "SELECT Id, Name, Email FROM Contact WHERE Name='John Test'" --target-org sandbox --json
```

### Before creating any test case, verify the contact email
```bash
# STOP if email is a real customer domain
sf data query --query "SELECT Email FROM Contact WHERE Id='<ContactId>'" --target-org sandbox --json
# Email must be a @test.com, @example.com, or internal domain — NEVER a customer domain
```

### Test case location
- UAT workbooks live at `docs/test_plans/<feature>-uat.xlsx`
- The xlsx file is the source of truth — not markdown
- Use the `xlsx` skill to read/write xlsx files
- Case IDs for manual UAT go in the "Case #" column of the Tier 2 sheet

---

## Anti-Patterns

### Don't double-test
**Wrong:** Apex test proves `Waiting_On__c` clears on inbound email. Manual UAT says "verify Waiting_On__c is blank after email."
**Right:** Apex test proves the field clears (Tier 1). Manual UAT tests "case moves back to Needs Attention view and agent sees the response" (Tier 2 — layout/workflow).

If you find yourself manually re-checking something Apex already tested, that's wasted time. Move it to Tier 1 permanently.

### Don't build first, test later
**Wrong:** "Let me build the flow, then we'll see if it works."
**Right:** "Let me define what the flow should do (UAT), write a test for it, then build it."

### Don't skip manual walkthrough
**Wrong:** "All 27 Apex tests pass, we're done."
**Right:** "Tests pass — Tier 1 is complete. Now walk through the Tier 2 items: does the workflow feel right to the agent?"

### Don't assume sandbox == production
**Wrong:** "It works in sandbox, deploy it."
**Right:** "It works in sandbox. Let me check field names, flow activation, and custom metadata values match prod before deploying."

### Don't test developer paths instead of user paths
**Wrong:** Manual UAT: "Insert a Case record via DML, query the result." (That's an Apex test.)
**Right:** Manual UAT: "Open a queue-owned case, click Accept Case, send an email reply, verify the case moves to Waiting On view."

---

## File Locations

| Artifact | Location |
|----------|----------|
| UAT checklists | `docs/test_plans/<feature>-uat.xlsx` |
| Test run logs | `docs/test_plans/test-runs/YYYY-MM-DD-runN.md` |
| Test run template | `docs/test_plans/test-runs/TEMPLATE.md` |
| Apex test classes | `force-app/main/default/classes/<Feature>FlowTest.cls` |

---

## Integration with Other Skills

- **Before `salesforce-prod-deploy`:** UAT checklist must exist with sandbox items passing
- **During `salesforce-prod-deploy`:** UAT checklist becomes post-deploy verification
- **With `branch-isolation`:** UAT checklist defines branch scope — if it's not on the checklist, it's not in scope
