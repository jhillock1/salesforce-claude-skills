---
name: salesforce-prod-deploy
description: Pre-deployment safety checks and wave deployment for promoting sandbox changes to production
allowed-tools: [Bash, Read, mcp__Salesforce_DX__*]
---

# Production Deployment Safety

> **Example from a production org with 20 admins and frequent concurrent changes**

## When to Use
- Before ANY production deployment
- When promoting validated sandbox work to production
- When John says "deploy to prod", "promote to prod", or "go live"

## STOP — Before You Do Anything

**Never deploy to production without completing ALL pre-flight checks.** No exceptions. Run them in order. If any check fails, stop and resolve before continuing.

---

## Pre-Flight Checks

### 1. Drift Detection — Are we overwriting someone else's work?

20 admins touch this org. Retrieve the prod versions of every file you're about to deploy and diff against your branch.

```bash
# Retrieve prod state of modified files
sf project retrieve start \
  --target-org sandbox-prod \
  --output-dir /tmp/prod-current \
  --metadata "Flow:Escalation_Auto_Assign,Flow:Meeting_Note_Sync"

# Diff against your branch
diff /tmp/prod-current/force-app/ force-app/ --brief
```

**Specifically check the high-risk modified files:**
```bash
# Get list of files modified (not new) on this branch vs main
git diff main --diff-filter=M --name-only
```

For each modified file:
1. Retrieve from production
2. Diff against main branch (not your feature branch) — this shows admin changes since your last sync
3. If drift found → merge admin changes into your branch first

**If you skip this step and overwrite an admin's change, it's gone.** No undo in Salesforce.

### 2. Dependency Map — What needs to exist before what?

Some metadata depends on other metadata existing first. Map it out:

```bash
# Find all metadata types in your deployment
find force-app/main/default -type d -maxdepth 1 | grep -v "^\.$"

# Check dependencies:
# - Flows reference which fields/objects?
# - Quick actions reference which flows?
# - Flexipages reference which actions/components?
```

**Common dependency order:**
1. Custom Fields / Objects
2. Flows (reference fields/objects)
3. Quick Actions (reference flows)
4. Flexipages / Page Layouts (reference actions + fields)
5. Permission Sets / Profiles (reference all of the above)

**Real example from production:**
```
Wave 1: Meeting_Note__c fields (Account_Link__c, Meeting_Date__c)
Wave 2: Meeting_Note_Sync flow (references new fields)
Wave 3: Log_Meeting quick action (references flow)
Wave 4: Account_Record_Page flexipage (references action)
Wave 5: Service_Agent_Profile (references all components)
```

### 3. Impact Analysis — Who/what breaks if this fails mid-deploy?

**Ask these questions:**

- **Is this used in production right now?**
  - Modifying an active Flow? Users are running it NOW.
  - Changing a flexipage? Users are viewing it NOW.

- **What's the blast radius?**
  - Single team vs entire company
  - Internal tools vs customer-facing features
  - Nice-to-have vs critical path

- **Can we roll back?**
  - Metadata changes: YES (redeploy old version)
  - Data changes: MAYBE (depends on what changed)
  - Destructive changes: NO (deletions are permanent)

**If blast radius is high, deploy during maintenance window** (off-hours for your users).

### 4. Test Coverage Validation

```bash
# Run tests in sandbox before deploying to prod
sf apex run test \
  --target-org sandbox-uat \
  --code-coverage \
  --result-format human \
  --wait 10

# Check coverage percentage
# Salesforce requires 75% for production deploys
```

**If coverage is below 75%:**
- Write more test classes
- Deploy tests FIRST (separate deployment)
- Then deploy the actual feature

### 5. Backup Critical Metadata

Before deploying changes to frequently-modified components, back them up:

```bash
# Backup current prod state
sf project retrieve start \
  --target-org sandbox-prod \
  --output-dir ~/prod-backups/$(date +%Y%m%d-%H%M)/ \
  --metadata "Flow:*,QuickAction:*,FlexiPage:*"
```

**Why?** If you need to emergency-rollback, you have a known-good state.

---

## Wave Deployment Pattern

**For large deployments with dependencies:**

### Wave 1: Foundation (Custom Objects & Fields)
```bash
sf project deploy start \
  --source-dir force-app/main/default/objects/Meeting_Note__c \
  --target-org sandbox-prod \
  --test-level RunLocalTests
```

