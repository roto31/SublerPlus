import Foundation
import os.log

/// Unified search manager that coordinates modern MetadataProvider instances
/// Provides weighted search results with caching support
/// 
/// Threading: All network operations run off the main thread. UI updates must be
/// performed on MainActor by the caller.
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
    private let logger = AppLog.providers
    
    // MARK: - Initialization
    
    public init(modernProviders: [MetadataProvider], includeAdult: Bool = false, searchCache: SearchCacheManager? = nil, providerWeights: ProviderWeights = ProviderWeights.defaults()) {
        self.modernProviders = modernProviders
        self.includeAdult = includeAdult
        self.searchCache = searchCache
        self.providerWeights = providerWeights
        
        AppLog.info(logger, "UnifiedSearchManager initialized with \(modernProviders.count) providers, adult=\(includeAdult)")
    }
    
    // MARK: - Unified Search
    
    /// Performs a unified search across modern providers
    /// 
    /// - Parameters:
    ///   - options: Search options including query, type, and filters
    /// - Returns: Sorted and deduplicated search results
    /// - Throws: SearchError if no providers available or search fails
    /// 
    /// Threading: This method runs off the main thread. Network calls execute concurrently.
    public func search(options: SearchOptions) async throws -> [MetadataResult] {
        let startTime = Date()
        AppLog.info(logger, "Search started: query='\(options.query)', type=\(options.type), providers=\(modernProviders.count)")
        
        // Validate providers are available
        let filteredProviders = modernProviders.filter { includeAdult || !$0.isAdult }
        guard !filteredProviders.isEmpty else {
            let error = SearchError.noProvidersAvailable
            AppLog.error(logger, "Search failed: \(error.localizedDescription)")
            throw error
        }
        
        AppLog.info(logger, "Filtered to \(filteredProviders.count) providers (adult filtering: \(!includeAdult))")
        
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
            let duration = Date().timeIntervalSince(startTime)
            AppLog.info(logger, "Search cache hit: \(cachedResults.count) results in \(String(format: "%.3f", duration))s")
            return cachedResults
        }
        
        AppLog.info(logger, "Search cache miss, querying providers...")
        
        // Cache miss - perform actual search
        // Execute provider searches concurrently for performance
        let modernResults = try await searchModernProviders(
            options: options,
            providers: filteredProviders
        )
        
        // Sort and deduplicate results with provider weights
        let sortedResults = sortAndDeduplicate(
            results: modernResults,
            yearHint: options.yearHint,
            weights: providerWeights
        )
        
        // Store in cache
        if let cache = searchCache {
            await cache.set(key: cacheKey, results: sortedResults)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        AppLog.info(logger, "Search completed: \(sortedResults.count) results in \(String(format: "%.3f", duration))s")
        
        return sortedResults
    }
    
    // MARK: - Modern Provider Search
    
    /// Searches modern providers concurrently
    /// 
    /// - Parameters:
    ///   - options: Search options
    ///   - providers: Filtered list of providers to search
    /// - Returns: Combined results from all providers
    /// - Throws: SearchError if all providers fail
    /// 
    /// Threading: Network calls execute concurrently on background threads
    private func searchModernProviders(
        options: SearchOptions,
        providers: [MetadataProvider]
    ) async throws -> [MetadataResult] {
        // Create concurrent tasks for all providers
        let tasks = providers.map { provider in
            Task { () -> (providerID: String, results: [MetadataResult], error: Error?) in
                let providerID = provider.id
                AppLog.info(logger, "Provider '\(providerID)' search started")
                let providerStartTime = Date()
                
                do {
                    // Check for cancellation before starting
                    try Task.checkCancellation()
                    
                    let results = try await provider.search(query: options.query)
                    
                    let duration = Date().timeIntervalSince(providerStartTime)
                    AppLog.info(logger, "Provider '\(providerID)' completed: \(results.count) results in \(String(format: "%.3f", duration))s")
                    
                    return (providerID: providerID, results: results, error: nil)
                } catch is CancellationError {
                    AppLog.info(logger, "Provider '\(providerID)' search cancelled")
                    throw CancellationError()
                } catch {
                    let duration = Date().timeIntervalSince(providerStartTime)
                    AppLog.error(logger, "Provider '\(providerID)' failed after \(String(format: "%.3f", duration))s: \(error.localizedDescription)")
                    return (providerID: providerID, results: [], error: error)
                }
            }
        }
        
        // Collect results from all tasks
        var allResults: [MetadataResult] = []
        var providerErrors: [String: Error] = [:]
        
        for task in tasks {
            do {
                let (providerID, results, error) = try await task.value
                allResults.append(contentsOf: results)
                if let error = error {
                    providerErrors[providerID] = error
                }
            } catch is CancellationError {
                // Task was cancelled, skip it
                continue
            } catch {
                // Unexpected error, log and continue
                AppLog.error(logger, "Unexpected error collecting provider results: \(error.localizedDescription)")
            }
        }
        
        // If all providers failed, throw an error
        if allResults.isEmpty && !providerErrors.isEmpty {
            let errorMessages = providerErrors.map { "\($0.key): \($0.value.localizedDescription)" }.joined(separator: "; ")
            throw SearchError.allProvidersFailed(errorMessages)
        }
        
        return allResults
    }
    
    // MARK: - Result Sorting and Deduplication
    
    /// Sorts and deduplicates search results with provider weight boosting
    private func sortAndDeduplicate(
        results: [MetadataResult],
        yearHint: Int?,
        weights: ProviderWeights
    ) -> [MetadataResult] {
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
        
        AppLog.info(logger, "Deduplicated \(results.count) results to \(unique.count) unique results")
        
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
        AppLog.info(logger, "Fetching details for result: id=\(result.id), source=\(result.source ?? "unknown")")
        
        // Try modern providers
        if let modernProvider = modernProviders.first(where: { $0.id == result.source }) {
            do {
                let details = try await modernProvider.fetchDetails(for: result.id)
                AppLog.info(logger, "Details fetched successfully for \(result.id)")
                return details
            } catch {
                AppLog.error(logger, "Failed to fetch details for \(result.id): \(error.localizedDescription)")
                throw error
            }
        }
        
        let error = SearchError.providerNotFound(result.source ?? "unknown")
        AppLog.error(logger, "Provider not found for result: \(result.source ?? "unknown")")
        throw error
    }
    
    // MARK: - Available Providers
    
    public var availableProviders: [String] {
        return modernProviders.map { $0.id }.sorted()
    }
    
    /// Returns count of available providers after adult filtering
    public var availableProviderCount: Int {
        modernProviders.filter { includeAdult || !$0.isAdult }.count
    }
}

// MARK: - Errors

public enum SearchError: LocalizedError {
    case providerNotFound(String)
    case noProvidersAvailable
    case allProvidersFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .providerNotFound(let name):
            return "Search provider '\(name)' not found"
        case .noProvidersAvailable:
            return "No search providers available. Please configure API keys in Settings."
        case .allProvidersFailed(let details):
            return "All search providers failed: \(details)"
        }
    }
}
