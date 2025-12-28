#if canImport(MP42Foundation)
import Foundation
import MP42Foundation

/// Runnable that supports incremental callbacks as providers complete
/// This extends Subler's Runnable pattern to support streaming results
public protocol IncrementalRunnable: Runnable {
    /// Run asynchronously with incremental callbacks
    /// - Parameters:
    ///   - providerCallback: Called as each provider completes with (providerName, results)
    ///   - completionHandler: Called when all providers complete with final aggregated results
    /// - Returns: Self for chaining
    @discardableResult
    func runAsyncIncremental(
        providerCallback: @escaping (String, [MetadataResult]) -> Void,
        completionHandler: @escaping ([MetadataResult]) -> Void
    ) -> Runnable
}

/// Task that executes multiple provider searches and calls incremental callbacks
/// Uses Subler's Runnable pattern internally
public final class IncrementalRunnableTask: IncrementalRunnable {
    
    private let providers: [MetadataService]
    private let searchType: MetadataType
    private let query: String
    private let language: String
    private let season: Int?
    private let episode: Int?
    private let priority: ProviderPriority
    private let includeAdult: Bool
    
    private var cancelled: Bool = false
    private let queue: DispatchQueue
    private var activeTasks: [Runnable] = []
    
    public init(
        providers: [MetadataService],
        searchType: MetadataType,
        query: String,
        language: String,
        season: Int? = nil,
        episode: Int? = nil,
        priority: ProviderPriority,
        includeAdult: Bool = false
    ) {
        self.providers = providers
        self.searchType = searchType
        self.query = query
        self.language = language
        self.season = season
        self.episode = episode
        self.priority = priority
        self.includeAdult = includeAdult
        self.queue = DispatchQueue(label: "IncrementalSearchTaskQueue")
    }
    
    // MARK: - Runnable Protocol
    
    @discardableResult
    public func runAsync() -> Runnable {
        // For batch mode, collect all results and call completion once
        var allResults: [MetadataResult] = []
        let group = DispatchGroup()
        
        // Sort providers by priority
        let sortedProviders = priority.sortProviders(providers) { $0.name }
        
        for provider in sortedProviders {
            // Filter adult content if needed
            if !includeAdult {
                // Check if provider is adult (would need to be tracked)
                // For now, we'll rely on the filtering done before creating this task
            }
            
            group.enter()
            let search: MetadataSearch
            switch searchType {
            case .movie:
                search = MetadataSearch.movieSeach(service: provider, movie: query, language: language)
            case .tvShow:
                search = MetadataSearch.tvSearch(service: provider, tvShow: query, season: season, episode: episode, language: language)
            }
            
            let task = search.search { results in
                self.queue.sync {
                    if !self.cancelled {
                        allResults.append(contentsOf: results)
                    }
                }
                group.leave()
            }.runAsync()
            
            queue.sync {
                activeTasks.append(task)
            }
        }
        
        // Wait for all providers (in background)
        DispatchQueue.global().async {
            group.wait()
            // Completion handled by incremental version
        }
        
        return self
    }
    
    @discardableResult
    public func run() -> Runnable {
        return runAsync()
    }
    
    public func cancel() {
        queue.sync {
            cancelled = true
            for task in activeTasks {
                task.cancel()
            }
            activeTasks.removeAll()
        }
    }
    
    // MARK: - IncrementalRunnable Protocol
    
    @discardableResult
    public func runAsyncIncremental(
        providerCallback: @escaping (String, [MetadataResult]) -> Void,
        completionHandler: @escaping ([MetadataResult]) -> Void
    ) -> Runnable {
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
            
            // Execute search with incremental callback
            let task = search.search { results in
                resultsLock.lock()
                defer { resultsLock.unlock() }
                
                if !self.cancelled {
                    // Call incremental callback immediately (on main thread for UI updates)
                    DispatchQueue.main.async {
                        providerCallback(provider.name, results)
                    }
                    
                    // Add to aggregated results
                    allResults.append(contentsOf: results)
                }
                group.leave()
            }.runAsync()
            
            queue.sync {
                if !cancelled {
                    activeTasks.append(task)
                }
            }
        }
        
        // Wait for all providers to complete, then call final completion handler
        DispatchQueue.global().async {
            group.wait()
            
            resultsLock.lock()
            let finalResults = allResults
            resultsLock.unlock()
            
            if !self.cancelled {
                // Sort results by priority before final callback
                let sortedResults = self.priority.sortSublerResults(finalResults)
                
                DispatchQueue.main.async {
                    completionHandler(sortedResults)
                }
            }
        }
        
        return self
    }
}


#endif
