import Foundation

/// Unified search manager that coordinates modern MetadataProvider instances
/// Provides weighted search results with caching support
@MainActor
public final class UnifiedSearchManager {
    
    // MARK: - Types
    
    public enum SearchType: Hashable {
        case movie
        case tvShow(season: Int?, episode: Int?)
    }
    
    public struct SearchOptions {
        public let query: String
        public let type: SearchType
        public let language: String?
        public let providerName: String?
        public let yearHint: Int?
        
        public init(query: String, type: SearchType, language: String? = nil, providerName: String? = nil, yearHint: Int? = nil) {
            self.query = query
            self.type = type
            self.language = language
            self.providerName = providerName
            self.yearHint = yearHint
        }
    }
    
    // MARK: - Properties
    
    private let modernProviders: [MetadataProvider]
    private let includeAdult: Bool
    private let searchCache: SearchCacheManager?
    private let providerWeights: ProviderWeights
    
    // MARK: - Initialization
    
    public init(modernProviders: [MetadataProvider], includeAdult: Bool = false, searchCache: SearchCacheManager? = nil, providerWeights: ProviderWeights = ProviderWeights.defaults()) {
        self.modernProviders = modernProviders
        self.includeAdult = includeAdult
        self.searchCache = searchCache
        self.providerWeights = providerWeights
    }
    
    // MARK: - Unified Search
    
    /// Performs a unified search across both modern and legacy providers
    public func search(options: SearchOptions) async throws -> [MetadataResult] {
        // Create cache key from options
        let cacheKey = SearchCacheKey(
            query: options.query,
            type: options.type,
            language: options.language,
            providerName: options.providerName,
            yearHint: options.yearHint,
            includeAdult: includeAdult
        )
        
        // Check cache first
        if let cache = searchCache, let cachedResults = await cache.get(key: cacheKey) {
            return cachedResults
        }
        
        // Cache miss - perform actual search
        // Search modern providers only
        let modernResults = await searchModernProviders(options: options)
        
        // Sort and deduplicate results with provider weights
        let sortedResults = sortAndDeduplicate(results: modernResults, yearHint: options.yearHint, weights: providerWeights)
        
        // Store in cache
        if let cache = searchCache {
            await cache.set(key: cacheKey, results: sortedResults)
        }
        
        return sortedResults
    }
    
    // MARK: - Modern Provider Search
    
    private func searchModernProviders(options: SearchOptions) async -> [MetadataResult] {
        let filteredProviders = modernProviders.filter { includeAdult || !$0.isAdult }
        
        let tasks = filteredProviders.map { provider in
            Task { () -> [MetadataResult] in
                do {
                    return try await provider.search(query: options.query)
                } catch {
                    return []
                }
            }
        }
        
        var results: [MetadataResult] = []
        for task in tasks {
            let providerResults = await task.value
            results.append(contentsOf: providerResults)
        }
        
        return results
    }
    
    // MARK: - Result Sorting and Deduplication
    
    private func sortAndDeduplicate(results: [MetadataResult], yearHint: Int?, weights: ProviderWeights) -> [MetadataResult] {
        // Deduplicate by ID and title
        var seen: Set<String> = []
        var unique: [MetadataResult] = []
        
        for result in results {
            let key = "\(result.id)-\(result.title)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(result)
            }
        }
        
        // Sort by adjusted score (with provider weight boost), then by year proximity if year hint provided
        return unique.sorted { lhs, rhs in
            // Apply provider weight boost to scores
            let lhsProviderID = lhs.source ?? ""
            let rhsProviderID = rhs.source ?? ""
            let lhsWeight = weights.weight(for: lhsProviderID)
            let rhsWeight = weights.weight(for: rhsProviderID)
            
            let lhsScore = (lhs.score ?? 0) * lhsWeight
            let rhsScore = (rhs.score ?? 0) * rhsWeight
            
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            
            // If scores are equal and year hint provided, prefer closer year
            if let hint = yearHint {
                if let ly = lhs.year, let ry = rhs.year {
                    return abs(hint - ly) < abs(hint - ry)
                }
            }
            
            // Fallback: prefer results with years
            if lhs.year != nil && rhs.year == nil {
                return true
            }
            if lhs.year == nil && rhs.year != nil {
                return false
            }
            
            // Final fallback: alphabetical
            return lhs.title < rhs.title
        }
    }
    
    // MARK: - Fetch Details
    
    /// Fetches detailed metadata for a result using modern providers
    public func fetchDetails(for result: MetadataResult) async throws -> MetadataDetails {
        // Try modern providers
        if let modernProvider = modernProviders.first(where: { $0.id == result.source }) {
            return try await modernProvider.fetchDetails(for: result.id)
        }
        
        throw SearchError.providerNotFound(result.source ?? "unknown")
    }
    
    // MARK: - Available Providers
    
    public var availableProviders: [String] {
        return modernProviders.map { $0.id }.sorted()
    }
}

// MARK: - Errors

public enum SearchError: LocalizedError {
    case providerNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .providerNotFound(let name):
            return "Search provider '\(name)' not found"
        }
    }
}

