#!/bin/bash
# Finds SOQL queries in Apex files that are missing WITH SECURITY_ENFORCED

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-apex-class-or-directory>"
    echo "Example: $0 force-app/main/default/classes/"
    echo "Example: $0 force-app/main/default/classes/MyClass.cls"
    exit 1
fi

TARGET="$1"

if [ ! -e "$TARGET" ]; then
    echo "❌ ERROR: Path not found: $TARGET"
    exit 1
fi

# Find all .cls files in target
if [ -d "$TARGET" ]; then
    FILES=$(find "$TARGET" -name "*.cls")
else
    FILES="$TARGET"
fi

FOUND_ISSUES=0

for FILE in $FILES; do
    # Extract SOQL queries (simplified - catches most cases)
    # Look for [SELECT ... FROM but not WITH SECURITY_ENFORCED in the same block
    
    # First check if file has any SOQL
    if ! grep -qi "SELECT.*FROM" "$FILE"; then
        continue
    fi
    
    # Extract query blocks (multi-line aware is hard in bash, so this is approximate)
    # Look for lines with SELECT that don't have WITH SECURITY_ENFORCED nearby
    QUERIES=$(grep -n "SELECT.*FROM" "$FILE" | grep -iv "WITH SECURITY_ENFORCED" | grep -iv "WITH USER_MODE")
    
    if [ -n "$QUERIES" ]; then
        if [ $FOUND_ISSUES -eq 0 ]; then
            echo "⚠️  SOQL queries without security enforcement found:"
            echo ""
        fi
        
        echo "📄 $FILE"
        echo "$QUERIES" | while read -r LINE; do
            LINE_NUM=$(echo "$LINE" | cut -d: -f1)
            QUERY=$(echo "$LINE" | cut -d: -f2-)
            echo "  Line $LINE_NUM: $QUERY"
        done
        echo ""
        
        FOUND_ISSUES=1
    fi
done

if [ $FOUND_ISSUES -eq 0 ]; then
    echo "✅ All SOQL queries have security enforcement"
    exit 0
else
    echo "❌ Add 'WITH SECURITY_ENFORCED' or 'WITH USER_MODE' to queries above"
    exit 1
fi
