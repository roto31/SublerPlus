# Keychain Migration Guide - Removing Authentication Prompts

## Problem

After updating to version 0.3.7b, you may still see Keychain authentication prompts on launch. This happens because existing Keychain items were created with a different accessibility setting that requires authentication.

## Solution

The app now uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` which doesn't require authentication prompts. However, existing items need to be recreated with this setting.

## Automatic Migration

The app will automatically attempt to handle old items, but if prompts persist, follow these steps:

### Option 1: Manual Keychain Cleanup (Recommended)

1. **Open Keychain Access**:
   - Press `Cmd + Space` to open Spotlight
   - Type "Keychain Access" and press Enter
   - Or go to **Applications** > **Utilities** > **Keychain Access**

2. **Find SublerPlus Items**:
   - Select **login** keychain in the left sidebar
   - In the search box (top right), type: `SublerPlus`
   - This will show all SublerPlus Keychain items

3. **Delete Old Items**:
   - Select all items matching "SublerPlus"
   - Right-click and choose **Delete** or press `Delete`
   - Confirm the deletion

4. **Re-enter API Keys**:
   - Launch SublerPlus
   - Go to **Settings** (⌘,)
   - Re-enter your API keys
   - They will be saved with the new accessibility settings (no prompts)

### Option 2: Reset All Keys via Settings

1. **Launch SublerPlus**
2. **Open Settings** (⌘,)
3. **Clear all API keys** (delete the values)
4. **Save Settings**
5. **Re-enter your API keys**
6. **Save again**

The keys will be recreated with the correct accessibility settings.

### Option 3: Use Environment Variables (Temporary)

If you want to avoid Keychain entirely for now:

1. **Set environment variables** before launching:
   ```bash
   export TPDB_API_KEY="your-key"
   export TMDB_API_KEY="your-key"
   export TVDB_API_KEY="your-key"
   export OPENSUBTITLES_API_KEY="your-key"
   export WEBUI_TOKEN="your-token"
   ```

2. **Launch from terminal**:
   ```bash
   cd "/path/to/SublerPlus/build"
   ./SublerPlus.app/Contents/MacOS/SublerPlusApp
   ```

## Why This Happens

- **Old items**: Created with `kSecAttrAccessibleAfterFirstUnlock` or `kSecAttrAccessibleWhenUnlocked`
- **New items**: Created with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Difference**: Old items require Keychain to be unlocked, which may prompt for password
- **Solution**: New items are accessible without prompts once device is unlocked

## Verification

After migration:
1. ✅ Launch app - no Keychain prompt appears
2. ✅ API keys work correctly
3. ✅ Keys are stored securely in Keychain
4. ✅ No authentication required on subsequent launches

## Technical Details

### Accessibility Settings

- **Old**: `kSecAttrAccessibleAfterFirstUnlock`
  - Accessible after first unlock, but may prompt
  - Synced to iCloud Keychain
  
- **New**: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  - Accessible when device is unlocked (no prompts)
  - Device-only (not synced to iCloud)
  - More secure for API keys (local only)

### Migration Logic

The app now:
1. Checks cache first (avoids Keychain access)
2. If cache miss, reads from Keychain
3. If `errSecAuthFailed`, attempts to delete old item
4. Next `set()` recreates with correct settings
5. Caches values to avoid repeated Keychain access

---

**Last Updated**: 2025-12-27  
**Version**: 0.3.7b

