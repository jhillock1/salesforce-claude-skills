# Validation Scripts

Cross-cutting validation tools that apply to multiple skills.

## Available Scripts

### check-soql-security.sh

**Purpose:** Finds SOQL queries in Apex classes missing `WITH SECURITY_ENFORCED` or `WITH USER_MODE`

**Usage:**
```bash
# Check all classes
bash scripts/check-soql-security.sh force-app/main/default/classes/

# Check single file
bash scripts/check-soql-security.sh force-app/main/default/classes/MyClass.cls
```

**Exit codes:**
- 0: All queries have security enforcement
- 1: Found queries without security enforcement

**Related skill:** `salesforce-patterns`

---

### validate-flow-xml.sh

**Purpose:** Validates Flow XML structure and checks for common issues

**Usage:**
```bash
bash scripts/validate-flow-xml.sh force-app/main/default/flows/My_Flow.flow-meta.xml
```

**Checks:**
- Valid XML structure
- Required elements present (`<status>`, `<processType>`)
- Screen flows have `<start>` element
- Flow activation status

**Exit codes:**
- 0: Flow XML is valid
- 1: Flow has validation issues

**Related skill:** `salesforce-flows`

---

## Skill-Specific Scripts

Some validation scripts live with their skill:

- `skills/salesforce-quick-actions/validate-quick-action.sh` - Checks for `<targetObject>` element

---

## Using in CI/CD

These scripts can be integrated into pre-commit hooks or CI pipelines:

```bash
# .git/hooks/pre-commit example
#!/bin/bash

# Check SOQL security on changed Apex files
git diff --cached --name-only --diff-filter=ACM | grep "\.cls$" | while read file; do
  if ! bash scripts/check-soql-security.sh "$file"; then
    echo "SOQL security check failed. Commit aborted."
    exit 1
  fi
done
```
