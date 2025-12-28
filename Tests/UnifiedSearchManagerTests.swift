import XCTest
@testable import SublerPlusCore

/// Mock MetadataProvider for testing
final class MockMetadataProvider: MetadataProvider {
    let id: String
    let isAdult: Bool
    let searchResults: [MetadataResult]
    let searchDelay: TimeInterval
    let shouldFail: Bool
    let failureError: Error?
    
    init(
        id: String = "mock",
        isAdult: Bool = false,
        searchResults: [MetadataResult] = [],
        searchDelay: TimeInterval = 0.1,
        shouldFail: Bool = false,
        failureError: Error? = nil
    ) {
        self.id = id
        self.isAdult = isAdult
        self.searchResults = searchResults
        self.searchDelay = searchDelay
        self.shouldFail = shouldFail
        self.failureError = failureError
    }
    
    func search(query: String) async throws -> [MetadataResult] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(searchDelay * 1_000_000_000))
        
        // Check for cancellation
        try Task.checkCancellation()
        
        if shouldFail {
            throw failureError ?? NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock provider failed"])
        }
        
        return searchResults
    }
    
    func fetchDetails(for id: String) async throws -> MetadataDetails {
        try await Task.sleep(nanoseconds: UInt64(searchDelay * 1_000_000_000))
        try Task.checkCancellation()
        
        if shouldFail {
            throw failureError ?? NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock provider failed"])
        }
        
        return MetadataDetails(
            id: id,
            title: "Mock Title",
            synopsis: nil,
            releaseDate: nil,
            studio: nil,
            tags: [],
            performers: [],
            coverURL: nil,
            rating: nil
        )
    }
}

final class UnifiedSearchManagerTests: XCTestCase {
    
    var manager: UnifiedSearchManager!
    var mockProviders: [MockMetadataProvider]!
    var cache: SearchCacheManager!
    
    override func setUp() {
        super.setUp()
        cache = SearchCacheManager(maxEntries: 10)
    }
    
    override func tearDown() {
        manager = nil
        mockProviders = nil
        cache = nil
        super.tearDown()
    }
    
    // MARK: - Provider Validation Tests
    
    func testSearchFailsWhenNoProvidersAvailable() async throws {
        // Given: Manager with no providers
        manager = UnifiedSearchManager(
            modernProviders: [],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test Query",
            type: .movie
        )
        
        // When: Search is executed
        // Then: Should throw noProvidersAvailable error
        do {
            _ = try await manager.search(options: options)
            XCTFail("Expected SearchError.noProvidersAvailable")
        } catch let error as SearchError {
            if case .noProvidersAvailable = error {
                // Expected
            } else {
                XCTFail("Expected noProvidersAvailable, got \(error)")
            }
        } catch {
            XCTFail("Expected SearchError, got \(error)")
        }
    }
    
    func testSearchFailsWhenAllProvidersFilteredOut() async throws {
        // Given: Manager with only adult providers, adult content disabled
        let adultProvider = MockMetadataProvider(id: "adult", isAdult: true)
        manager = UnifiedSearchManager(
            modernProviders: [adultProvider],
            includeAdult: false, // Adult content disabled
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test Query",
            type: .movie
        )
        
        // When: Search is executed
        // Then: Should throw noProvidersAvailable error
        do {
            _ = try await manager.search(options: options)
            XCTFail("Expected SearchError.noProvidersAvailable")
        } catch let error as SearchError {
            if case .noProvidersAvailable = error {
                // Expected
            } else {
                XCTFail("Expected noProvidersAvailable, got \(error)")
            }
        } catch {
            XCTFail("Expected SearchError, got \(error)")
        }
    }
    
    // MARK: - Successful Search Tests
    
    func testSuccessfulSearch() async throws {
        // Given: Manager with working providers
        let result1 = MetadataResult(
            id: "1",
            title: "Movie 1",
            score: 8.5,
            year: 2020,
            source: "provider1"
        )
        let result2 = MetadataResult(
            id: "2",
            title: "Movie 2",
            score: 7.0,
            year: 2021,
            source: "provider2"
        )
        
        let provider1 = MockMetadataProvider(
            id: "provider1",
            searchResults: [result1]
        )
        let provider2 = MockMetadataProvider(
            id: "provider2",
            searchResults: [result2]
        )
        
        manager = UnifiedSearchManager(
            modernProviders: [provider1, provider2],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test Query",
            type: .movie
        )
        
        // When: Search is executed
        let results = try await manager.search(options: options)
        
        // Then: Should return combined results
        XCTAssertEqual(results.count, 2, "Should return results from both providers")
        XCTAssertTrue(results.contains(where: { $0.id == "1" }))
        XCTAssertTrue(results.contains(where: { $0.id == "2" }))
    }
    
