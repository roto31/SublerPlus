import Foundation
import Security

public final class KeychainController: APIKeyStore {
    private let service = "SublerPlus"
    
    // In-memory cache to avoid repeated Keychain access
    private var cache: [String: String?] = [:]
    private let cacheQueue = DispatchQueue(label: "com.sublerplus.keychain.cache")
    
    // Track which keys we've attempted to migrate
    private var migrationAttempted: Set<String> = []

    public init() {}
    
    /// Delete and recreate an existing Keychain item to update its accessibility settings
    /// This is called when we detect an item exists but requires authentication
    private func migrateItem(key: String) {
        guard !migrationAttempted.contains(key) else { return }
        migrationAttempted.insert(key)
        
        // Try to read the old item with minimal query (no data return)
        let checkQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: false,  // Just check if it exists
            kSecReturnAttributes: false
        ]
        
        var checkResult: CFTypeRef?
        let checkStatus = SecItemCopyMatching(checkQuery as CFDictionary, &checkResult)
        
        // If item exists, try to delete it (this might fail if it requires auth, but we try)
        if checkStatus == errSecSuccess {
            let deleteQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key
            ]
            _ = SecItemDelete(deleteQuery as CFDictionary)
        }
    }

    public func set(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        // Always delete first to ensure we create with correct accessibility settings
        SecItemDelete(query as CFDictionary)
        
        let insert: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(insert as CFDictionary, nil)
        
        // Update cache on successful save
        if status == errSecSuccess {
            cacheQueue.sync {
                cache[key] = value
            }
        }
    }

    public func get(key: String) -> String? {
        // Check cache first to avoid Keychain access
        return cacheQueue.sync {
            // Check if we've cached this key (including nil values to avoid repeated Keychain lookups)
            if let cachedValue = cache[key] {
                return cachedValue
            }
            
            // Not in cache - read from Keychain
            // Use kSecAttrAccessibleWhenUnlockedThisDeviceOnly which doesn't require authentication prompts
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key,
                kSecReturnData: true
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            
            switch status {
            case errSecSuccess:
                guard let data = item as? Data,
                      let value = String(data: data, encoding: .utf8) else {
                    cache[key] = nil
                    return nil
                }
                // Cache the value for future access
                cache[key] = value
                return value
            case errSecItemNotFound:
                // Key doesn't exist - cache nil to avoid repeated Keychain lookups
                cache[key] = nil
                return nil
            case errSecAuthFailed:
                // Item exists but requires authentication (old item with wrong accessibility)
                // Try to migrate it (delete and let next set() recreate it)
                migrationAttempted.remove(key) // Allow retry
                migrateItem(key: key)
                // Don't cache - return nil so app can work without the key
                // User will need to re-enter the key in Settings
                return nil
            case errSecInteractionNotAllowed:
                // UI blocked - return nil to avoid prompts
                return nil
            default:
                // For any other error, return nil silently
                return nil
            }
        }
    }

    public func remove(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        
        // Remove from cache on successful delete
        if status == errSecSuccess || status == errSecItemNotFound {
            cacheQueue.sync {
                cache.removeValue(forKey: key)
                migrationAttempted.remove(key)
            }
        }
    }
    
    /// Clear all cached values and migration state
    public func clearCache() {
        cacheQueue.sync {
            cache.removeAll()
            migrationAttempted.removeAll()
        }
    }
}
