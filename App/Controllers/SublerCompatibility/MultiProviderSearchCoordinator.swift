#if canImport(MP42Foundation)
import Foundation
import MP42Foundation

/// Multi-provider search coordinator using Subler's Runnable pattern
/// Coordinates searches across multiple MetadataService providers with priority ordering
/// Supports both incremental streaming and batch completion modes
public final class MultiProviderSearchCoordinator {
    
    // MARK: - Properties
    
    private let providers: [MetadataService]
    private let priority: ProviderPriority
    private let includeAdult: Bool
    private let incrementalStreaming: Bool
    
    // MARK: - Initialization
    
    public init(
        providers: [MetadataService],
        priority: ProviderPriority = ProviderPriority.defaults(),
        includeAdult: Bool = false,
        incrementalStreaming: Bool = false
    ) {
        // Filter providers based on adult content setting
        // Note: We can't easily filter MetadataService by adult content,
        // so we rely on the caller to provide pre-filtered list
        self.providers = providers
        self.priority = priority
        self.includeAdult = includeAdult
        self.incrementalStreaming = incrementalStreaming
    }
    
    // MARK: - Movie Search
    
    /// Search movies across multiple providers
    /// - Parameters:
    ///   - query: Movie title to search
    ///   - language: Language code
    ///   - completionHandler: Called with aggregated results
    /// - Returns: Runnable task for cancellation
    public func searchMovie(
        query: String,
        language: String,
        completionHandler: @escaping ([MetadataResult]) -> Void
    ) -> Runnable {
        return search(
            searchType: .movie,
            query: query,
            language: language,
            season: nil,
            episode: nil,
            completionHandler: completionHandler
        )
    }
    
    /// Search movies with incremental callbacks
    /// - Parameters:
    ///   - query: Movie title to search
    ///   - language: Language code
    ///   - providerCallback: Called as each provider completes
    ///   - completionHandler: Called when all providers complete
    /// - Returns: Runnable task for cancellation
    public func searchMovieIncremental(
        query: String,
        language: String,
        providerCallback: @escaping (String, [MetadataResult]) -> Void,
        completionHandler: @escaping ([MetadataResult]) -> Void
    ) -> Runnable {
        return searchIncremental(
            searchType: .movie,
            query: query,
            language: language,
            season: nil,
            episode: nil,
            providerCallback: providerCallback,
            completionHandler: completionHandler
        )
    }
    
    // MARK: - TV Show Search
    
    /// Search TV shows across multiple providers
    /// - Parameters:
    ///   - query: TV show title to search
    ///   - language: Language code
    ///   - season: Optional season number
    ///   - episode: Optional episode number
    ///   - completionHandler: Called with aggregated results
    /// - Returns: Runnable task for cancellation
    public func searchTVShow(
        query: String,
        language: String,
        season: Int? = nil,
        episode: Int? = nil,
        completionHandler: @escaping ([MetadataResult]) -> Void
    ) -> Runnable {
        return search(
            searchType: .tvShow,
            query: query,
            language: language,
            season: season,
            episode: episode,
            completionHandler: completionHandler
        )
    }
    
    /// Search TV shows with incremental callbacks
    /// - Parameters:
    ///   - query: TV show title to search
    ///   - language: Language code
    ///   - season: Optional season number
    ///   - episode: Optional episode number
    ///   - providerCallback: Called as each provider completes
    ///   - completionHandler: Called when all providers complete
    /// - Returns: Runnable task for cancellation
    public func searchTVShowIncremental(
        query: String,
        language: String,
        season: Int? = nil,
        episode: Int? = nil,
        providerCallback: @escaping (String, [MetadataResult]) -> Void,
        completionHandler: @escaping ([MetadataResult]) -> Void
    ) -> Runnable {
        return searchIncremental(
            searchType: .tvShow,
            query: query,
            language: language,
            season: season,
            episode: episode,
            providerCallback: providerCallback,
            completionHandler: completionHandler
        )
    }
    
    // MARK: - Private Implementation
    
    private func search(
        searchType: MetadataType,
        query: String,
        language: String,
        season: Int?,
        episode: Int?,
        completionHandler: @escaping ([MetadataResult]) -> Void
    ) -> Runnable {
        // If incremental streaming is enabled, use incremental version
        if incrementalStreaming {
            return searchIncremental(
                searchType: searchType,
                query: query,
                language: language,
                season: season,
                episode: episode,
                providerCallback: { _, _ in }, // Empty callback for batch mode
                completionHandler: completionHandler
            )
        }
        
        // Batch mode: collect all results, then call completion once
        var allResults: [MetadataResult] = []
        let group = DispatchGroup()
        let resultsLock = NSLock()
        
        // Sort providers by priority (higher priority first)
        let sortedProviders = priority.sortProviders(providers) { $0.name }
        
        for provider in sortedProviders {
            group.enter()
            
            // Create search based on type
            let search: MetadataSearch
            switch searchType {
            case .movie:
                search = MetadataSearch.movieSeach(service: provider, movie: query, language: language)
            case .tvShow:
                search = MetadataSearch.tvSearch(service: provider, tvShow: query, season: season, episode: episode, language: language)
            }
            
            // Execute search
            let task = search.search { results in
                resultsLock.lock()
                defer { resultsLock.unlock() }
                
                // Add results (priority ordering will be applied later)
                allResults.append(contentsOf: results)
                group.leave()
            }.runAsync()
            
            // Store task for potential cancellation (simplified - full implementation would track all tasks)
            _ = task
        }
        
        // Wait for all providers and call completion
        DispatchQueue.global().async {
            group.wait()
            
            resultsLock.lock()
            let finalResults = allResults
            resultsLock.unlock()
            
            // Sort results by priority
            let sortedResults = priority.sortSublerResults(finalResults)
            
            // Call completion on main thread (matching Subler's pattern)
            DispatchQueue.main.async {
                completionHandler(sortedResults)
            }
        }
        
        // Return a cancellable wrapper
        return BatchSearchRunnable(group: group, providers: sortedProviders)
    }
    
    private func searchIncremental(
        searchType: MetadataType,
        query: String,
        language: String,
        season: Int?,
        episode: Int?,
        providerCallback: @escaping (String, [MetadataResult]) -> Void,
        completionHandler: @escaping ([MetadataResult]) -> Void
    ) -> Runnable {
        // Use IncrementalRunnableTask for incremental streaming
        let task = IncrementalRunnableTask(
            providers: providers,
            searchType: searchType,
            query: query,
            language: language,
            season: season,
            episode: episode,
            priority: priority,
            includeAdult: includeAdult
        )
        
        return task.runAsyncIncremental(
            providerCallback: providerCallback,
            completionHandler: completionHandler
        )
    }
}

// MARK: - Batch Search Runnable Wrapper

/// Simple Runnable wrapper for batch searches
private final class BatchSearchRunnable: Runnable {
    private let group: DispatchGroup
    private let providers: [MetadataService]
    private var cancelled: Bool = false
    private let queue = DispatchQueue(label: "BatchSearchRunnable")
    
    init(group: DispatchGroup, providers: [MetadataService]) {
        self.group = group
        self.providers = providers
    }
    
    @discardableResult
    func runAsync() -> Runnable {
        // Already running
        return self
    }
    
    @discardableResult
    func run() -> Runnable {
        return runAsync()
    }
    
    func cancel() {
        queue.sync {
            cancelled = true
        }
        // Note: Individual provider tasks would need to be cancelled
        // This is a simplified implementation
    }
}


#endif
