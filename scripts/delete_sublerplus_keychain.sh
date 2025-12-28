#!/bin/bash
# Delete SublerPlus Keychain items using security command-line tool
# This avoids authentication prompts by using the security CLI

echo "Deleting SublerPlus Keychain items..."

# List of known API keys
KEYS=("tpdb" "tmdb" "tvdb" "opensubtitles" "webui_token")

DELETED=0
for key in "${KEYS[@]}"; do
    if security delete-generic-password -s "SublerPlus" -a "$key" 2>/dev/null; then
        echo "✅ Deleted: $key"
        ((DELETED++))
    else
        echo "ℹ️  Not found: $key (may not exist)"
    fi
done

echo ""
if [ $DELETED -gt 0 ]; then
    echo "✅ Deleted $DELETED Keychain item(s)"
    echo ""
    echo "Next steps:"
    echo "1. Launch SublerPlus"
    echo "2. Go to Settings (⌘,)"
    echo "3. Re-enter your API keys"
    echo "4. They will be saved with new settings (no prompts)"
else
    echo "ℹ️  No SublerPlus Keychain items found to delete"
    echo "   Your keys may already be using the new settings"
fi

