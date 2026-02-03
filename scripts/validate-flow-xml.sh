#!/bin/bash
# Validates basic Flow XML structure and common issues

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-flow-meta.xml>"
    echo "Example: $0 force-app/main/default/flows/My_Flow.flow-meta.xml"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "❌ ERROR: File not found: $FILE"
    exit 1
fi

ISSUES=0

# Check if it's a Flow file
if ! grep -q "Flow xmlns" "$FILE"; then
    echo "❌ ERROR: Not a valid Flow file (missing Flow xmlns)"
    exit 1
fi

echo "Validating Flow XML: $(basename "$FILE")"
echo ""

# Check for required elements in correct order
# Expected order: apiVersion, description, label, processType, status, ...

# Check if status is present
if ! grep -q "<status>" "$FILE"; then
    echo "⚠️  WARNING: Missing <status> element (flow may not be active)"
    ISSUES=1
fi

# Check if processType is present
if ! grep -q "<processType>" "$FILE"; then
    echo "⚠️  WARNING: Missing <processType> element"
    ISSUES=1
fi

# Check for common mistakes
if grep -q "<processType>Flow</processType>" "$FILE" && ! grep -q "<start>" "$FILE"; then
    echo "❌ ERROR: Screen flow missing <start> element"
    ISSUES=1
fi

# Check that screens have labels
SCREEN_COUNT=$(grep -c "<screens>" "$FILE" 2>/dev/null || echo "0")
SCREEN_LABEL_COUNT=$(grep -c "<screens>.*<label>" "$FILE" 2>/dev/null || echo "0")

if [ "$SCREEN_COUNT" -gt 0 ]; then
    echo "ℹ️  Found $SCREEN_COUNT screen(s) in flow"
fi

# Validate XML is well-formed (basic check)
if ! xmllint --noout "$FILE" 2>/dev/null; then
    echo "❌ ERROR: Invalid XML structure (run xmllint for details)"
    ISSUES=1
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ Flow XML structure looks good"
    
    # Show status if active
    STATUS=$(grep "<status>" "$FILE" | sed 's/.*<status>\(.*\)<\/status>.*/\1/')
    if [ "$STATUS" = "Active" ]; then
        echo "✅ Flow is Active"
    else
        echo "⚠️  Flow status: $STATUS (not Active)"
    fi
    
    exit 0
else
    echo ""
    echo "❌ Flow has validation issues (see above)"
    exit 1
fi
