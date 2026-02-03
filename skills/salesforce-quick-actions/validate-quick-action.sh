#!/bin/bash
# Validates that a quick action has the required <targetObject> element

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-quickAction-meta.xml>"
    echo "Example: $0 force-app/main/default/objects/Case/quickActions/MyAction.quickAction-meta.xml"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "❌ ERROR: File not found: $FILE"
    exit 1
fi

# Check if it's a QuickAction file
if ! grep -q "QuickAction xmlns" "$FILE"; then
    echo "❌ ERROR: Not a valid QuickAction file (missing QuickAction xmlns)"
    exit 1
fi

# Check for <targetObject>
if grep -q "<targetObject>" "$FILE"; then
    TARGET=$(grep "<targetObject>" "$FILE" | sed 's/.*<targetObject>\(.*\)<\/targetObject>.*/\1/')
    echo "✅ VALID: Object-scoped quick action (targetObject: $TARGET)"
    exit 0
else
    echo "❌ INVALID: Missing <targetObject> element"
    echo ""
    echo "This quick action is GLOBAL and won't work on flexipages."
    echo "Add this element after <optionsCreateFeedItem>:"
    echo "  <targetObject>YourObjectName</targetObject>"
    exit 1
fi
