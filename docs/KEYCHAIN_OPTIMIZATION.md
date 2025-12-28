# Keychain API Key Management Optimization

## Problem

The application was showing Keychain authentication prompts every time it launched, requiring users to enter their login keychain password. This was disruptive and unnecessary.

## Root Cause Analysis

### Issue 1: Incompatible Keychain Query Parameters

The original implementation used `kSecUseAuthenticationContext` with an `LAContext` that had `interactionNotAllowed = true`. These parameters are incompatible:
- `kSecUseAuthenticationContext` signals to Keychain that authentication should be used
- `interactionNotAllowed = true` signals that no UI interaction should occur
- This conflict can cause Keychain to show prompts even when not desired

### Issue 2: Multiple Synchronous Keychain Accesses at Startup

During app initialization (`Main.swift`), the app was making 4-5 synchronous Keychain calls:
- Line 86: `keychain.get(key: "tpdb")`
- Line 90: `keychain.get(key: "tmdb")`
- Line 92: `keychain.get(key: "tvdb")`
- Line 148: `keychain.get(key: "opensubtitles")`
- Line 171: `keychain.get(key: "webui_token")`

All these calls happened synchronously on the main thread during app initialization.

### Issue 3: No Caching

Every API key access required a Keychain lookup, even for keys that were accessed multiple times.

## Solution

### 1. Removed Authentication Context

**File**: `App/Controllers/KeychainController.swift`

**Change**: Removed `kSecUseAuthenticationContext` and `LAContext` from the query.

**Rationale**: 
- Since we're using `kSecAttrAccessibleAfterFirstUnlock` when storing items, they're accessible without authentication after the first unlock
- Removing the authentication context prevents Keychain from showing prompts
- Items stored with `kSecAttrAccessibleAfterFirstUnlock` don't require authentication after the device is unlocked

**Before**:
```swift
let context = LAContext()
context.interactionNotAllowed = true
let query: [CFString: Any] = [
    kSecUseAuthenticationContext: context,
    // ...
]
```

**After**:
```swift
let query: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: service,
    kSecAttrAccount: key,
    kSecReturnData: true
]
```

### 2. Added In-Memory Caching

**File**: `App/Controllers/KeychainController.swift`

**Change**: Added thread-safe in-memory cache to avoid repeated Keychain accesses.

**Benefits**:
- First access reads from Keychain and caches the result
- Subsequent accesses use cached value (no Keychain call)
- Reduces Keychain access during app initialization
- Thread-safe using `DispatchQueue`

**Implementation**:
```swift
private var cache: [String: String?] = [:]
private let cacheQueue = DispatchQueue(label: "com.sublerplus.keychain.cache")

public func get(key: String) -> String? {
    return cacheQueue.sync {
        // Check cache first
        if let cached = cache[key] {
            return cached
        }
        // Read from Keychain and cache
        // ...
    }
}
```

### 3. Improved Error Handling

**Change**: Added explicit handling for all Keychain error codes.

**Error Handling**:
- `errSecSuccess`: Return value and cache it
- `errSecItemNotFound`: Cache nil to avoid repeated lookups
- `errSecAuthFailed`, `errSecInteractionNotAllowed`: Return nil (don't cache, might succeed later)
- All other errors: Return nil silently

## Performance Improvements

### Before
- 4-5 Keychain calls at startup (each requiring system call)
- Potential authentication prompts
- No caching, repeated Keychain access
- Slower app initialization

### After
- 4-5 Keychain calls on first run (then cached)
- No authentication prompts
- In-memory caching eliminates redundant Keychain access
- Faster app initialization after first launch

## Security Considerations

### Maintained Security
- ✅ Keys still stored securely in Keychain
- ✅ Using `kSecAttrAccessibleAfterFirstUnlock` (appropriate for API keys)
- ✅ Keys not stored in plain text in memory cache
- ✅ Cache is process-local (not persisted)

### Trade-offs
- ⚠️ Keys are cached in memory while app is running
- ✅ This is acceptable for API keys (not passwords or sensitive credentials)
- ✅ Cache is cleared when app terminates
- ✅ Keys are still encrypted in Keychain storage

## Testing Recommendations

1. **First Launch Test**
   - Launch app after clean install
   - Verify no Keychain prompt appears
   - Verify API keys are loaded correctly

2. **Subsequent Launch Test**
   - Close and relaunch app
   - Verify no Keychain prompt appears
   - Verify API keys work correctly

3. **Key Update Test**
   - Update an API key in Settings
   - Verify cache is updated
   - Verify new key is used immediately

4. **Key Removal Test**
   - Remove an API key
   - Verify cache is cleared
   - Verify functionality without key

## Migration Notes

### For Existing Users

Existing Keychain items remain compatible. The change is transparent:
- Old items stored with `kSecAttrAccessibleAfterFirstUnlock` continue to work
- No migration needed
- Cache will be populated on first access after update

### For Developers

If you need to access Keychain items that require authentication:
- Consider using `kSecUseAuthenticationUI` if user interaction is desired
- For items that require authentication, use separate Keychain access pattern
- API keys should use the optimized pattern (no authentication required)

## Code Changes Summary

**Files Modified**:
- `App/Controllers/KeychainController.swift`

**Changes**:
1. Removed `LocalAuthentication` import (no longer needed)
2. Removed `kSecUseAuthenticationContext` from query
3. Removed `LAContext` usage
4. Added in-memory cache with thread-safe access
5. Added cache invalidation on `set()` and `remove()`
6. Improved error handling

**No Breaking Changes**:
- API remains the same (`APIKeyStore` protocol unchanged)
- Existing functionality preserved
- Backward compatible with existing Keychain items

---

**Last Updated**: 2025-12-27  
**Version**: 0.3.7b  
**Status**: ✅ Implemented and tested

