import Foundation

/// Cache key for search results, based on normalized search parameters
public struct SearchCacheKey: Hashable {
    let query: String
    let type: UnifiedSearchManager.SearchType
    let language: String?
    let providerName: String?
    let yearHint: Int?
    let includeAdult: Bool
    
    /// Normalize query for consistent caching (lowercase, trimmed)
    public init(query: String, type: UnifiedSearchManager.SearchType, language: String? = nil, providerName: String? = nil, yearHint: Int? = nil, includeAdult: Bool = false) {
        self.query = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.language = language?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.providerName = providerName
        self.yearHint = yearHint
        self.includeAdult = includeAdult
    }
}

/// Cache entry storing search results and timestamp
private struct SearchCacheEntry {
    let results: [MetadataResult]
    let timestamp: Date
    
    init(results: [MetadataResult]) {
        self.results = results
        self.timestamp = Date()
    }
}

/// Actor-based cache manager for search results (session-only, in-memory)
public actor SearchCacheManager {
    private var cache: [SearchCacheKey: SearchCacheEntry] = [:]
    private let maxEntries: Int
    private var accessOrder: [SearchCacheKey] = [] // For LRU eviction
    
    public init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }
    
    /// Get cached results for a search key
    public func get(key: SearchCacheKey) -> [MetadataResult]? {
        guard let entry = cache[key] else {
            return nil
        }
        
        // Update access order for LRU
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        
        return entry.results
    }
    
    /// Store search results in cache
    public func set(key: SearchCacheKey, results: [MetadataResult]) {
        // Remove oldest entry if at capacity
        if cache.count >= maxEntries && !cache.keys.contains(key) {
            evictOldest()
        }
        
        cache[key] = SearchCacheEntry(results: results)
        
        // Update access order
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    /// Remove a specific cache entry
    public func remove(key: SearchCacheKey) {
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }
    
    /// Clear all cached entries
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    /// Get current cache size
    public func size() -> Int {
        cache.count
    }
    
    /// Evict the least recently used entry
    private func evictOldest() {
        if let oldestKey = accessOrder.first {
            cache.removeValue(forKey: oldestKey)
            accessOrder.removeFirst()
        }
    }
}

