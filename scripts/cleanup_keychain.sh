#!/bin/bash
# Script to clean up old SublerPlus Keychain items
# This removes items that require authentication prompts

echo "=========================================="
echo "SublerPlus Keychain Cleanup Script"
echo "=========================================="
echo ""
echo "This script will delete old SublerPlus Keychain items"
echo "that may cause authentication prompts."
echo ""
echo "You will need to:"
echo "1. Re-enter your API keys in SublerPlus Settings after cleanup"
echo "2. The app will save them with the new settings (no prompts)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Opening Keychain Access..."
echo "Please follow these steps:"
echo ""
echo "1. In Keychain Access, select 'login' keychain"
echo "2. Search for 'SublerPlus' in the search box"
echo "3. Select ALL items that appear (Cmd+A)"
echo "4. Press Delete and confirm"
echo "5. Close Keychain Access"
echo "6. Re-enter your API keys in SublerPlus Settings"
echo ""
open -a "Keychain Access"