**Wait for confirmation. Verify in UI that objects/fields are visible.**

### Wave 2: Automation (Flows, Apex)
```bash
sf project deploy start \
  --source-dir force-app/main/default/flows/Meeting_Note_Sync.flow-meta.xml \
  --source-dir force-app/main/default/classes/ \
  --target-org sandbox-prod \
  --test-level RunLocalTests
```

**Activate flows manually in UI after deploy** (they deploy as Inactive by default for safety).

### Wave 3: UI Components (Quick Actions, LWC)
```bash
sf project deploy start \
  --source-dir force-app/main/default/objects/Account/quickActions/ \
  --source-dir force-app/main/default/lwc/ \
  --target-org sandbox-prod \
  --test-level RunLocalTests
```

### Wave 4: Layout/Page Updates (Flexipages, Layouts)
```bash
sf project deploy start \
  --source-dir force-app/main/default/flexipages/Account_Record_Page.flexipage-meta.xml \
  --source-dir force-app/main/default/layouts/ \
  --target-org sandbox-prod \
  --test-level NoTestRun  # Layouts don't require tests
```

### Wave 5: Permissions (Profiles, Permission Sets)
```bash
sf project deploy start \
  --source-dir force-app/main/default/permissionsets/ \
  --target-org sandbox-prod \
  --test-level NoTestRun
```

**Between waves:**
- Verify in production UI
- Test the deployed components manually
- Check for errors in Debug Logs

---

## Rollback Plan

**If deployment fails or causes issues:**

### Option A: Redeploy Previous Version
```bash
# Restore from backup
sf project deploy start \
  --source-dir ~/prod-backups/20260203-1430/ \
  --target-org sandbox-prod \
  --test-level RunLocalTests
```

### Option B: Deactivate Problematic Component
```bash
# For flows: Deactivate in UI (Setup > Flows > find flow > Deactivate)
# For quick actions: Remove from page layouts
# For LWC: Remove from flexipages
```

### Option C: Emergency Destructive Change
```bash
# Delete the broken component (LAST RESORT)
# Create destructiveChanges.xml and deploy
```

---

## Post-Deployment Verification

**After every production deploy:**

1. **Smoke test in production:**
   - Navigate to affected pages
   - Trigger affected flows (if possible without real data)
   - Check Debug Logs for errors

2. **Monitor for 1 hour:**
   - Watch for user error reports (Slack, email, Chatter)
   - Check Debug Logs for exceptions
   - Review Email Deliverability (if email alerts involved)

3. **Document what deployed:**
   ```bash
   # Update CHANGELOG.md or deployment log
   echo "$(date): Deployed Meeting_Note_Sync flow to production (Wave 2)" >> CHANGELOG.md
   ```

---

## Real-World Example

**Scenario:** Deploy Meeting Note integration (custom object + flow + quick action + flexipage)

**Pre-flight:**
- ✅ Drift check: No admin changes to Account flexipage since last week
- ✅ Dependencies: Flow needs Meeting_Note__c fields first
- ✅ Impact: Medium (affects Sales team, ~50 users)
- ✅ Tests: 82% coverage, all passing
- ✅ Backup: Saved current Account_Record_Page to `~/prod-backups/20260203-1430/`

**Waves:**
1. Deploy Meeting_Note__c object + fields → verify in prod
2. Deploy Meeting_Note_Sync flow (inactive) → activate manually → test with 1 record
3. Deploy Log_Meeting quick action → verify appears in actions menu
4. Deploy Account_Record_Page updates → verify action shows on page
5. Deploy Service_Agent_Profile permissions → verify users see new action

**Post-deployment:**
- Tested on 3 accounts, flow ran successfully
- Monitored for 1 hour, no errors
- Documented in CHANGELOG.md

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Deploying without drift check | Always retrieve prod first, diff |
| Deploying all-at-once with dependencies | Use wave deployment |
| Deploying during business hours | Deploy after-hours for high-impact changes |
| No rollback plan | Always have prod backups ready |
| Not activating flows after deploy | Flows deploy inactive, activate manually |

---

## Remember

**Production deployments are high-stakes.** Take your time. Check twice. Deploy once.