    func testSearchResultsAreSortedByScore() async throws {
        // Given: Providers with different scores
        let lowScore = MetadataResult(
            id: "1",
            title: "Low Score",
            score: 5.0,
            year: nil,
            source: "provider1"
        )
        let highScore = MetadataResult(
            id: "2",
            title: "High Score",
            score: 9.0,
            year: nil,
            source: "provider2"
        )
        
        let provider1 = MockMetadataProvider(id: "provider1", searchResults: [lowScore])
        let provider2 = MockMetadataProvider(id: "provider2", searchResults: [highScore])
        
        manager = UnifiedSearchManager(
            modernProviders: [provider1, provider2],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test",
            type: .movie
        )
        
        // When: Search is executed
        let results = try await manager.search(options: options)
        
        // Then: Results should be sorted by score (highest first)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].id, "2", "Highest score should be first")
        XCTAssertEqual(results[1].id, "1", "Lowest score should be second")
    }
    
    // MARK: - Provider Weighting Tests
    
    func testProviderWeightsBoostScores() async throws {
        // Given: Two providers with same score, different weights
        let result1 = MetadataResult(
            id: "1",
            title: "Weighted Result",
            score: 5.0,
            year: nil,
            source: "weighted"
        )
        let result2 = MetadataResult(
            id: "2",
            title: "Normal Result",
            score: 5.0,
            year: nil,
            source: "normal"
        )
        
        let weightedProvider = MockMetadataProvider(id: "weighted", searchResults: [result1])
        let normalProvider = MockMetadataProvider(id: "normal", searchResults: [result2])
        
        var weights = ProviderWeights.defaults()
        weights.setWeight(2.0, for: "weighted") // Double the score
        weights.setWeight(1.0, for: "normal")   // Normal score
        
        manager = UnifiedSearchManager(
            modernProviders: [weightedProvider, normalProvider],
            includeAdult: false,
            searchCache: nil,
            providerWeights: weights
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test",
            type: .movie
        )
        
        // When: Search is executed
        let results = try await manager.search(options: options)
        
        // Then: Weighted result should appear first (5.0 * 2.0 = 10.0 > 5.0 * 1.0 = 5.0)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].id, "1", "Weighted result should be first")
    }
    
    // MARK: - Caching Tests
    
    func testSearchUsesCache() async throws {
        // Given: Manager with cache and a provider
        let result = MetadataResult(
            id: "1",
            title: "Cached Result",
            score: 8.0,
            year: nil,
            source: "provider1"
        )
        
        let provider = MockMetadataProvider(
            id: "provider1",
            searchResults: [result],
            searchDelay: 0.5 // Longer delay to verify cache
        )
        
        manager = UnifiedSearchManager(
            modernProviders: [provider],
            includeAdult: false,
            searchCache: cache,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test Query",
            type: .movie
        )
        
        // When: First search (cache miss)
        let start1 = Date()
        let results1 = try await manager.search(options: options)
        let duration1 = Date().timeIntervalSince(start1)
        
        // Then: Should take time (network call)
        XCTAssertGreaterThan(duration1, 0.4, "First search should take time")
        XCTAssertEqual(results1.count, 1)
        
        // When: Second search with same query (cache hit)
        let start2 = Date()
        let results2 = try await manager.search(options: options)
        let duration2 = Date().timeIntervalSince(start2)
        
        // Then: Should be fast (from cache)
        XCTAssertLessThan(duration2, 0.1, "Cached search should be fast")
        XCTAssertEqual(results2.count, 1)
        XCTAssertEqual(results2[0].id, results1[0].id)
    }
    
    // MARK: - Cancellation Tests
    
