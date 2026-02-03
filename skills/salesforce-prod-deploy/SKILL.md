---
name: salesforce-prod-deploy
description: Pre-deployment safety checks and wave deployment for promoting sandbox changes to production
allowed-tools: [Bash, Read, mcp__Salesforce_DX__*]
---

# Production Deployment Safety

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
  --target-org production \
  --output-dir /tmp/prod-current \
  --metadata "Flow:FlowName1,Flow:FlowName2"

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

```
Wave 1: Custom Fields + Standard Value Sets (picklists)
         └─ Everything else depends on these existing
Wave 2: New Flows + Apex Classes + Test Classes
         └─ Referenced by quick actions and pages
Wave 3: Quick Actions
         └─ Referenced by flexipages
Wave 4: List Views + Path Assistants + Page Layouts
         └─ Reference fields and actions
Wave 5: Flexipages (Case Record Page, Service Home)
         └─ Reference everything above
Wave 6: Modified Existing Flows (HIGHEST RISK)
         └─ Deploy last, rollback first if broken
```

### 3. Queue/ID Verification — Are hardcoded IDs correct for prod?

Flows often contain hardcoded queue IDs, user IDs, or record type IDs from sandbox. These are DIFFERENT in production.

```bash
# Find hardcoded IDs in your changed files
git diff main --diff-filter=AM -- '*.flow-meta.xml' '*.cls' | grep -E '[0-9a-zA-Z]{15,18}' | grep -v "apiVersion\|xmlns"

# Cross-reference: Get prod queue IDs
sf data query --query "SELECT Id, DeveloperName, Name FROM Group WHERE Type='Queue'" --target-org production --json

# Get prod record type IDs
sf data query --query "SELECT Id, DeveloperName, SObjectType FROM RecordType WHERE SObjectType='Case'" --target-org production --json
```

**If ANY ID doesn't match prod, the flow will error at runtime.** Fix in code before deploying.

### 4. Automation Audit — What else references what you're changing?

Before modifying status values or fields, check what references them:

```bash
# Find all flows referencing a status value
grep -rl "Waiting on Customer\|Waiting on Partner\|Waiting on Internal" force-app/main/default/flows/

# Find validation rules that might reference old values
grep -rl "Waiting on" force-app/main/default/objects/Case/validationRules/

# Find reports (if retrieved)
grep -rl "Waiting on" force-app/main/default/reports/ 2>/dev/null

# Check process builders (legacy)
grep -rl "Waiting on" force-app/main/default/workflows/ 2>/dev/null
```

Also query prod directly:
```bash
# Flows referencing a field
sf data query --query "SELECT Id, Definition.DeveloperName FROM FlowVersionView WHERE Status='Active' AND Definition.DeveloperName != null" --target-org production --json
```

### 5. Dry Run — Does it even deploy?

```bash
# Validate each wave WITHOUT deploying
sf project deploy start --source-dir <wave-paths> --target-org production --dry-run
```

If dry-run fails, fix before proceeding. Common causes:
- Missing dependency (deploy order wrong)
- Test class failure (check Apex tests pass)
- Profile/permission conflicts

### 6. Apex Tests — Do they pass in prod context?

```bash
# Run your test classes against production
sf apex run test --class-names CaseLifecycleFlowTest --target-org production --wait 10
```

---

## Wave Deployment Execution

### Create a Backup First
```bash
# Tag current prod state
BACKUP_DIR="prod-backup-$(date +%Y%m%d-%H%M)"
mkdir -p "$BACKUP_DIR"

# Retrieve everything you're about to overwrite
sf project retrieve start \
  --target-org production \
  --output-dir "$BACKUP_DIR" \
  --metadata "Flow:Flow1,Flow:Flow2,FlexiPage:Page1"

echo "Backup saved to $BACKUP_DIR"
```

### Deploy Each Wave
```bash
# Wave 1: Fields + picklists
sf project deploy start --source-dir force-app/main/default/objects/Case/fields/ \
  --source-dir force-app/main/default/standardValueSets/ \
  --target-org production

# Wave 2: New flows + Apex
sf project deploy start --source-dir force-app/main/default/flows/New_Flow_1.flow-meta.xml \
  --source-dir force-app/main/default/classes/ \
  --target-org production

# ... continue per wave
```

**Verify after each wave before proceeding to the next:**
```bash
# Quick sanity check — does the component exist?
sf org list metadata --metadata-type Flow --target-org production | grep "FlowName"
```

### Wave 6: Modified Flows (Do Last)
This is the danger zone. These are live flows that agents use right now.

1. Deploy the modified flow
2. **Immediately test** the affected action in the org (e.g., click Escalate Case)
3. If it errors → rollback from backup:
```bash
sf project deploy start --source-dir "$BACKUP_DIR/force-app/main/default/flows/Broken_Flow.flow-meta.xml" --target-org production
```

---

## Rollback Plan

If something breaks after deploy:

```bash
# Rollback specific component from backup
sf project deploy start \
  --source-dir prod-backup-YYYYMMDD-HHMM/force-app/main/default/flows/BrokenFlow.flow-meta.xml \
  --target-org production

# Rollback entire wave
sf project deploy start \
  --source-dir prod-backup-YYYYMMDD-HHMM/force-app/ \
  --target-org production
```

**New components** (fields, new flows) don't need rollback — they're additive and harmless. Deactivate new flows in the UI if needed.

**Modified components** are the rollback priority — restore from backup immediately.

---

## Migration Flows (Special Handling)

One-time migration flows (e.g., status value conversion):
1. Deploy as **Inactive**
2. Run manually in prod via Setup → Flows → Run
3. Spot-check results: query 10 affected records
4. Deactivate/delete after confirmed

```bash
# Verify migration results
sf data query --query "SELECT Status, Waiting_On__c, COUNT(Id) FROM Case WHERE IsClosed=false GROUP BY Status, Waiting_On__c" --target-org production
```

---

## Timing

- **Deploy during low traffic:** Before 7 AM ET or after 6 PM ET
- **Never deploy Friday afternoon** — you won't catch errors until Monday
- **Best day:** Tuesday or Wednesday morning — full week to catch issues
- **Migration flows:** Run before agents log in

---

## Post-Deploy Checklist

- [ ] Each wave deployed successfully
- [ ] Modified flows tested manually in prod
- [ ] New list views visible to correct profiles
- [ ] Page layout changes showing on Case record
- [ ] Quick actions appearing on Case page
- [ ] Migration flow run and verified (if applicable)
- [ ] Old status values NOT removed yet (keep inactive for 2 weeks)
- [ ] Agents notified of changes
- [ ] Backup directory retained for 30 days

---

## Don't Forget

- **Status values:** Never remove old values in the same deploy. Keep them for 2+ weeks until confirmed nothing references them.
- **Flow versions:** Deploying a flow creates a new version. Old version is still there. If you need to rollback, activate the previous version in Setup → Flows.
- **Field-level security:** New fields may not be visible to all profiles. Check FLS after deploying fields.
- **List view visibility:** New list views default to "visible to me only." Set sharing to appropriate groups.
