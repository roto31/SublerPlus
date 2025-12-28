import Foundation

/// Provider priority system for search execution and result ordering
/// Higher priority values execute first and appear first in results
public struct ProviderPriority: Codable, Sendable {
    
    /// Priority values (higher = more important)
    /// Default priorities match Subler-equivalent behavior:
    /// - Local/Subler: 100 (highest - uses file metadata)
    /// - TMDB: 80 (standard movie/TV database)
    /// - TVDB: 70 (TV-focused database)
    /// - TPDB: 60 (adult content)
    /// - AppleTV: 50 (legacy Subler provider)
    /// - iTunesStore: 40 (legacy Subler provider)
    public var priorities: [String: Int]
    
    public init(priorities: [String: Int] = [:]) {
        self.priorities = priorities
    }
    
    /// Get priority for a provider, returning default if not specified
    public func priority(for providerName: String) -> Int {
        // Check exact match first
        if let priority = priorities[providerName] {
            return priority
        }
        
        // Check case-insensitive match
        let lowerName = providerName.lowercased()
        for (key, value) in priorities {
            if key.lowercased() == lowerName {
                return value
            }
        }
        
        // Return default priority based on provider name patterns
        return defaultPriority(for: providerName)
    }
    
    /// Set priority for a provider
    public mutating func setPriority(_ priority: Int, for providerName: String) {
        priorities[providerName] = priority
    }
    
    /// Default priority values matching Subler-equivalent behavior
    public static func defaults() -> ProviderPriority {
        return ProviderPriority(priorities: [
            "Subler": 100,           // Local file metadata (highest)
            "TheMovieDB": 80,        // TMDB
            "TMDB": 80,
            "TheTVDB": 70,           // TVDB
            "TVDB": 70,
            "ThePornDB": 60,         // TPDB
            "TPDB": 60,
            "Apple TV": 50,          // Legacy Subler providers
            "AppleTV": 50,
            "iTunes Store": 40,      // Legacy Subler providers
            "iTunesStore": 40
        ])
    }
    
    /// Get default priority for a provider based on name patterns
    private func defaultPriority(for providerName: String) -> Int {
        let lower = providerName.lowercased()
        
        if lower.contains("subler") || lower.contains("local") {
            return 100
        } else if lower.contains("tmdb") || lower.contains("themoviedb") {
            return 80
        } else if lower.contains("tvdb") || lower.contains("thetvdb") {
            return 70
        } else if lower.contains("tpdb") || lower.contains("theporndb") {
            return 60
        } else if lower.contains("apple") {
            return 50
        } else if lower.contains("itunes") {
            return 40
        }
        
        // Default for unknown providers
        return 50
    }
    
    /// Sort providers by priority (higher priority first)
    public func sortProviders<T>(_ providers: [T], by nameExtractor: (T) -> String) -> [T] {
        return providers.sorted { provider1, provider2 in
            let priority1 = priority(for: nameExtractor(provider1))
            let priority2 = priority(for: nameExtractor(provider2))
            return priority1 > priority2
        }
    }
}

