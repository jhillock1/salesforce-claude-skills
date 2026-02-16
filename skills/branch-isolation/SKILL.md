---
name: branch-isolation
description: Enforce strict branch isolation - one branch = one feature/fix tied to a dev plan
---

# Branch Isolation

**Skill ID:** `branch-isolation`  
**Domain:** Git workflow, project planning  
**Purpose:** Enforce strict branch isolation - one branch = one feature/fix tied to a dev plan

---

## Core Principle

**Every branch must map to exactly ONE item in `~/casechek-salesforce/docs/plans/`.**

Branches are not dumping grounds. They are focused delivery units with clear scope boundaries.

---

## Pre-Work Checklist

Before touching ANY code:

1. **Identify the dev plan**
   ```bash
   ls ~/casechek-salesforce/docs/plans/
   cat ~/casechek-salesforce/docs/plans/<relevant-plan>.md
   ```

2. **Confirm branch scope with user**
   - "I see this relates to [dev plan item]. Confirming scope: [X, Y, Z]. Anything else is out of scope for this branch. Correct?"
   - Wait for explicit confirmation

3. **Check current branch**
   ```bash
   git branch --show-current
   ```

4. **Validate branch name matches dev plan**
   - Branch should reference the plan or feature clearly
   - Example: `feature/slack-incident-notifications` (ties to `incident_slack_notifications.md`)

---

## During Work

### Scope Validation (Every File Change)

Before editing a file, ask:
- Does this change directly serve the dev plan item for THIS branch?
- If NO → stop, ask user if scope has changed

### When Tempted to Mix Changes

**STOP.** You are about to violate branch isolation.

**Anti-pattern from session 766aaacd:**
- User working on Feature A (slack notifications)
- Claude starts making changes for Feature B (unrelated metadata fixes)
- User has to correct: "That's not part of this branch"
- Result: Wasted time, unclear git history, merge conflicts

**Correct approach:**
1. Note the additional work needed
2. Tell user: "I notice [X] also needs work, but that's outside the scope of [current dev plan]. Should we:
   - Create a new branch for it after this?
   - Add it to backlog?
   - Ignore for now?"
3. Do NOT implement until user explicitly expands scope or creates new branch

---

## Scope Creep Detection

**Red flags that you're mixing unrelated changes:**
- Editing files in different functional areas (e.g., Flows + Lightning Pages in one branch)
- Fixing "while I'm here" bugs unrelated to dev plan
- Refactoring code that doesn't block the current feature
- User says "that's not what we're working on"

**When flagged:**
1. Stop immediately
2. Acknowledge: "You're right, that's scope creep. Reverting to [original scope]."
3. Ask: "Should we branch separately for [the other change]?"

---

## Branch Completion

Before marking work complete:

```bash
# Review all changes
git status
git diff --stat

# Validate: Do ALL changes serve the dev plan item?
# If NO → split into separate branches
```

---

## Examples

### ✅ GOOD: Clean Branch Isolation

**Branch:** `feature/slack-incident-notifications`  
**Dev Plan:** `incident_slack_notifications.md`  
**Changes:**
- `force-app/.../IncidentSlackNotification.flow-meta.xml`
- `force-app/.../Slack_Notification__c.object-meta.xml`
- `docs/slack_integration_notes.md`

**Why good:** All changes directly serve Slack incident notification feature.

---

### ❌ BAD: Mixed Unrelated Changes

**Branch:** `feature/slack-incident-notifications`  
**Dev Plan:** `incident_slack_notifications.md`  
**Changes:**
- `force-app/.../IncidentSlackNotification.flow-meta.xml` ✅
- `force-app/.../CaseListView.listView-meta.xml` ❌ (unrelated)
- `force-app/.../QuickAction_UpdateStatus.quickAction-meta.xml` ❌ (unrelated)

**Why bad:** List views and quick actions are NOT part of Slack notification work. These belong in separate branches tied to their own dev plan items.

**User correction (session 766aaacd):** "Claude doesn't respect branch isolation and mixes unrelated changes into feature branches"

---

## Decision Tree

```
About to make a code change?
  |
  ├─ Is there a dev plan for current branch?
  |    NO → STOP. Ask user which dev plan this ties to.
  |    YES → Continue
  |
  ├─ Does this change directly serve the dev plan item?
  |    NO → STOP. Ask user if scope changed or if new branch needed.
  |    YES → Continue
  |
  └─ Proceed with change
```

---

## Integration with Other Skills

- **Before using `salesforce-deploy`:** Confirm all metadata in deployment serves ONE dev plan
- **Before using `metadata-enrichment`:** Validate enrichment scope matches branch scope
- **Before using `salesforce-flows`:** Ensure Flow changes align with current dev plan item

---

## Concurrent Session Hazard

**Two Claude Code sessions on the same repo can corrupt git state.**

What happens: Session A does `git checkout main && git reset --hard <sha>`, but Session B switches branches between the checkout and reset. The reset lands on Session B's branch, not main.

**Mitigation:**
1. At session start, check if other Claude processes are active:
   ```bash
   ps aux | grep -i claude | grep -v grep
   ```
2. If another session is running on the same repo, warn the user immediately
3. Avoid destructive git operations (`reset --hard`, `checkout .`, `clean -f`) when concurrent sessions are possible
4. Always verify branch with `git branch --show-current` immediately before any destructive operation — don't trust a checkout from 30 seconds ago

**Real incident:** Session A reset main to fix contamination, but Session B had switched to `plan/service-cloud-2026`. The reset hit the plan branch instead of main. Required manual recovery.

---

## Failure Mode Recovery

If you realize mid-work that you've mixed changes:

1. **Acknowledge immediately:** "I mixed unrelated changes. Let me fix this."
2. **Assess damage:**
   ```bash
   git status
   git diff --name-only
   ```
3. **Propose fix:**
   - Option A: Stash unrelated changes, create new branch
   - Option B: Reset and restart with correct scope
   - Option C: User manually separates (last resort)

---

## Success Metrics

- User never has to say "that's not part of this branch"
- Each branch ties cleanly to exactly one dev plan item
- Git history is clear and reviewable
- Merge conflicts reduced (because branches don't overlap scope)

---

## Key Takeaway

**Branches are promises.** When you create or work on a branch tied to a dev plan, you're promising that ONLY that work will land there. Keep the promise.
