#!/bin/bash
# Auto-configuration helper for Salesforce Claude skills
# Called by the salesforce-install skill

set -e

echo "🔧 Salesforce Skills Auto-Configuration"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check sf CLI
if ! command -v sf &> /dev/null; then
    echo "❌ Salesforce CLI (sf) not found"
    echo "Install: brew install sf"
    exit 1
fi
echo "✅ Salesforce CLI: $(sf --version | head -1)"

# Check for authenticated orgs
ORG_COUNT=$(sf org list --json 2>/dev/null | jq -r '.result.nonScratchOrgs | length' || echo "0")
if [ "$ORG_COUNT" -eq 0 ]; then
    echo "❌ No authenticated Salesforce orgs found"
    echo "Authenticate: sf org login web --alias YOUR_ORG_NAME"
    exit 1
fi
echo "✅ Found $ORG_COUNT authenticated org(s)"

# List orgs
echo ""
echo "Available orgs:"
sf org list --json | jq -r '.result.nonScratchOrgs[] | "  - \(.alias // .username) (\(.instanceUrl))"'

echo ""
echo "This script requires Claude Code to run interactively."
echo "Please use the salesforce-install skill instead:"
echo ""
echo "  \"Use the salesforce-install skill to configure for my org\""
echo ""
exit 0