    func testSearchCanBeCancelled() async throws {
        // Given: Manager with slow provider
        let provider = MockMetadataProvider(
            id: "slow",
            searchResults: [],
            searchDelay: 1.0 // Long delay
        )
        
        manager = UnifiedSearchManager(
            modernProviders: [provider],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test",
            type: .movie
        )
        
        // When: Start search and cancel immediately
        let searchTask = Task {
            try await manager.search(options: options)
        }
        
        // Cancel after short delay
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        searchTask.cancel()
        
        // Then: Should throw CancellationError
        do {
            _ = try await searchTask.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testSearchHandlesProviderFailure() async throws {
        // Given: One provider fails, one succeeds
        let successResult = MetadataResult(
            id: "1",
            title: "Success",
            score: 8.0,
            year: nil,
            source: "success"
        )
        
        let failingProvider = MockMetadataProvider(
            id: "failing",
            searchResults: [],
            shouldFail: true
        )
        let successProvider = MockMetadataProvider(
            id: "success",
            searchResults: [successResult]
        )
        
        manager = UnifiedSearchManager(
            modernProviders: [failingProvider, successProvider],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test",
            type: .movie
        )
        
        // When: Search is executed
        // Then: Should return results from successful provider (not throw)
        let results = try await manager.search(options: options)
        XCTAssertEqual(results.count, 1, "Should return results from successful provider")
        XCTAssertEqual(results[0].id, "1")
    }
    
    func testSearchThrowsWhenAllProvidersFail() async throws {
        // Given: All providers fail
        let failingProvider1 = MockMetadataProvider(
            id: "fail1",
            searchResults: [],
            shouldFail: true
        )
        let failingProvider2 = MockMetadataProvider(
            id: "fail2",
            searchResults: [],
            shouldFail: true
        )
        
        manager = UnifiedSearchManager(
            modernProviders: [failingProvider1, failingProvider2],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test",
            type: .movie
        )
        
        // When: Search is executed
        // Then: Should throw allProvidersFailed error
        do {
            _ = try await manager.search(options: options)
            XCTFail("Expected SearchError.allProvidersFailed")
        } catch let error as SearchError {
            if case .allProvidersFailed = error {
                // Expected
            } else {
                XCTFail("Expected allProvidersFailed, got \(error)")
            }
        } catch {
            XCTFail("Expected SearchError, got \(error)")
        }
    }
    
    // MARK: - Deduplication Tests
    
    func testSearchDeduplicatesResults() async throws {
        // Given: Two providers return same result
        let duplicateResult = MetadataResult(
            id: "1",
            title: "Duplicate",
            score: 8.0,
            year: nil,
            source: "provider1"
        )
        
        let provider1 = MockMetadataProvider(id: "provider1", searchResults: [duplicateResult])
        let provider2 = MockMetadataProvider(id: "provider2", searchResults: [duplicateResult])
        
        manager = UnifiedSearchManager(
            modernProviders: [provider1, provider2],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test",
            type: .movie
        )
        
        // When: Search is executed
        let results = try await manager.search(options: options)
        
        // Then: Should deduplicate results
        XCTAssertEqual(results.count, 1, "Should deduplicate identical results")
    }
    
    // MARK: - Year Hint Tests
    
    func testSearchPrioritizesCloserYear() async throws {
        // Given: Results with different years, year hint provided
        let result2020 = MetadataResult(
            id: "1",
            title: "2020 Movie",
            score: 8.0,
            year: 2020,
            source: "provider1"
        )
        let result2022 = MetadataResult(
            id: "2",
            title: "2022 Movie",
            score: 8.0, // Same score
            year: 2022,
            source: "provider2"
        )
        
        let provider1 = MockMetadataProvider(id: "provider1", searchResults: [result2020])
        let provider2 = MockMetadataProvider(id: "provider2", searchResults: [result2022])
        
        manager = UnifiedSearchManager(
            modernProviders: [provider1, provider2],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test",
            type: .movie,
            yearHint: 2021 // Hint closer to 2022
        )
        
        // When: Search is executed
        let results = try await manager.search(options: options)
        
        // Then: 2022 result should be first (closer to hint)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].id, "2", "Result closer to year hint should be first")
    }
    
    // MARK: - Concurrent Execution Tests
    
    func testProvidersSearchConcurrently() async throws {
        // Given: Multiple providers with delays
        let provider1 = MockMetadataProvider(
            id: "provider1",
            searchResults: [MetadataResult(id: "1", title: "Result 1", score: 8.0, year: nil, source: "provider1")],
            searchDelay: 0.2
        )
        let provider2 = MockMetadataProvider(
            id: "provider2",
            searchResults: [MetadataResult(id: "2", title: "Result 2", score: 8.0, year: nil, source: "provider2")],
            searchDelay: 0.2
        )
        let provider3 = MockMetadataProvider(
            id: "provider3",
            searchResults: [MetadataResult(id: "3", title: "Result 3", score: 8.0, year: nil, source: "provider3")],
            searchDelay: 0.2
        )
        
        manager = UnifiedSearchManager(
            modernProviders: [provider1, provider2, provider3],
            includeAdult: false,
            searchCache: nil,
            providerWeights: ProviderWeights.defaults()
        )
        
        let options = UnifiedSearchManager.SearchOptions(
            query: "Test",
            type: .movie
        )
        
        // When: Search is executed
        let start = Date()
        let results = try await manager.search(options: options)
        let duration = Date().timeIntervalSince(start)
        
        // Then: Should complete in ~0.2s (concurrent) not ~0.6s (sequential)
        XCTAssertLessThan(duration, 0.4, "Concurrent execution should be faster than sequential")
        XCTAssertEqual(results.count, 3, "Should return results from all providers")
    }
}

